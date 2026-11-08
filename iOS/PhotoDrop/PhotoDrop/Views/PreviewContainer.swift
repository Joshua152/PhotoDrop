//
//  PreviewContainer.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/5/26.
//

import SwiftUI

typealias AspectRatio = CGSize
let photoAspectRatio = AspectRatio(width: 3.0, height: 4.0)
let videoAspectRatio = AspectRatio(width: 9.0, height: 16.0)

struct PreviewContainer<Content: View, CameraModel: Camera>: View {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var blurRadius = CGFloat.zero
    @State private var coverOpacity = 0.0
    
    private let photoModeOffset = CGFloat(-44)
    private let content: Content
    
    init(camera: CameraModel, @ViewBuilder content: () -> Content) {
        self.camera = camera
        self.content = content()
    }
    
    var body: some View {
        if horizontalSizeClass == .compact {
            ZStack {
                previewView
            }
            .clipped()
            .aspectRatio(photoAspectRatio, contentMode: .fit)
            .offset(y: photoModeOffset)
        } else {
            previewView
        }
    }
    
    var previewView: some View {
        content
            .blur(radius: blurRadius, opaque: true)
            .overlay(Color.black.opacity(coverOpacity))
//            .onChange(of: camera.isSwitchingModes, updateBlurRadius(_:_:))
            .onChange(of: scenePhase, updateCoverOpacity(_:_:))
    }
    
    func updateBlurRadius(_: Bool, _ isSwitching: Bool) {
        withAnimation {
            blurRadius = isSwitching ? 30 : 0
        }
    }
    
    func updateCoverOpacity(_: ScenePhase, _ phase: ScenePhase) {
        switch phase {
        case.background:
            coverOpacity = 1
        case.active:
            withAnimation(.easeIn(duration: 0.3)) {
                coverOpacity = 0
            }
        default:
            break
        }
    }
}
