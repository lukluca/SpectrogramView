/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The class that provides a signal that represents a drum loop.
*/

import Accelerate
import Combine
import AVFoundation

@MainActor
final class AudioSpectrogram2: NSObject, ObservableObject {
    
    @Published var configuation = Configuration()
    
    @Published var outputImage = AudioSpectrogram2.emptyCGImage
    
    @Published var frequencies = [Float]()
    /// A buffer that contains the raw audio data from AVFoundation.
    @Published var audioData = [Int16]()
    
    @Published var error: SpectrogramError?
    
    private var bag = [AnyCancellable]()
  
    override init() {
        super.init()
        
        $configuation.sink { [weak self] config in
            guard let self else {
                return
            }
            if config.requiresMicrophone {
                self.configureCaptureSession()
                self.audioOutput.setSampleBufferDelegate(self,
                                                         queue: captureQueue)
            }
            
        }.store(in: &bag)
    }
    
    // MARK: Properties
    
    lazy var melSpectrogram = MelSpectrogram(sampleCount: AudioSpectrogram2.sampleCount)
    
    /// The number of samples per frame — the height of the spectrogram.
    static let sampleCount = 1024
    
    /// The number of displayed buffers — the width of the spectrogram.
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
    
    /// The window sequence for reducing spectral leakage.
    let hanningWindow = vDSP.window(ofType: Float.self,
                                    usingSequence: .hanningDenormalized,
                                    count: sampleCount,
                                    isHalfWindow: false)
    
    let dispatchSemaphore = DispatchSemaphore(value: 1)
    
    /// The highest frequency that the app can represent.
    ///
    /// The first call of `AudioSpectrogram.captureOutput(_:didOutput:from:)` calculates
    /// this value.
    var nyquistFrequency: Float?
    
    var rawAudioData = [Int16]()
    
    /// Raw frequency-domain values.
    var frequencyDomainValues = [Float](repeating: 0,
                                        count: bufferCount * sampleCount)
        
