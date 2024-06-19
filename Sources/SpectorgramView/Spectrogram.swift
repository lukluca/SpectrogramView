//
//  Spectrogram.swift
//  ParoleFuoriDalComune
//
//  Created by softwave on 06/09/22.
//

import Foundation

protocol SpectrogramController {
    var rawAudioData: [Int16] { get }
    var frequencies: [Float] { get }
    
    func start()
    func stop()
    func reset()
}

#if targetEnvironment(simulator)

final class SimulatorSpectrogramController {
    
    private(set) var frequencies = [Float]()
    private(set) var rawAudioData = [Int16]()
    
    private var timer: Timer?
    
    func start() {
        stop()
        timer = Timer.scheduledTimer(timeInterval: 0.1,
                                     target: self,
                                     selector: #selector(fireTimer),
                                     userInfo: nil,
                                     repeats: true)
    }
    func reset() {
        frequencies.removeAll()
    }
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func fireTimer() {
        frequencies.append(Float.random(min: -10, max: 10))
    }
}

extension SimulatorSpectrogramController: SpectrogramController {}


private extension Float {

    /// Returns a random floating point number between 0.0 and 1.0, inclusive.
    static var random: Float {
        Float(arc4random()) / Float(0xFFFFFFFF)
    }

    /// Random float between 0 and n-1.
    ///
    /// - Parameter min:  Interval min
    /// - Parameter max:  Interval max
    /// - Returns:      Returns a random float point number between 0 and n max
    static func random(min: Float, max: Float) -> Float {
        Float.random * (max - min) + min
    }
}

#endif
