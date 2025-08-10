import Flutter
import UIKit
import AVFoundation

public class MyCameraPlugin: NSObject, FlutterPlugin {
    private var session: AVCaptureSession?
    private var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64 = 0
    private var previewOutput: PreviewOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentDevice: AVCaptureDevice?
    private var isBackCamera = true
    private var photoCompletionHandler: ((FlutterResult, Data?) -> Void)?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "my_camera_plugin", binaryMessenger: registrar.messenger())
        let instance = MyCameraPlugin()
        instance.textureRegistry = registrar.textures()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startCamera":
            startCamera(result: result)
        case "stopCamera":
            stopCamera(result: result)
        case "switchCamera":
            switchCamera(result: result)
        case "takePhoto":
            takePhoto(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startCamera(result: @escaping FlutterResult) {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera(isBack: true, result: result)
                    } else {
                        result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
                    }
                }
            }
            return
        default:
            result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
            return
        }
        
        setupCamera(isBack: true, result: result)
    }
    
    private func setupCamera(isBack: Bool, result: @escaping FlutterResult) {
        // Stop existing session
        session?.stopRunning()
        session = nil
        
        // Create new session
        let session = AVCaptureSession()
        
        // Configure session for high quality
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            session.sessionPreset = .high
        }
        
        // Get camera device
        let position: AVCaptureDevice.Position = isBack ? .back : .front
        guard let device = getCamera(position: position) else {
            let cameraType = isBack ? "back" : "front"
            result(FlutterError(code: "NO_CAMERA", message: "No \(cameraType) camera found", details: nil))
            return
        }
        
        // Configure device for enhanced quality
        do {
            try device.lockForConfiguration()
            
            // Set focus mode for sharp images
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Set exposure mode for optimal brightness
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // Set white balance mode for accurate colors
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Enable image stabilization if available
            if device.activeFormat.isVideoStabilizationModeSupported(.auto) {
                // Note: Video stabilization is set on the connection, not the device
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to configure camera device: \(error)")
        }
        
        // Create input
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            result(FlutterError(code: "CAMERA_ERROR", message: "Failed to create camera input", details: nil))
            return
        }
        
        // Add input to session
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            result(FlutterError(code: "CAMERA_ERROR", message: "Cannot add camera input", details: nil))
            return
        }
        
        // Create texture output for preview
        guard let textureRegistry = textureRegistry else {
            result(FlutterError(code: "CAMERA_ERROR", message: "Texture registry not available", details: nil))
            return
        }
        
        let previewOutput = PreviewOutput(registry: textureRegistry)
        
        // Add video output
        if session.canAddOutput(previewOutput.videoOutput) {
            session.addOutput(previewOutput.videoOutput)
            
            // Configure video connection for enhanced quality
            if let connection = previewOutput.videoOutput.connection(with: .video) {
                // Set video stabilization
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                
                // Set orientation
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
        
        // Create and add photo output
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            // Configure photo output for high quality
            photoOutput.isHighResolutionCaptureEnabled = true
            if #available(iOS 13.0, *) {
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
        }
        
        // Store references
        self.session = session
        self.previewOutput = previewOutput
        self.photoOutput = photoOutput
        self.currentDevice = device
        self.isBackCamera = isBack
        self.textureId = previewOutput.textureId
        
        // Start session
        session.startRunning()
        
        // Return result
        let width = Int(device.activeFormat.formatDescription.dimensions.width)
        let height = Int(device.activeFormat.formatDescription.dimensions.height)
        
        result([
            "textureId": previewOutput.textureId,
            "isBackCamera": isBack,
            "width": width,
            "height": height,
            "quality": "enhanced"
        ])
    }
    
    private func switchCamera(result: @escaping FlutterResult) {
        setupCamera(isBack: !isBackCamera, result: result)
    }
    
    private func takePhoto(result: @escaping FlutterResult) {
        guard let photoOutput = photoOutput else {
            result(FlutterError(code: "CAMERA_NOT_READY", message: "Camera not initialized", details: nil))
            return
        }
        
        // Create photo settings for high quality
        let settings = AVCapturePhotoSettings()
        
        // Set format to JPEG
        settings.flashMode = .auto
        
        // Enable high resolution capture
        settings.isHighResolutionPhotoEnabled = true
        
        // Set quality prioritization (iOS 13+)
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }
        
        // Store completion handler
        photoCompletionHandler = { [weak self] flutterResult, imageData in
            guard let imageData = imageData else {
                flutterResult(FlutterError(code: "PHOTO_CAPTURE_ERROR", message: "No image data received", details: nil))
                return
            }
            
            // Convert to base64
            let base64String = imageData.base64EncodedString()
            flutterResult(base64String)
        }
        
        // Capture photo
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func stopCamera(result: @escaping FlutterResult) {
        session?.stopRunning()
        previewOutput?.dispose()
        
        session = nil
        previewOutput = nil
        photoOutput = nil
        currentDevice = nil
        textureId = 0
        
        result(nil)
    }
    
    private func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        } else {
            for device in AVCaptureDevice.devices(for: .video) {
                if device.position == position {
                    return device
                }
            }
            return nil
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension MyCameraPlugin: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCompletionHandler?(FlutterError(code: "PHOTO_CAPTURE_FAILED", message: "Photo capture failed: \(error.localizedDescription)", details: nil), nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            photoCompletionHandler?(FlutterError(code: "PHOTO_CAPTURE_ERROR", message: "Failed to get image data", details: nil), nil)
            return
        }
        
        photoCompletionHandler?(FlutterResult.self as! FlutterResult, imageData)
        photoCompletionHandler = nil
    }
}

// MARK: - PreviewOutput Class
class PreviewOutput: NSObject {
    let videoOutput: AVCaptureVideoDataOutput
    let textureId: Int64
    private let textureRegistry: FlutterTextureRegistry
    private var pixelBuffer: CVPixelBuffer?
    
    init(registry: FlutterTextureRegistry) {
        self.textureRegistry = registry
        self.videoOutput = AVCaptureVideoDataOutput()
        
        // Register texture
        self.textureId = registry.register(self)
        
        super.init()
        
        // Configure video output
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        // Set up video data output delegate
        let queue = DispatchQueue(label: "camera_frame_processing_queue")
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
    }
    
    func dispose() {
        textureRegistry.unregisterTexture(textureId)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension PreviewOutput: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let newPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Store the pixel buffer
        pixelBuffer = newPixelBuffer
        
        // Notify texture registry of new frame
        textureRegistry.textureFrameAvailable(textureId)
    }
}

// MARK: - FlutterTexture Protocol
extension PreviewOutput: FlutterTexture {
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = pixelBuffer else {
            return nil
        }
        return Unmanaged.passRetained(pixelBuffer)
    }
}

// MARK: - CMFormatDescription Extension
extension CMFormatDescription {
    var dimensions: CMVideoDimensions {
        return CMVideoFormatDescriptionGetDimensions(self)
    }
}