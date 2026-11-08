//
//  Camera.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/2/26.
//

import SwiftUI

protocol Camera: AnyObject, SendableMetatype {
    
    /// Provides the current clip status of the app
    var clipStatus: ClipStatus { get }
    
    /// Provides the current status of the camera
    var cameraStatus: CameraStatus { get }
    
    /// The camera's current activity state (photo capture, idle)
    var captureActivity: CaptureActivity { get }
    
    /// The source of video content for a camera preview
    var previewSource: PreviewSource { get }
    
    /// The extracted foreground clip
    var clip: UIImage? { get }
    
    /// Start the camera capture pipeline
    func start() async
    
    /// Performs a one-time automatic focus and exposure operation
    func focusAndExpose(at point: CGPoint) async
    
    /// Handles the actions for a photo (should keep track of state)
    func handlePhotoAction() async
    
    /// A boolean value that indicates whether to show visual feedback when capture begins
    var shouldFlashScreen: Bool { get }
    
    /// An error if the camera encounted a problem
    var error: Error? { get }
}
