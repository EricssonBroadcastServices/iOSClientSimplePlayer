//
//  Int+timeFormat.swift
//  SDK SimplePlayer
//
//  Created by Udaya Sri Senarathne on 2022-07-04.
//

import Foundation

extension Int64 {
    public func timeFormat() -> String {
        let s:UInt64 = (self < 0 ? UInt64(-self) : UInt64(self)) / 1000
        
        let seconds = s % 60
        let minutes = (s / 60) % 60
        let hours = (s / 3600) % 24
        
        guard hours > 0 else {
            return (self<0 ? "-":"") + String(format: "%02d:%02d",minutes,seconds)
        }
        return (self<0 ? "-":"") + String(format: "%d:%02d:%02d", hours,minutes,seconds)
    }
}
