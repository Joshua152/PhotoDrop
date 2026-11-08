//
//  DataTypes.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/4/26.
//

import SwiftUI
import Foundation

enum ClipStatus {
    /// A status that indicates the app is waiting for the next clip
    case waitingForClip
    
    /// A status that indicates the app is waiting for the computer paste location image
    case waitingForPasteLoc
}

enum CameraStatus {
    /// The initial state upon creation
    case unknown
    /// A status that indicates a person disallows access to the camera
    case unauthorized
    /// A status that indicates the camera failed to start
    case failed
    /// A status that indicates that the camera is succesfully running
    case running
    /// A status that indicates higher-priority media processing is interrupting the camera
    case interrupted
}

enum CaptureActivity {
    case idle
    case photoCapture(willCapture: Bool = false)
    
    var willCapture: Bool {
        if case .photoCapture(let willCapture) = self {
            return willCapture
        }
        return false
    }
}

struct Photo: Sendable {
    let data: Data
    let isProxy: Bool
}

enum CameraError: Error {
    case videoDeviceUnavailable
    case addInputFailed
    case addOutputFailed
    case setupFailed
}
