//
//  SpectrogramViewController.swift
//  ParoleFuoriDalComune
//
//  Created by Luca Tagliabue on 07/09/21.
//

import UIKit

@MainActor
public final class SpectrogramViewController: UIViewController {

    /// The audio spectrogram layer.
    private var audioSpectrogram: AudioSpectrogram?
    
    public var showError: ((SpectrogramError) -> Void)?
    
    public private(set) var frequencies = [Float]()
    public private(set) var rawAudioData = [Int16]()
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        setSpectrogram()
        
        view.backgroundColor = .black
    }

    public override func viewDidLayoutSubviews() {
        audioSpectrogram?.frame = view.frame
    }
    
    public override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
    
    public override var prefersStatusBarHidden: Bool {
        true
    }
    
    //MARK: Start / Stop
    
    public func start() {
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
    
    public func start(rawAudioData: [Int16]) {
        resetSpectrogram()

        setSpectrogram(darkMode: false, capturingSession: false)
        
        audioSpectrogram?.startRunning(rawAudioData: rawAudioData)
    }
    
    public func stop() {
        audioSpectrogram?.stopRunning()
    }
    
    public func reset() {
        frequencies.removeAll()
        resetSpectrogram()
    }
    
    private func resetSpectrogram() {
        audioSpectrogram?.removeFromSuperlayer()
    }
    
    private func setSpectrogram(darkMode: Bool? = nil, capturingSession: Bool = true) {
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
        
        spectrogram.configure(capturingSession: capturingSession)
        
        view.layer.addSublayer(spectrogram)
    }
    
    private func bindSpectrogram() {
        audioSpectrogram?.showError = { error in
            Task { @MainActor [weak self] in
                self?.showError?(error)
            }
        }
    }
}

extension SpectrogramViewController: @preconcurrency SpectrogramController {}

public enum SpectrogramError: Error {
    case requiresMicrophoneAccess
    case cantCreateMicrophone
}
