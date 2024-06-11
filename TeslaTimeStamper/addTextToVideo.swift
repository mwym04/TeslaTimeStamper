import AVFoundation
import UIKit
import Photos
import CoreImage.CIFilterBuiltins

class VideoExporter: ObservableObject {
    
    @Published var isExporting: Bool = false
    @Published var progress: Float = 0.0
    @Published var isCompleted: Bool = false
    private var timer: Timer = Timer()
    
    func export(url: URL,
                withPreset preset: String = AVAssetExportPresetHEVCHighestQualityWithAlpha,
                toFileType outputFileType: AVFileType = .mp4, creationDate startDate: Date) async throws -> URL? {
        
        DispatchQueue.main.async {
            self.isCompleted = false
            self.isExporting = true
            self.progress = 0.0
        }
        
        self.clearTemporaryDirectory()
        
        //날짜 처리
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
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
            resetExportingState(isCompleted: true)
            return outURL
        case .failed:
            print("export failed")
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

