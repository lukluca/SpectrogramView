//
//  AudioSpectrogram.swift
//  ParoleFuoriDalComune
//
//  Created by Luca Tagliabue on 07/09/21.
//

import AVFoundation
import Accelerate

final class AudioSpectrogram: CALayer, @unchecked Sendable {
    
    @MainActor static var darkMode = true
    
    var didAppendFrequencies: (([Float]) -> Void)?
    var didAppendAudioData: (([Int16]) -> Void)?
    
    var showError: ((SpectrogramError) -> Void)?

    // MARK: Initialization
    
    override init() {
        Task { @MainActor in
          AudioSpectrogram.darkMode = true
        }
        
        super.init()
    }
    
    @MainActor
    init(darkMode: Bool) {
        AudioSpectrogram.darkMode = darkMode
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    func configure(capturingSession: Bool) {
        contentsGravity = .resize
        
        if capturingSession {
            configureCaptureSession()
            audioOutput.setSampleBufferDelegate(self,
                                                queue: captureQueue)
        }
    }
    
    // MARK: Properties
    /// Samples per frame — the height of the spectrogram.
    static let sampleCount = 1024
    
    /// Number of displayed buffers — the width of the spectrogram.
    static let bufferCount = 768
    
    /// Determines the overlap between frames.
    static let hopCount = 512
    
    lazy var captureSession = AVCaptureSession()
    lazy var audioOutput = AVCaptureAudioDataOutput()
    lazy var captureQueue = DispatchQueue(label: "captureQueue",
                                          qos: .userInitiated,
                                          attributes: [],
                                          autoreleaseFrequency: .workItem)
    lazy var sessionQueue = DispatchQueue(label: "sessionQueue",
                                          attributes: [],
                                          autoreleaseFrequency: .workItem)
    
    let forwardDCT = vDSP.DCT(count: sampleCount,
                              transformType: .II)!
    
    /// The window sequence used to reduce spectral leakage.
    let hanningWindow = vDSP.window(ofType: Float.self,
                                    usingSequence: .hanningDenormalized,
                                    count: sampleCount,
                                    isHalfWindow: false)
    
    lazy var dispatchSemaphore = DispatchSemaphore(value: 1)
    
    /// The highest frequency that the app can represent.
    ///
    /// The first call of `AudioSpectrogram.captureOutput(_:didOutput:from:)` calculates
    /// this value.
    var nyquistFrequency: Float?
    
    /// A buffer that contains the raw audio data from AVFoundation.
    var rawAudioData = [Int16]()
    
    /// Raw frequency domain values.
    var frequencyDomainValues = [Float](repeating: 0,
                                        count: bufferCount * sampleCount)
        
    var rgbImageFormat: vImage_CGImageFormat = {
        guard let format = vImage_CGImageFormat(
                bitsPerComponent: 8,
                bitsPerPixel: 8 * 4,
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                renderingIntent: .defaultIntent) else {
            fatalError("Can't create image format.")
        }
        
        return format
    }()
    
    /// RGB vImage buffer that contains a vertical representation of the audio spectrogram.
    lazy var rgbImageBuffer: vImage_Buffer = {
        guard let buffer = try? vImage_Buffer(width: AudioSpectrogram.sampleCount,
                                              height: AudioSpectrogram.bufferCount,
                                              bitsPerPixel: rgbImageFormat.bitsPerPixel) else {
            fatalError("Unable to initialize image buffer.")
        }
        return buffer
    }()
    
    /// RGB vImage buffer that contains a horizontal representation of the audio spectrogram.
    lazy var rotatedImageBuffer: vImage_Buffer = {
        guard let buffer = try? vImage_Buffer(width: AudioSpectrogram.bufferCount,
                                              height: AudioSpectrogram.sampleCount,
                                              bitsPerPixel: rgbImageFormat.bitsPerPixel)  else {
            fatalError("Unable to initialize rotated image buffer.")
        }
        return buffer
    }()
    
    deinit {
        rgbImageBuffer.free()
        rotatedImageBuffer.free()
    }
    
    // Lookup tables for color transforms.
    @MainActor static var redTable: [Pixel_8] = (0 ... 255).map {
        brgValue(from: $0, darkMode: true).red
    }
    
    @MainActor static var greenTable: [Pixel_8] = (0 ... 255).map {
        brgValue(from: $0, darkMode: true).green
    }
    
    @MainActor static var blueTable: [Pixel_8] = (0 ... 255).map {
        brgValue(from: $0, darkMode: true).blue
    }
    
    // Lookup tables for color transforms.
    @MainActor static var lightRedTable: [Pixel_8] = (0 ... 255).map {
        brgValue(from: $0, darkMode: false).red
    }
    
    @MainActor static var lightGreenTable: [Pixel_8] = (0 ... 255).map {
        brgValue(from: $0, darkMode: false).green
    }
    
    @MainActor static var lightBlueTable: [Pixel_8] = (0 ... 255).map {
        brgValue(from: $0, darkMode: false).blue
    }
    
    /// A reusable array that contains the current frame of time domain audio data as single-precision
    /// values.
    var timeDomainBuffer = [Float](repeating: 0,
                                   count: sampleCount)
    
    /// A reusable array that contains the frequency domain representation of the current frame of
    /// audio data.
    var frequencyDomainBuffer = [Float](repeating: 0,
                                        count: sampleCount)
    
    // MARK: Instance Methods
        
    /// Process a frame of raw audio data:
    /// * Convert supplied `Int16` values to single-precision.
    /// * Apply a Hann window to the audio data.
    /// * Perform a forward discrete cosine transform.
    /// * Convert frequency domain values to decibels.
    func processData(values: [Int16]) {
        dispatchSemaphore.wait()
        
        vDSP.convertElements(of: values,
                             to: &timeDomainBuffer)
        
        vDSP.multiply(timeDomainBuffer,
                      hanningWindow,
                      result: &timeDomainBuffer)
        
        forwardDCT.transform(timeDomainBuffer,
                             result: &frequencyDomainBuffer)
        
        vDSP.absolute(frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        vDSP.convert(amplitude: frequencyDomainBuffer,
                     toDecibels: &frequencyDomainBuffer,
                     zeroReference: Float(AudioSpectrogram.sampleCount))
        
        if frequencyDomainValues.count > AudioSpectrogram.sampleCount {
            frequencyDomainValues.removeFirst(AudioSpectrogram.sampleCount)
        }
        
        frequencyDomainValues.append(contentsOf: frequencyDomainBuffer)
        didAppendFrequencies?(frequencyDomainBuffer)

        dispatchSemaphore.signal()
    }
    
    /// The value for the maximum float for RGB channels when the app converts PlanarF to
    /// ARGB8888.
    var maxFloat: Float = {
        var maxValue = [Float(Int16.max)]
        vDSP.convert(amplitude: maxValue,
                     toDecibels: &maxValue,
                     zeroReference: Float(AudioSpectrogram.sampleCount))
        return maxValue[0] * 2
    }()

    /// Creates an audio spectrogram `CGImage` from `frequencyDomainValues` and renders it
    /// to the `spectrogramLayer` layer.
    @MainActor func createAudioSpectrogram() {
        let maxFloats: [Float] = [255, maxFloat, maxFloat, maxFloat]
        let minFloats: [Float] = [255, 0, 0, 0]
        
        frequencyDomainValues.withUnsafeMutableBufferPointer {
            var planarImageBuffer = vImage_Buffer(data: $0.baseAddress!,
                                                  height: vImagePixelCount(AudioSpectrogram.bufferCount),
                                                  width: vImagePixelCount(AudioSpectrogram.sampleCount),
                                                  rowBytes: AudioSpectrogram.sampleCount * MemoryLayout<Float>.stride)
            
            vImageConvert_PlanarFToARGB8888(&planarImageBuffer,
                                            &planarImageBuffer, &planarImageBuffer, &planarImageBuffer,
                                            &rgbImageBuffer,
                                            maxFloats, minFloats,
                                            vImage_Flags(kvImageNoFlags))
        }
        
        if AudioSpectrogram.darkMode {
            vImageTableLookUp_ARGB8888(&rgbImageBuffer, &rgbImageBuffer,
                                       nil,
                                       &AudioSpectrogram.redTable,
                                       &AudioSpectrogram.greenTable,
                                       &AudioSpectrogram.blueTable,
                                       vImage_Flags(kvImageNoFlags))
        } else {
            vImageTableLookUp_ARGB8888(&rgbImageBuffer, &rgbImageBuffer,
                                       nil,
                                       &AudioSpectrogram.lightRedTable,
                                       &AudioSpectrogram.lightGreenTable,
                                       &AudioSpectrogram.lightBlueTable,
                                       vImage_Flags(kvImageNoFlags))
        }
        
        vImageRotate90_ARGB8888(&rgbImageBuffer,
                                &rotatedImageBuffer,
                                UInt8(kRotate90DegreesCounterClockwise),
                                [UInt8()],
                                vImage_Flags(kvImageNoFlags))
        
        if let image = try? rotatedImageBuffer.createCGImage(format: rgbImageFormat) {
            contents = image
        }
    }
}

import UIKit

// MARK: Utility functions
extension AudioSpectrogram {
    
    /// Returns the RGB values from a blue -> red -> green color map for a specified value.
    ///
    /// `value` controls hue and brightness. Values near zero return dark blue, `127` returns red, and
    ///  `255` returns full-brightness green.

    static func brgValue(from value: Pixel_8, darkMode: Bool) -> (red: Pixel_8,
                                                                  green: Pixel_8,
                                                                  blue: Pixel_8) {
        let normalizedValue = CGFloat(value) / 255
        
        // Define `hue` that's blue at `0.0` to red at `1.0`.
        let hue = 0.6666 - (0.6666 * normalizedValue)
        let brightness = sqrt(normalizedValue)
        
        let color = UIColor(hue: hue,
                            saturation: 1,
                            brightness: brightness,
                            alpha: 1)
        
        var red = CGFloat()
        var green = CGFloat()
        var blue = CGFloat()
        
        color.getRed(&red,
                     green: &green,
                     blue: &blue,
                     alpha: nil)
        
        if !darkMode {
            if green == 0 && red == 0 && blue == 0 {
                return (Pixel_8(255),
                        Pixel_8(255),
                        Pixel_8(255))
            }
        }
        
        return (Pixel_8(green * 255),
                Pixel_8(red * 255),
                Pixel_8(blue * 255))
    }
}

