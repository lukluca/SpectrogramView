//
//  SpectrogramViewController.swift
//  ParoleFuoriDalComune
//
//  Created by Luca Tagliabue on 07/09/21.
//

import UIKit
import Combine

@MainActor
public final class SpectrogramViewController: UIViewController {

    /// The audio spectrogram
    private lazy var audioSpectrogram = AudioSpectrogram2()
    private var bag = [AnyCancellable]()
    
    public var showError: ((SpectrogramError) -> Void)?
    
    private lazy var imageContainer: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        
        view.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let top = imageView.topAnchor.constraint(equalTo: view.topAnchor)
        let bottom = imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        let leading = imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let trailing = imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        
        NSLayoutConstraint.activate([top, bottom, leading, trailing])
        
        return imageView
    }()
    
    public private(set) var frequencies = [Float]()
    public private(set) var rawAudioData = [Int16]()
    
    public var darkMode = false {
        didSet {
            if isViewLoaded {
                view.backgroundColor = darkMode ? .black : .white
            }
            
            setDarkMode(darkMode)
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        observe()
        
        view.backgroundColor = darkMode ? .black : .white
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
    
    public override var prefersStatusBarHidden: Bool {
        true
    }
    
    //MARK: Start / Stop
    
    public func start() {
        resetSpectrogram()
        setRequiresMicrophone(true)
        audioSpectrogram.rawAudioData.removeAll()
        audioSpectrogram.startRunning()
    }
    
    public func start(rawAudioData: [Int16]) {
        resetSpectrogram()
        setRequiresMicrophone(false)
        audioSpectrogram.rawAudioData = rawAudioData
        audioSpectrogram.startRunning()
    }
    
    public func stop() {
        audioSpectrogram.stopRunning()
    }
    
    public func reset() {
        frequencies.removeAll()
        resetSpectrogram()
    }
    
    private func resetSpectrogram() {
        imageContainer.image = nil
    }
    
    //MARK: Change Configuration
    
    private func setDarkMode(_ value: Bool) {
        let requiresMicrophone = audioSpectrogram.configuation.requiresMicrophone
        audioSpectrogram.configuation = .init(darkMode: darkMode, requiresMicrophone: requiresMicrophone)
    }
    
    private func setRequiresMicrophone(_ value: Bool) {
        let darkMode = audioSpectrogram.configuation.darkMode
        audioSpectrogram.configuation = .init(darkMode: darkMode, requiresMicrophone: value)
    }
    
    private func observe() {
        audioSpectrogram.$outputImage
            .compactMap { $0 }
            .sink { [weak self] image in
                self?.imageContainer.image = UIImage(cgImage: image)
            }
            .store(in: &bag)
        
        audioSpectrogram.$frequencies
            .sink { [weak self] frequencies in
                self?.frequencies = frequencies
            }
            .store(in: &bag)
        
        audioSpectrogram.$audioData
            .sink { [weak self] audioData in
                self?.rawAudioData = audioData
            }
            .store(in: &bag)
        
        audioSpectrogram.$error
            .compactMap { $0 }
            .sink { error in
                self.showError?(error)
            }
            .store(in: &bag)
    }
}

extension SpectrogramViewController: @preconcurrency SpectrogramController {}

public enum SpectrogramError: LocalizedError {
    case requiresMicrophoneAccess
    case cantCreateMicrophone
    case cantCreateMicrophoneDevice(Error)
    case impossibleCreateImage
    case cantAddAudioOutput
    
    public var recoverySuggestion: String? {
        switch self {
        case .requiresMicrophoneAccess:
            #if os(iOS)
            "Users can add authorization by choosing Settings > Privacy > Microphone."
            #elseif os(macOS)
            "Users can add authorization by choosing System Preferences > Security & Privacy > Microphone."
            #else
            nil
            #endif
        case .cantCreateMicrophone:
            nil
        case .cantCreateMicrophoneDevice:
            nil
        case .impossibleCreateImage:
            nil
        case .cantAddAudioOutput:
            nil
        }
    }
}
