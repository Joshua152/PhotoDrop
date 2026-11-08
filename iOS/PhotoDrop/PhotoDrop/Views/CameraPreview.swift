//
//  CameraPreview.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/2/26.
//

import SwiftUI
@preconcurrency import AVFoundation

struct CameraPreview: UIViewRepresentable {
    private let source: PreviewSource
    
    init(source: PreviewSource) {
        self.source = source
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let preview = PreviewView()
        source.connect(to: preview)
        return preview
    }
    
    func updateUIView(_ previewView: PreviewView, context: Context) {
    }
    
    class PreviewView: UIView, PreviewTarget {
        
        init() {
            super.init(frame: .zero)
    #if targetEnvironment(simulator)
            // The capture APIs require running on a real device. If running
            // in Simulator, display a static image to represent the video feed.
            let imageView = UIImageView()
            imageView.image = UIImage(named: "video_mode")
            imageView.contentMode = .scaleAspectFill
            // The image view resizes to fill the preview area.
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(imageView)
    #endif
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        // Use the preview layer as the view's backing layer.
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        
        nonisolated func setSession(_ session: AVCaptureSession) {
            // Connects the session with the preview layer, which allows the layer
            // to provide a live view of the captured content.
            Task { @MainActor in
                previewLayer.session = session
            }
        }
    }
}

protocol PreviewSource: Sendable {
    func connect(to target: PreviewTarget)
}

protocol PreviewTarget {
    func setSession(_ session: AVCaptureSession)
}

nonisolated struct DefaultPreviewSource: PreviewSource {
    private let session: AVCaptureSession
    
    init(session: AVCaptureSession) {
        self.session = session
    }
    
    func connect(to target: PreviewTarget) {
        target.setSession(session)
    }
}
