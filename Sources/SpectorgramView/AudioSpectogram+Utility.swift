//
//  AudioSpectogram+Utility.swift
//  
//
//  Created by softwave on 22/06/24.
//

/*
import Accelerate
import Combine
import AVFoundation

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension AudioSpectrogram {
    
    /// Returns the RGB values from a blue -> red -> green color map for a specified value.
    ///
    /// Values near zero return dark blue, `0.5` returns red, and `1.0` returns full-brightness green.
    @MainActor static var multidimensionalLookupTable: vImage.MultidimensionalLookupTable = {
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
    @MainActor @available(iOS 16.0, *)
    static var emptyCGImage: CGImage = {
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
        
        return buffer.makeCGImage(cgImageFormat: fmt!)!
    }()
}
*/
