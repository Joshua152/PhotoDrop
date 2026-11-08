//
//  Camera.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/2/26.
//

import SwiftUI
import AVFoundation
import AVKit

struct CameraView<CameraModel: Camera>: PlatformView {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    
    var body: some View {
        ZStack {
            PreviewContainer(camera: camera) {
                CameraPreview(source: camera.previewSource)
                    .onCameraCaptureEvent(defaultSoundDisabled: true) { event in
                        if event.phase == .ended {
                            let sound: AVCaptureEventSound = .cameraShutter
                            let _ = await camera.capturePhoto()
                            
                            if event.shouldPlaySound {
                                event.play(sound)
                            }
                        }
                    }
                    .opacity(camera.shouldFlashScreen ? 0 : 1)
            }
            if camera.clip != nil {
                Image(uiImage: camera.clip!)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
            .contentShape(Rectangle())
            .onTapGesture {
                Task {
                    await camera.captureClip()
                }
            }
    }
}
