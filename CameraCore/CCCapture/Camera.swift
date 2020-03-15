//
//  Camera.swift
//  CameraCore
//
//  Created by hideyuki machida on 2019/12/31.
//  Copyright © 2019 hideyuki machida. All rights reserved.
//

import AVFoundation
import Foundation
import MetalCanvas
import MetalKit
import UIKit

extension CCCapture {
    public class CameraSetup: CCComponentSetupProtocol {
        fileprivate var onSetup: ((_ property: CCCapture.VideoCapture.Property) throws -> Void)?
        fileprivate var onUpdate: ((_ property: CCCapture.VideoCapture.Property) throws-> Void)?

        public func setup(property: CCCapture.VideoCapture.Property) throws { try self.onSetup?(property) }
        public func update(property: CCCapture.VideoCapture.Property) throws { try self.onUpdate?(property) }
    }

    public class CameraTriger: CCComponentTrigerProtocol {
        fileprivate var onPlay: (()->Void)?
        fileprivate var onPause: (()->Void)?
        fileprivate var onDispose: (()->Void)?
        
        public func play() { self.onPlay?() }
        public func pause() { self.onPause?() }
        public func dispose() { self.onDispose?() }
    }

    public class CameraPipe: CCComponentPipeProtocol {
        public var outCaptureData: ((_ currentCaptureItem: CCCapture.VideoCapture.CaptureData) -> Void)?
    }

}

extension CCCapture {
    @objc public class Camera: NSObject {
        public let setup: CCCapture.CameraSetup = CCCapture.CameraSetup()
        public let triger: CCCapture.CameraTriger = CCCapture.CameraTriger()
        public let pipe: CCCapture.CameraPipe = CCCapture.CameraPipe()
        
        public fileprivate(set) var property: CCCapture.VideoCapture.Property {
            willSet {
                self.onUpdateCaptureProperty?(newValue)
            }
        }

        public var event: Event?
        public var status: Camera.Status = .setup {
            willSet {
                self.event?.onStatusChange?(newValue)
            }
        }

        public var onUpdateCaptureProperty: ((_ property: CCCapture.VideoCapture.Property) -> Void)?

        public var capture: CCCapture.VideoCapture.VideoCaptureManager?

        public init(property: CCCapture.VideoCapture.Property) throws {
            self.property = property

            super.init()
            try self.setupProperty(property: property)
            
            self.setup.onSetup = self.setupProperty
            self.triger.onPlay = self.play
            self.triger.onPause = self.pause
            self.triger.onDispose = self.dispose
        }

        deinit {
            MCDebug.deinitLog(self)
        }

    }
}


extension CCCapture.Camera {
    fileprivate func play() {
        guard self.status != .play else { return }
        MCDebug.log("CameraCore.VideoRecordingPlayer.play")
        self.capture?.play()
        self.status = .play
    }

    fileprivate func pause() {
        MCDebug.log("CameraCore.VideoRecordingPlayer.pause")
        self.capture?.stop()
        self.status = .pause
    }

    fileprivate func dispose() {
        MCDebug.log("CameraCore.VideoRecordingPlayer.dispose")
        self.capture?.stop()
        self.status = .setup
        self.capture = nil
    }
}

fileprivate extension CCCapture.Camera {
    func setupProperty(property: CCCapture.VideoCapture.Property) throws {
        self.property = property

        ///////////////////////////////////////////////////////////////////////////////////////////////////
        do {
            self.capture = try CCCapture.VideoCapture.VideoCaptureManager(property: property)
        } catch {
            self.capture = nil
            throw CCRenderer.ErrorType.setup
        }
        ///////////////////////////////////////////////////////////////////////////////////////////////////

        ///////////////////////////////////////////////////////////////////////////////////////////////////
        self.capture?.onUpdate = { [weak self] (sampleBuffer: CMSampleBuffer, captureVideoOrientation: AVCaptureVideoOrientation, depthData: AVDepthData?, metadataObjects: [AVMetadataObject]?) in

            guard
                let self = self,
                let captureInfo: CCCapture.VideoCapture.CaptureInfo = self.capture?.property.captureInfo
            else { return }

            let currentCaptureItem: CCCapture.VideoCapture.CaptureData = CCCapture.VideoCapture.CaptureData(
                sampleBuffer: sampleBuffer,
                captureInfo: captureInfo,
                depthData: depthData,
                metadataObjects: metadataObjects,
                colorPixelFormat: MTLPixelFormat.bgra8Unorm,
                captureVideoOrientation: captureVideoOrientation
            )

            self.event?.onUpdate?(currentCaptureItem)
            self.pipe.outCaptureData?(currentCaptureItem)
        }
        ///////////////////////////////////////////////////////////////////////////////////////////////////
    }

    func updateProperty(property: CCCapture.VideoCapture.Property) throws {
        try self.capture?.update(property: property)
    }
}

extension CCCapture.Camera {
    public enum Status {
        case setup
        case update
        case ready
        case play
        case pause
        case seek
        case dispose
    }

    public class Event: NSObject {
        public var onStatusChange: ((_ status: CCCapture.Camera.Status) -> Void)?
        public var onUpdate: ((_ captureData: CCCapture.VideoCapture.CaptureData) -> Void)?
    }
}
