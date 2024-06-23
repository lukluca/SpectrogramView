/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The AudioSpectrogram extension for AVFoundation support.
*/

import AVFoundation

// MARK: AVCaptureAudioDataOutputSampleBufferDelegate and AVFoundation Support

extension AudioSpectrogram: AVCaptureAudioDataOutputSampleBufferDelegate {
 
    nonisolated public func captureOutput(_ output: AVCaptureOutput,
                                          didOutput sampleBuffer: CMSampleBuffer,
                                          from connection: AVCaptureConnection) {

        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
  
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout.stride(ofValue: audioBufferList),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer)
        
        guard let data = audioBufferList.mBuffers.mData else {
            return
        }
        
        /// The _Nyquist frequency_ is the highest frequency that a sampled system can properly
        /// reproduce and is half the sampling rate of such a system. Although  this app doesn't use
        /// `nyquistFrequency`,  you may find this code useful to add an overlay to the user interface.
        Task { @MainActor in
            if nyquistFrequency == nil {
                let duration = Float(CMSampleBufferGetDuration(sampleBuffer).value)
                let timescale = Float(CMSampleBufferGetDuration(sampleBuffer).timescale)
                let numsamples = Float(CMSampleBufferGetNumSamples(sampleBuffer))
                nyquistFrequency = 0.5 / (duration / timescale / numsamples)
            }
            
            /// Because the audio spectrogram code requires exactly `sampleCount` (which the app defines
            /// as 1024) samples, but audio sample buffers from AVFoundation may not always contain exactly
            /// 1024 samples, the app adds the contents of each audio sample buffer to `rawAudioData`.
            ///
            /// The following code creates an array from `data` and appends it to  `audioData`:
            if self.rawAudioData.count < AudioSpectrogram.sampleCount * 2 {
                let actualSampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
                
                let pointer = data.bindMemory(to: Int16.self,
                                              capacity: actualSampleCount)
                let buffer = UnsafeBufferPointer(start: pointer,
                                                 count: actualSampleCount)
                
                rawAudioData.append(contentsOf: Array(buffer))
            }
            
            process()
        }
    }
    
    func process() {
        /// The following code app passes the first `sampleCount`elements of raw audio data to the
        /// `processData(values:)` function, and removes the first `hopCount` elements from
        /// `rawAudioData`.
        ///
        /// By removing fewer elements than each step processes, the rendered frames of data overlap,
        /// ensuring no loss of audio data.
        while rawAudioData.count >= AudioSpectrogram.sampleCount {
            let dataToProcess = Array(rawAudioData[0 ..< AudioSpectrogram.sampleCount])
            rawAudioData.removeFirst(AudioSpectrogram.hopCount)
            processData(values: dataToProcess)
        }
        
        do {
            audioData = rawAudioData
            outputImage = try makeAudioSpectrogramImage()
        } catch {
            if let spectrogramError = error as? SpectrogramError {
                self.error = spectrogramError
            }
        }
    }
    
    func configureCaptureSession() {
        Task {
            await sessionQueue.configureCaptureSession(audioOutput: audioOutput)
        }
    }
    
    /// Starts the audio spectrogram.
    public func startRunning() {
        if configuation.requiresMicrophone {
            Task {
                await sessionQueue.startRunning()
            }
        } else {
            if !rawAudioData.isEmpty {
                audioData = rawAudioData
                process()
            }
        }
    }
    
    /// Stops the audio spectrogram.
    public func stopRunning() {
        guard configuation.requiresMicrophone else {
            return
        }
        Task {
            await sessionQueue.stopRunning()
        }
    }
}

actor SessionQueue {
    private lazy var captureSession = AVCaptureSession()
    
    var requiresMicrophone = false
    
    private var onError: (@Sendable (SpectrogramError) -> Void)?
    
    func setErrorCallback(_ callback: @escaping @Sendable (SpectrogramError) -> Void) {
        onError = callback
    }
    
    func configureCaptureSession(audioOutput: AVCaptureAudioDataOutput) {
        // Also note that:
        //
        // When running in iOS, you need to add a "Privacy - Microphone Usage
        // Description" entry.
        //
        // When running in macOS, you need to add a "Privacy - Microphone Usage
        // Description" entry to `Info.plist`, and select Audio Input and Camera
        // Access in the Resource Access category of Hardened Runtime.
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            requestAccess(audioOutput: audioOutput)
            return
        default:
            self.onError?(.requiresMicrophoneAccess)
        }
        
        captureSession.beginConfiguration()
        
        #if os(macOS)
        // Note that in macOS, you can change the sample rate, for example to
        // `AVSampleRateKey: 22050`. This reduces the Nyquist frequency and
        // increases the resolution at lower frequencies.
        audioOutput.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMBitDepthKey: 16,
            AVNumberOfChannelsKey: 1]
        #endif
        
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        } else {
            captureSession.commitConfiguration()
            self.onError?(.cantAddAudioOutput)
        }

        guard let microphone = AVCaptureDevice.default(.builtInMicrophone,
                                                       for: .audio,
                                                       position: .unspecified) else {
            captureSession.commitConfiguration()
            self.onError?(.cantCreateMicrophone)
            return
        }
        
        do {
            let microphoneInput = try AVCaptureDeviceInput(device: microphone)
            
            if captureSession.canAddInput(microphoneInput) {
                captureSession.addInput(microphoneInput)
            }
            
            captureSession.commitConfiguration()
            
        } catch {
            captureSession.commitConfiguration()
            self.onError?(.cantCreateMicrophoneDevice(error))
        }
    }
    
    private func requestAccess(audioOutput: AVCaptureAudioDataOutput) {
        AVCaptureDevice.requestAccess(for: .audio,
                                      completionHandler: { granted in
            
            Task { [weak self] in
                if !granted {
                    await self?.onError?(.requiresMicrophoneAccess)
                } else {
                    if await self?.requiresMicrophone == true {
                        await self?.configureCaptureSession(audioOutput: audioOutput)
                    }
                }
            }
        })
    }
     
    func startRunning() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            captureSession.startRunning()
        }
    }
    
    func stopRunning() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            captureSession.stopRunning()
        }
    }
}

extension AVCaptureAudioDataOutput: @unchecked @retroactive Sendable {}

extension CMSampleBuffer: @unchecked @retroactive Sendable {}

extension UnsafeMutableRawPointer: @unchecked @retroactive Sendable {}