    var rgbImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 32,
        bitsPerPixel: 32 * 3,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(
            rawValue: kCGBitmapByteOrder32Host.rawValue |
            CGBitmapInfo.floatComponents.rawValue |
            CGImageAlphaInfo.none.rawValue))
    
    /// RGB vImage buffer that contains a vertical representation of the audio spectrogram.
    
    let redBuffer = vImage.PixelBuffer<vImage.PlanarF>(
        width: AudioSpectrogram2.sampleCount,
        height: AudioSpectrogram2.bufferCount)
    
    let greenBuffer = vImage.PixelBuffer<vImage.PlanarF>(
        width: AudioSpectrogram2.sampleCount,
        height: AudioSpectrogram2.bufferCount)
    
    let blueBuffer = vImage.PixelBuffer<vImage.PlanarF>(
        width: AudioSpectrogram2.sampleCount,
        height: AudioSpectrogram2.bufferCount)
    
    let rgbImageBuffer = vImage.PixelBuffer<vImage.InterleavedFx3>(
        width: AudioSpectrogram2.sampleCount,
        height: AudioSpectrogram2.bufferCount)


    /// A reusable array that contains the current frame of time-domain audio data as single-precision
    /// values.
    var timeDomainBuffer = [Float](repeating: 0,
                                   count: sampleCount)
    
    /// A resuable array that contains the frequency-domain representation of the current frame of
    /// audio data.
    var frequencyDomainBuffer = [Float](repeating: 0,
                                        count: sampleCount)
    
    // MARK: Instance Methods
        
    /// Process a frame of raw audio data.
    ///
    /// * Convert supplied `Int16` values to single-precision and write the result to `timeDomainBuffer`.
    /// * Apply a Hann window to the audio data in `timeDomainBuffer`.
    /// * Perform a forward discrete cosine transform and write the result to `frequencyDomainBuffer`.
    /// * Convert frequency-domain values in `frequencyDomainBuffer` to decibels and scale by the
    ///     `gain` value.
    /// * Append the values in `frequencyDomainBuffer` to `frequencyDomainValues`.
    func processData(values: [Int16]) {
        vDSP.convertElements(of: values,
                             to: &timeDomainBuffer)
        
        vDSP.multiply(timeDomainBuffer,
                      hanningWindow,
                      result: &timeDomainBuffer)
        
        forwardDCT.transform(timeDomainBuffer,
                             result: &frequencyDomainBuffer)
        
        vDSP.absolute(frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        switch configuation.mode {
            case .linear:
                vDSP.convert(amplitude: frequencyDomainBuffer,
                             toDecibels: &frequencyDomainBuffer,
                             zeroReference: Float(configuation.zeroReference))
            case .mel:
                melSpectrogram.computeMelSpectrogram(
                    values: &frequencyDomainBuffer)
                
                vDSP.convert(power: frequencyDomainBuffer,
                             toDecibels: &frequencyDomainBuffer,
                             zeroReference: Float(configuation.zeroReference))
        }

        vDSP.multiply(Float(configuation.gain),
                      frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        if frequencyDomainValues.count > AudioSpectrogram2.sampleCount {
            frequencyDomainValues.removeFirst(AudioSpectrogram2.sampleCount)
        }
        
        frequencyDomainValues.append(contentsOf: frequencyDomainBuffer)
        frequencies.append(contentsOf: frequencyDomainBuffer)
    }
    
    private func makeAudioSpectrogramEmptyImage() throws -> CGImage {
        guard let empty = AudioSpectrogram2.emptyCGImage else {
            throw SpectrogramError.impossibleCreateImage
        }
        return empty
    }
    
    /// Creates an audio spectrogram `CGImage` from `frequencyDomainValues`.
    func makeAudioSpectrogramImage() throws -> CGImage {
        try frequencyDomainValues.withUnsafeMutableBufferPointer {
            guard let data = $0.baseAddress, let rgbImageFormat else {
                return try makeAudioSpectrogramEmptyImage()
            }
            
            let planarImageBuffer = vImage.PixelBuffer(
                data: data,
                width: AudioSpectrogram2.sampleCount,
                height: AudioSpectrogram2.bufferCount,
                byteCountPerRow: AudioSpectrogram2.sampleCount * MemoryLayout<Float>.stride,
                pixelFormat: vImage.PlanarF.self)
            
            AudioSpectrogram2.multidimensionalLookupTable.apply(
                sources: [planarImageBuffer],
                destinations: [redBuffer, greenBuffer, blueBuffer],
                interpolation: .half)
            
            rgbImageBuffer.interleave(
                planarSourceBuffers: [redBuffer, greenBuffer, blueBuffer])
            
            guard let image = rgbImageBuffer.makeCGImage(cgImageFormat: rgbImageFormat) else {
                return try makeAudioSpectrogramEmptyImage()
            }
            
            return image
        }
    }
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import SwiftUI

// MARK: Utility functions
extension AudioSpectrogram2 {
    
    /// Returns the RGB values from a blue -> red -> green color map for a specified value.
    ///
    /// Values near zero return dark blue, `0.5` returns red, and `1.0` returns full-brightness green.
    static var multidimensionalLookupTable: vImage.MultidimensionalLookupTable = {
        let entriesPerChannel = UInt8(32)
        let srcChannelCount = 1
        let destChannelCount = 3
        
        let lookupTableElementCount = Int(pow(Float(entriesPerChannel),
                                              Float(srcChannelCount))) *
        Int(destChannelCount)
        
        let tableData = [UInt16](unsafeUninitializedCapacity: lookupTableElementCount) {
            buffer, count in
            
            /// Supply the samples in the range `0...65535`. The transform function
            /// interpolates these to the range `0...1`.
            let multiplier = CGFloat(UInt16.max)
            var bufferIndex = 0
            
            for gray in ( 0 ..< entriesPerChannel) {
                /// Create normalized red, green, and blue values in the range `0...1`.
                let normalizedValue = CGFloat(gray) / CGFloat(entriesPerChannel - 1)
              
                // Define `hue` that's blue at `0.0` to red at `1.0`.
                let hue = 0.6666 - (0.6666 * normalizedValue)
                let brightness = sqrt(normalizedValue)
                
                let color = Color(hue: hue,
                                  saturation: 1,
                                  brightness: brightness,
                                  opacity: 1)
                
                var red = CGFloat()
                var green = CGFloat()
                var blue = CGFloat()
                
                #if canImport(UIKit)
                typealias NativeColor = UIColor
                #elseif canImport(AppKit)
                typealias NativeColor = NSColor
                #endif
                
                guard NativeColor(color).getRed(&red, green: &green, blue: &blue, alpha: nil) else {
                    return
                }
                
                buffer[ bufferIndex ] = UInt16(green * multiplier)
                bufferIndex += 1
                buffer[ bufferIndex ] = UInt16(red * multiplier)
                bufferIndex += 1
                buffer[ bufferIndex ] = UInt16(blue * multiplier)
                bufferIndex += 1
            }
            
            count = lookupTableElementCount
        }
        
        let entryCountPerSourceChannel = [UInt8](repeating: entriesPerChannel,
                                                 count: srcChannelCount)
        
        return vImage.MultidimensionalLookupTable(entryCountPerSourceChannel: entryCountPerSourceChannel,
                                                  destinationChannelCount: destChannelCount,
                                                  data: tableData)
    }()
    
    /// A 1x1 Core Graphics image.
    static var emptyCGImage: CGImage? = {
        let buffer = vImage.PixelBuffer(
            pixelValues: [0],
            size: .init(width: 1, height: 1),
            pixelFormat: vImage.Planar8.self)
        
        let fmt = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8 ,
            colorSpace: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            renderingIntent: .defaultIntent)
        
        guard let fmt else {
            return nil
        }
        
        return buffer.makeCGImage(cgImageFormat: fmt)
    }()
}

extension AudioSpectrogram2 {
    
    /// An enumeration that specifies the drum loop provider's mode.
    enum Mode: String, CaseIterable, Identifiable {
        case linear
        case mel
        
        var id: Self { self }
    }
    
    struct Configuration {
        let gain: Double
        let zeroReference: Double
        let darkMode: Bool
        let mode: Mode
        let requiresMicrophone: Bool
        
        init(gain: Double = 0.025, 
             zeroReference: Double = 1000,
             darkMode: Bool = true, 
             mode: Mode = .linear,
             requiresMicrophone: Bool = true) {
            self.gain = gain
            self.zeroReference = zeroReference
            self.darkMode = darkMode
            self.mode = mode
            self.requiresMicrophone = requiresMicrophone
        }
    }
}
