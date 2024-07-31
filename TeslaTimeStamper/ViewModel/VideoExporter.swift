import AVFoundation
import UIKit
import Photos
import CoreImage.CIFilterBuiltins
import UserNotifications
import CoreText
import CoreGraphics

class VideoExporter: ObservableObject {
    
    @Published var isExporting: Bool = false
    @Published var progress: Float = 0.0
    @Published var isCompleted: Bool = false
    private var timer: Timer = Timer()
    let compositor: FourWayCompositor
    
    init() {
        self.compositor = FourWayCompositor()
    }
    
    func export(url: URL,
                withPreset preset: String = AVAssetExportPresetHEVCHighestQuality,
                toFileType outputFileType: AVFileType = .mp4, creationDate startDate: Date) async throws -> URL? {
        
        DispatchQueue.main.async {
            self.isCompleted = false
            self.isExporting = true
            self.progress = 0.0
        }
        
        self.clearTemporaryDirectory()
        
        //날짜 처리
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let video = AVURLAsset(url: url)
        //비디오 처리
        
        let titleComposition = AVMutableVideoComposition(asset: video) { request in
            let seconds = Int(CMTimeGetSeconds(request.compositionTime))
            let updatedDate = startDate.addingTimeInterval(TimeInterval(seconds))
            let dateString = dateFormatter.string(from: updatedDate)
            let fontSize = request.renderSize.height / 24
            // Create a white attributed string for the text
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
            ]
            let waterfallText = NSAttributedString(string: dateString, attributes: attributes)
            
            // Convert attributed string to a CIImage
            let textFilter = CIFilter.attributedTextImageGenerator()
            textFilter.text = waterfallText
            
            // Get the size of the text image
            let textImage = textFilter.outputImage!
            let textWidth = textImage.extent.width
            let textHeight = textImage.extent.height
            
            // Create a black box behind the text
            let boxFilter = CIFilter(name: "CIConstantColorGenerator")
            boxFilter?.setValue(CIColor.black, forKey: kCIInputColorKey)
            let boxImage = boxFilter?.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: textWidth + 20, height: textHeight + 20))
            
            // Adjust the opacity of the black box
            let transparentBox = boxImage?.applyingFilter("CIMultiplyCompositing", parameters: ["inputImage": boxImage!, "inputBackgroundImage": CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.85)).cropped(to: boxImage!.extent)])
            
            // Position the black box and text
            let positionedBox = transparentBox!.transformed(by: CGAffineTransform(translationX: (request.renderSize.width - transparentBox!.extent.width) / 2, y: request.renderSize.height - transparentBox!.extent.height))
            let positionedText = textImage.transformed(by: CGAffineTransform(translationX: (request.renderSize.width - textWidth) / 2, y: request.renderSize.height - textHeight - 20 + 10))
            
            // Compose text over the black box and then over the video image
            let combinedImage = positionedText.composited(over: positionedBox)
            let finalImage = combinedImage.composited(over: request.sourceImage)
            
            request.finish(with: finalImage, context: nil)
        }
        
        //*** 비디오 Export ***//
        let uniqueFileName = url.deletingPathExtension().lastPathComponent
        let documentURL = FileManager.default.temporaryDirectory
        var outURL = documentURL.appendingPathComponent(uniqueFileName).appendingPathExtension("mp4")
        
        guard let exportSession = AVAssetExportSession(asset: video,
                                                       presetName: preset) else {
            print("Failed to create export session.")
            fatalError()
        }
        
        exportSession.outputFileType = outputFileType
        exportSession.outputURL = outURL
        exportSession.videoComposition = titleComposition
        exportSession.shouldOptimizeForNetworkUse = false
        
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                self.progress = exportSession.progress
                if exportSession.progress >= 0.99 {
                    self.timer.invalidate()
                }
            }
        }
        
        await exportSession.export()
        
        switch exportSession.status {
        case .unknown:
            print("unknown error")
            resetExportingState(isCompleted: false)
            return nil
        case .waiting:
            print("waiting")
            resetExportingState(isCompleted: false)
            return nil
        case .exporting:
            print("exporting")
            resetExportingState(isCompleted: false)
            return nil
        case .completed:
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            do {
                try outURL.setResourceValues(resourceValues)
            } catch {
                print("생성날짜, 수정날짜를 변경하는데 실패했습니다.")
            }
            print("export completed")
            scheduleNotification()
            resetExportingState(isCompleted: true)
            return outURL
        case .failed:
            print("export failed")
            if let error = exportSession.error {
                print(error.localizedDescription)
                print(error)
            }
            resetExportingState(isCompleted: false)
            return nil
        case .cancelled:
            print("export cancelled")
            resetExportingState(isCompleted: false)
            return nil
        @unknown default:
            print("unknown error")
            resetExportingState(isCompleted: false)
            return nil
        }
    }
    
    func mergedVideo(url: URL, withPreset preset: String = AVAssetExportPresetHEVCHighestQuality, toFileType outputFileType: AVFileType = .mp4, creationDate startDate: Date) async throws -> URL? {
        
        DispatchQueue.main.async {
            self.isCompleted = false
            self.isExporting = true
            self.progress = 0.0
        }
        
        self.clearTemporaryDirectory()
        
        
        
        // Date processing
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let fileName: String = url.deletingPathExtension().lastPathComponent
        let position: String = extractSuffix(from: fileName)
        let date: String = String(fileName.prefix(fileName.count - position.count - 1))
        let fileManager = FileManager.default
        guard let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            print("라이브러리 디렉토리를 찾을 수 없습니다.")
            return nil
        }
        let videosDirectory = libraryDirectory.appendingPathComponent("Videos")
        
        let frontVideoURL = videosDirectory.appendingPathComponent(date + "-front").appendingPathExtension("mp4")
        let backVideoURL = videosDirectory.appendingPathComponent(date + "-back").appendingPathExtension("mp4")
        let leftVideoURL = videosDirectory.appendingPathComponent(date + "-left_repeater").appendingPathExtension("mp4")
        let rightVideoURL = videosDirectory.appendingPathComponent(date + "-right_repeater").appendingPathExtension("mp4")
        
        // Load video assets
        let frontVideo = AVURLAsset(url: frontVideoURL)
        let backVideo = AVURLAsset(url: backVideoURL)
        let leftVideo = AVURLAsset(url: leftVideoURL)
        let rightVideo = AVURLAsset(url: rightVideoURL)
        
        // Create a composition
        let composition = AVMutableComposition()
        guard let frontVideoTrack = try await frontVideo.loadTracks(withMediaType: .video).first,
              let backVideoTrack = try await backVideo.loadTracks(withMediaType: .video).first,
              let leftVideoTrack = try await leftVideo.loadTracks(withMediaType: .video).first,
              let rightVideoTrack = try await rightVideo.loadTracks(withMediaType: .video).first else { return nil }
        
        
        let frontCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let backCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let leftCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let rightCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        
        let frontVideoDuration = try await frontVideo.load(.duration)
        let backVideoDuration = try await backVideo.load(.duration)
        let leftVideoDuration = try await leftVideo.load(.duration)
        let rightVideoDuration = try await rightVideo.load(.duration)
        
        try frontCompositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: frontVideoDuration), of: frontVideoTrack, at: .zero)
        try backCompositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: backVideoDuration), of: backVideoTrack, at: .zero)
        try leftCompositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: leftVideoDuration), of: leftVideoTrack, at: .zero)
        try rightCompositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: rightVideoDuration), of: rightVideoTrack, at: .zero)
        
        let originVideoSize = try await frontVideoTrack.load(.naturalSize)
        let frameRate = try await frontVideoTrack.load(.minFrameDuration)
        let videoSize = CGSize(width: originVideoSize.width, height: originVideoSize.height * 4 / 3)

        // Video composition instructions
        FourWayCompositor.setStartDate(startDate)
        
        let videoComposition = AVMutableVideoComposition(propertiesOf: composition)
        videoComposition.customVideoCompositorClass = FourWayCompositor.self
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = frameRate
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        let frontLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: frontCompositionTrack)
        let BackLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: backCompositionTrack)
        let leftLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: leftCompositionTrack)
        let rightLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: rightCompositionTrack)
        
        instruction.layerInstructions = [BackLayerInstruction, leftLayerInstruction, rightLayerInstruction, frontLayerInstruction]
        videoComposition.instructions = [instruction]
        

        // Export session
        let uniqueFileName = url.deletingPathExtension().lastPathComponent + "_combined"
        let documentURL = FileManager.default.temporaryDirectory
        var outURL = documentURL.appendingPathComponent(uniqueFileName).appendingPathExtension("mp4")
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: preset) else {
            print("Failed to create export session.")
            fatalError()
        }
        
        videoComposition.frameDuration = CMTime(value: 30, timescale: 1000)
        
        exportSession.outputFileType = outputFileType
        exportSession.outputURL = outURL
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = false
        
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                self.progress = exportSession.progress
                if exportSession.progress >= 0.99 {
                    self.timer.invalidate()
                }
            }
        }
        
        await exportSession.export()
        
        switch exportSession.status {
        case .unknown:
            print("unknown error")
            resetExportingState(isCompleted: false)
            return nil
        case .waiting:
            print("waiting")
            resetExportingState(isCompleted: false)
            return nil
        case .exporting:
            print("exporting")
            resetExportingState(isCompleted: false)
            return nil
        case .completed:
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            do {
                try outURL.setResourceValues(resourceValues)
            } catch {
                print("생성날짜, 수정날짜를 변경하는데 실패했습니다.")
            }
            print("export completed")
            scheduleNotification()
            resetExportingState(isCompleted: true)
            return outURL
        case .failed:
            print("export failed")
            if let error = exportSession.error {
                print(error.localizedDescription)
                print(error)
            }
            resetExportingState(isCompleted: false)
            return nil
        case .cancelled:
            print("export cancelled")
            resetExportingState(isCompleted: false)
            return nil
        @unknown default:
            print("unknown error")
            resetExportingState(isCompleted: false)
            return nil
        }
        
    }
    
    private func extractSuffix(from input: String) -> String {
        let components = input.split(separator: "-")
        if let lastComponent = components.last {
            return String(lastComponent)
        }
        return ""
    }
    
    func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "타임스탬프 완료"
        content.body = "앨범에 저장되었습니다."
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func createFrameDuration(for frameRate: Float) -> CMTime {
        if frameRate.truncatingRemainder(dividingBy: 1) == 0 {
            // 정수 프레임 레이트
            return CMTime(value: 1, timescale: CMTimeScale(frameRate))
        } else {
            // 소수점 프레임 레이트
            let scale: CMTimeScale = 1000
            let value = CMTimeValue(round(Double(scale) / Double(frameRate)))
            return CMTime(value: value, timescale: scale)
        }
    }
    
    func resetExportingState(isCompleted: Bool) {
        DispatchQueue.main.async {
            self.isExporting = false
            self.progress = 0.0
            self.isCompleted = isCompleted
            self.timer.invalidate()
        }
    }
    
    func saveToLibrary(url: URL) async {
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        if status == .authorized {
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                do {
                    creationRequest?.creationDate = try url.resourceValues(forKeys: [.creationDateKey]).creationDate
                } catch {
                    print("생성날짜를 삽입하지 못했습니다.")
                }
                
            } completionHandler: { success, error in
                if success {
                    print("Video saved to photo library")
                } else if let error = error {
                    print("Error saving video: \(error.localizedDescription)")
                    fatalError()
                }
            }
        } else {
            print("Photo library access denied")
        }
    }
    
    func clearTemporaryDirectory() {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil, options: [])
            if tempFiles.isEmpty {
                print("No files to delete in the temporary directory")
            } else {
                for file in tempFiles {
                    try fileManager.removeItem(at: file)
                }
                print("Temporary directory cleared")
            }
        } catch {
            print("Error clearing temporary directory: \(error.localizedDescription)")
        }
    }
}

