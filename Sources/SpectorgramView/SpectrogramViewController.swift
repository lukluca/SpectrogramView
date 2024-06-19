//
//  SpectrogramViewController.swift
//  ParoleFuoriDalComune
//
//  Created by Luca Tagliabue on 07/09/21.
//

import UIKit

@MainActor
final class SpectrogramViewController: UIViewController {

    /// The audio spectrogram layer.
    private var audioSpectrogram: AudioSpectrogram?
    
    var showError: ((SpectrogramError) -> Void)?
    
    private(set) var frequencies = [Float]()
    private(set) var rawAudioData = [Int16]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setSpectrogram()
        
        view.backgroundColor = .black
    }

    override func viewDidLayoutSubviews() {
        audioSpectrogram?.frame = view.frame
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
    
    override var prefersStatusBarHidden: Bool {
        true
    }
    
    //MARK: Start / Stop
    
    func start() {
        setSpectrogram(darkMode: false)
        
        audioSpectrogram?.didAppendFrequencies = { values in
            Task { @MainActor [weak self] in
                self?.frequencies.append(contentsOf: values)
            }
        }
        
        audioSpectrogram?.didAppendAudioData = { [weak self] values in
            Task { @MainActor [weak self] in
                self?.rawAudioData.append(contentsOf: values)
            }
        }
        
        audioSpectrogram?.startRunning()
    }
    
    func start(rawAudioData: [Int16]) {
        resetSpectrogram()

        setSpectrogram(darkMode: false)
        
        audioSpectrogram?.startRunning(rawAudioData: rawAudioData)
    }
    
    func stop() {
        audioSpectrogram?.stopRunning()
    }
    
    func reset() {
        frequencies.removeAll()
        resetSpectrogram()
    }
    
    private func resetSpectrogram() {
        audioSpectrogram?.removeFromSuperlayer()
    }
    
    private func setSpectrogram(darkMode: Bool? = nil) {
        guard audioSpectrogram?.superlayer == nil else {
            return
        }
        let spectrogram: AudioSpectrogram
        if let darkMode = darkMode {
            spectrogram = AudioSpectrogram(darkMode: darkMode)
        } else {
            spectrogram = AudioSpectrogram()
        }
        audioSpectrogram = spectrogram
        bindSpectrogram()
        
        spectrogram.configure()
        
        view.layer.addSublayer(spectrogram)
    }
    
    private func bindSpectrogram() {
        audioSpectrogram?.showError = { [weak self] error in
            self?.showError?(error)
        }
    }
}

extension SpectrogramViewController: @preconcurrency SpectrogramController {}

enum SpectrogramError: Error {
    case requiresMicrophoneAccess
    case cantCreateMicrophone
}
