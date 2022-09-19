//
//  FrameHandler.swift
//  LiveCamera
//
//  Created by 李晨 on 2022/9/19.
//

import AVFoundation
import CoreImage
import Vision
import UIKit

class FrameHandler: NSObject, ObservableObject {
    @Published var frame: CGImage?
    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let context = CIContext()
    var faceRectangle: [VNFaceObservation]?

    
    override init() {
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: // The user has previously granted access to the camera.
                permissionGranted = true
                
            case .notDetermined: // The user has not yet been asked for camera access.
                requestPermission()
                
        // Combine the two other cases into the default case
        default:
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        // Strong reference not a problem here but might become one in the future.
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
        }
    }
    
    func setupCaptureSession() {
        let videoOutput = AVCaptureVideoDataOutput()
        
        guard permissionGranted else { return }
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video, position: .back) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        captureSession.addOutput(videoOutput)
        
        videoOutput.connection(with: .video)?.videoOrientation = .landscapeRight
    }
}


extension FrameHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cgImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        // All UI updates should be/ must be performed on the main queue.
        DispatchQueue.main.async { [unowned self] in
            var uiImage = UIImage(cgImage: cgImage)
            identifyFacesWithLandmarks(image: uiImage)
            for face in faceRectangle! {
                let landmarkRegions: [VNFaceLandmarkRegion2D] = []
                uiImage = drawImage(source: uiImage, boundary: face.boundingBox, faceLandmarkRegions: landmarkRegions)
            }
            
//            self.frame = cgImage
            self.frame = uiImage.cgImage!
        }
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return cgImage
    }
    
    // defect faces and draw a rectangle to the face
    func drawImage(source: UIImage, boundary: CGRect, faceLandmarkRegions: [VNFaceLandmarkRegion2D]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(source.size, false, 1)
        
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: 0, y: source.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setLineJoin(.bevel)
        context.setLineCap(.square)
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        let rect = CGRect(x: 0, y: 0, width: source.size.width, height: source.size.height)
        context.draw(source.cgImage!, in: rect)
        
        let fillColor = UIColor.red
        fillColor.setStroke()
        fillColor.setFill()
        
        let rectangleWidth = source.size.width * boundary.size.width
        let rectangleHeight = source.size.height * boundary.size.height
        let radius = (pow(rectangleWidth, 2)+pow(rectangleHeight, 2)).squareRoot() / 2
        
        context.setLineWidth(12)
        context.addRect(CGRect(x: boundary.origin.x * source.size.width, y: boundary.origin.y * source.size.height, width: rectangleWidth, height: rectangleHeight))
        context.drawPath(using: CGPathDrawingMode.stroke)
        
        let modifiedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return modifiedImage
    }
    
    
    
    func identifyFacesWithLandmarks(image: UIImage) {
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        let request = VNDetectFaceLandmarksRequest() { [self] request, error in
            guard let foundFaces = request.results as? [VNFaceObservation] else {
                fatalError("Problem loading picture to examine faces")
            }
            
            self.faceRectangle = foundFaces
        }
        try! handler.perform([request])
    }
    
}
