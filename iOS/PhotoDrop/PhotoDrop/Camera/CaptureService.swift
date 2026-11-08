//
//  CameraService.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/2/26.
//

import Foundation
@preconcurrency import AVFoundation
import Combine
import os

actor CaptureService {
    @Published private(set) var captureActivity: CaptureActivity = .idle
    @Published private(set) var isInterrupted = false

    nonisolated let previewSource: PreviewSource
    private let captureSession = AVCaptureSession()
    private let photoCapture = PhotoCapture()
    
    private var activeVideoInput: AVCaptureDeviceInput?
    
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator!
    private var rotationObservers = [AnyObject]()
    
    private var isSetUp = false

    init() {
        previewSource = DefaultPreviewSource(session: captureSession)
    }
    
    var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            var isAuthorized = status == .authorized
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            
            return isAuthorized
        }
    }
    
    func start() async throws {
        guard await isAuthorized, !captureSession.isRunning else { return }
        try setUpSession()
        captureSession.startRunning()
    }
    
    func capturePhoto() async throws -> Photo {
        try await photoCapture.capturePhoto()
    }
    
    func focusAndExpose(at point: CGPoint) {
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        
        do {
            try focusAndExpose(at: devicePoint, isUserInitiated: true)
        } catch {
            logger.debug("Unable to perform focus and exposure operation. \(error)")
        }
    }
    
    private func setUpSession() throws {
        guard !isSetUp else { return }
        
        observeOutputServices()
        observeNotifications()
        
        do {
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw CameraError.videoDeviceUnavailable
            }
            
            activeVideoInput = try addInput(for: camera)
            
            captureSession.sessionPreset = .photo
            captureSession.automaticallyRunsDeferredStart = true
            
            photoCapture.output.isDeferredStartEnabled = photoCapture.output.isDeferredStartSupported
            try addOutput(photoCapture.output)
            
            createRotationCoordinator(for: camera)
                        
            isSetUp = true
        } catch {
            throw CameraError.setupFailed
        }
    }
    
    private func createRotationCoordinator(for device: AVCaptureDevice) {
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: videoPreviewLayer)
        
        updatePreviewRotation(rotationCoordinator.videoRotationAngleForHorizonLevelPreview)
        updateCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        
        rotationObservers.removeAll()
        
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                Task { await self.updatePreviewRotation(angle) }
            }
        )
        
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                Task { await self.updateCaptureRotation(angle) }
            }
        )
    }
    
    private func updatePreviewRotation(_ angle: CGFloat) {
        let connection = videoPreviewLayer.connection
        Task { @MainActor in
            connection?.videoRotationAngle = angle
        }
    }
    
    private func updateCaptureRotation(_ angle: CGFloat) {
        photoCapture.setVideoRotationAngle(angle)
    }
    
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = captureSession.connections.compactMap({ $0.videoPreviewLayer }).first else {
            fatalError("The app is misconfigured. The capture session should have a connection to the preview layer.")
        }
        return previewLayer
    }
    
    private func focusAndExpose(at devicePoint: CGPoint, isUserInitiated: Bool) throws {
        let device = currentDevice
        
        try device.lockForConfiguration()
        
        let focusMode = isUserInitiated ? AVCaptureDevice.FocusMode.autoFocus : .continuousAutoFocus
        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
            device.exposurePointOfInterest = devicePoint
            device.focusMode = focusMode
        }
        
        let exposureMode = isUserInitiated ? AVCaptureDevice.ExposureMode.autoExpose : .continuousAutoExposure
        if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = exposureMode
        }
        
        device.isSubjectAreaChangeMonitoringEnabled = isUserInitiated
        
        device.unlockForConfiguration()
    }
    
    private var currentDevice: AVCaptureDevice {
        guard let device = activeVideoInput?.device else {
            fatalError("No device found for current video input.")
        }
        return device
    }
    
    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CameraError.addInputFailed
        }
        return input
    }
    
    private func addOutput(_ output: AVCaptureOutput) throws {
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            throw CameraError.addOutputFailed
        }
    }
    
    private func observeOutputServices() {
        photoCapture.$captureActivity.assign(to: &$captureActivity)
    }
    
    private func observeNotifications() {
        Task {
            for await reason in NotificationCenter.default.notifications(named: AVCaptureSession.wasInterruptedNotification)
                .compactMap({ $0.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject? })
                .compactMap({ AVCaptureSession.InterruptionReason(rawValue: $0.integerValue) }) {
                    
                    isInterrupted = reason == .videoDeviceInUseByAnotherClient
                }
        }
        
        Task {
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.interruptionEndedNotification) {
                isInterrupted = false
            }
        }
        
        Task {
            for await error in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification)
                .compactMap({ $0.userInfo?[AVCaptureSessionErrorKey] as? AVError }) {
                
                if error.code == .mediaServicesWereReset {
                    if !captureSession.isRunning {
                        captureSession.startRunning()
                    }
                }
            }
        }
    }
}
