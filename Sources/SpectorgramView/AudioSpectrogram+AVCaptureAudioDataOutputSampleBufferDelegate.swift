//
//  AudioSpectrogram+AVCaptureAudioDataOutputSampleBufferDelegate.swift
//  ParoleFuoriDalComune
//
//  Created by Luca Tagliabue on 07/09/21.
//

/*
 import AVFoundation
 
 // MARK: AVCaptureAudioDataOutputSampleBufferDelegate and AVFoundation Support
 
 extension AudioSpectrogram: AVCaptureAudioDataOutputSampleBufferDelegate {
 
 func captureOutput(_ output: AVCaptureOutput,
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
 /// `nyquistFrequency` you may find this code useful to add an overlay to the user interface.
 if nyquistFrequency == nil {
 let duration = Float(CMSampleBufferGetDuration(sampleBuffer).value)
 let timescale = Float(CMSampleBufferGetDuration(sampleBuffer).timescale)
 let numSamples = Float(CMSampleBufferGetNumSamples(sampleBuffer))
 nyquistFrequency = 0.5 / (duration / timescale / numSamples)
 }
 
 if rawAudioData.count < AudioSpectrogram.sampleCount * 2 {
 let actualSampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
 
 let ptr = data.bindMemory(to: Int16.self, capacity: actualSampleCount)
 let buf = UnsafeBufferPointer(start: ptr, count: actualSampleCount)
 
 rawAudioData.append(contentsOf: Array(buf))
 }
 
 process()
 }
 
 func process() {
 while rawAudioData.count >= AudioSpectrogram.sampleCount {
 let dataToProcess = Array(rawAudioData[0 ..< AudioSpectrogram.sampleCount])
 rawAudioData.removeFirst(AudioSpectrogram.hopCount)
 didAppendAudioData?(dataToProcess)
 processData(values: dataToProcess)
 }
 
 Task { @MainActor [weak self] in
 self?.createAudioSpectrogram()
 }
 }
 
 func configureCaptureSession() {
 
 switch AVCaptureDevice.authorizationStatus(for: .audio) {
 case .authorized:
 break
 case .notDetermined:
 sessionQueue.suspend()
 AVCaptureDevice.requestAccess(for: .audio,
 completionHandler: { [weak self] granted in
 if !granted {
 self?.notify(error: .requiresMicrophoneAccess)
 } else {
 self?.configureCaptureSession()
 self?.sessionQueue.resume()
 }
 })
 return
 default:
 notify(error: .requiresMicrophoneAccess)
 
 }
 
 captureSession.beginConfiguration()
 
 if captureSession.canAddOutput(audioOutput) {
 captureSession.addOutput(audioOutput)
 } else {
 fatalError("Can't add `audioOutput`.")
 }
 
 guard
 let microphone = AVCaptureDevice.default(.builtInMicrophone,
 for: .audio,
 position: .unspecified),
 let microphoneInput = try? AVCaptureDeviceInput(device: microphone) else {
 notify(error: .cantCreateMicrophone)
 captureSession.commitConfiguration()
 return
 }
 
 if captureSession.canAddInput(microphoneInput) {
 captureSession.addInput(microphoneInput)
 }
 
 captureSession.commitConfiguration()
 }
 
 /// Starts the audio spectrogram.
 func startRunning() {
 sessionQueue.async { [weak self] in
 if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
 self?.captureSession.startRunning()
 }
 }
 }
 
 @MainActor
 func startRunning(rawAudioData: [Int16]) {
 self.rawAudioData = rawAudioData
 process()
 }
 
 /// Stops the audio spectrogram.
 func stopRunning() {
 sessionQueue.async { [weak self] in
 if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
 self?.captureSession.stopRunning()
 }
 }
 }
 
 private func notify(error: SpectrogramError) {
 Task { @MainActor [weak self] in
 self?.showError?(error)
 }
 }
 }
 */