class FourWayCompositor: NSObject, AVVideoCompositing {
    
    private let dateFormatter: DateFormatter
    private static var startDate: Date = Date()
    
    override init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        super.init()
    }
    
    class func setStartDate(_ date: Date) {
        Self.startDate = date
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        guard let destinationBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "FourWayCompositor", code: -1, userInfo: nil))
            return
        }
        
        guard let frontBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: 1),
              let backBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: 2),
              let leftBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: 3),
              let rightBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: 4) else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "FourWayCompositor", code: -2, userInfo: nil))
            return
        }
        
        let ciContext = CIContext()
        let frontImage = CIImage(cvPixelBuffer: frontBuffer)
        let backImage = CIImage(cvPixelBuffer: backBuffer)
        let leftImage = CIImage(cvPixelBuffer: leftBuffer)
        let rightImage = CIImage(cvPixelBuffer: rightBuffer)
        
        let frontTransform = CGAffineTransform(translationX: 0, y: frontImage.extent.height / 3)
        
        let backTransform = CGAffineTransform(scaleX: -1 / 3, y: 1 / 3)
            .translatedBy(x: -frontImage.extent.width * 2, y: 0)
        
        let leftTransform = CGAffineTransform(scaleX: -1 / 3, y: 1 / 3)
            .translatedBy(x: -frontImage.extent.width, y: 0)
            
        let rightTransform = CGAffineTransform(scaleX: -1 / 3, y: 1 / 3)
            .translatedBy(x: -frontImage.extent.width * 3, y: 0)
        
        var compositeImage = frontImage.transformed(by: frontTransform)
            .composited(over: backImage.transformed(by: backTransform))
            .composited(over: leftImage.transformed(by: leftTransform))
            .composited(over: rightImage.transformed(by: rightTransform))
        
        let seconds = Int(CMTimeGetSeconds(asyncVideoCompositionRequest.compositionTime))
        let updatedDate = Self.startDate.addingTimeInterval(TimeInterval(seconds))
        let dateString = dateFormatter.string(from: updatedDate)
        let fontSize = asyncVideoCompositionRequest.renderContext.size.height / 32
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        ]
        let waterfallText = NSAttributedString(string: dateString, attributes: attributes)
        
        let textFilter = CIFilter.attributedTextImageGenerator()
        textFilter.text = waterfallText
        
        let textImage = textFilter.outputImage!
        let textWidth = textImage.extent.width
        let textHeight = textImage.extent.height
        
        let boxFilter = CIFilter(name: "CIConstantColorGenerator")
        boxFilter?.setValue(CIColor.black, forKey: kCIInputColorKey)
        let boxImage = boxFilter?.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: textWidth + 20, height: textHeight + 20))
        
        let transparentBox = boxImage?.applyingFilter("CIMultiplyCompositing", parameters: ["inputImage": boxImage!, "inputBackgroundImage": CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.85)).cropped(to: boxImage!.extent)])
        
        let positionedBox = transparentBox!.transformed(by: CGAffineTransform(translationX: (compositeImage.extent.width - transparentBox!.extent.width) / 2, y: compositeImage.extent.height - transparentBox!.extent.height))
        let positionedText = textImage.transformed(by: CGAffineTransform(translationX: (compositeImage.extent.width - textWidth) / 2, y: compositeImage.extent.height - textHeight - 20 + 10))
        
        let combinedImage = positionedText.composited(over: positionedBox)
        compositeImage = combinedImage.composited(over: compositeImage)
                
        ciContext.render(compositeImage, to: destinationBuffer)
        
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: destinationBuffer)
    }
    
    func cancelAllPendingVideoCompositionRequests() {}
    
    var sourcePixelBufferAttributes: [String : Any]? {
        return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
}
