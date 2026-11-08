//
//  PhotoDropApp.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/2/26.
//

import os
import SwiftUI

@main
struct PhotoDropApp: App {
    
    @State private var camera = CameraModel()
    
    var body: some Scene {
        WindowGroup {
            CameraView(camera: camera)
                .statusBarHidden(true)
                .task {
                    await camera.start()
                }
        }
    }
}

nonisolated let logger = Logger()
