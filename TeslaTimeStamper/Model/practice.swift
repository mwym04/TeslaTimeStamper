import SwiftUI
import AVFoundation

func addTimeToVideoAndExport(creationDate: String, videoURL: URL, completion: @escaping (URL?) -> Void) {
    // 1. AVAsset 생성
    let asset = AVAsset(url: videoURL)
    
    // 2. 비디오 컴포지션 생성
    let composition = AVMutableComposition()
    guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        completion(nil)
        return
    }
    
    // 3. 원본 비디오 트랙 추가
    guard let assetTrack = asset.tracks(withMediaType: .video).first else {
        completion(nil)
        return
    }
    
    do {
        try compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: assetTrack, at: .zero)
    } catch {
        print("Error inserting video track: \(error)")
        completion(nil)
        return
    }
    
    // 4. 시간 텍스트 레이어 생성
    let videoSize = assetTrack.naturalSize
    let textLayer = CATextLayer()
    textLayer.frame = CGRect(x: 20, y: 20, width: videoSize.width - 40, height: 50)
    textLayer.fontSize = 30
    textLayer.foregroundColor = UIColor.white.cgColor
    textLayer.alignmentMode = .left
    textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
    
    // 5. 애니메이션 생성
    let animation = CABasicAnimation(keyPath: "string")
    animation.fromValue = creationDate
    animation.toValue = incrementTimeString(creationDate, by: asset.duration.seconds)
    animation.duration = asset.duration.seconds
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    textLayer.add(animation, forKey: "textAnimation")
    
    // 6. 비디오 컴포지션에 텍스트 레이어 추가
    let videoLayer = CALayer()
    videoLayer.frame = CGRect(origin: .zero, size: videoSize)
    
    let parentLayer = CALayer()
    parentLayer.frame = CGRect(origin: .zero, size: videoSize)
    parentLayer.addSublayer(videoLayer)
    parentLayer.addSublayer(textLayer)
    
    // 7. AVVideoComposition 생성
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = videoSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
    
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
    instruction.layerInstructions = [layerInstruction]
    
    videoComposition.instructions = [instruction]
    
    // 8. 비디오 export
    guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        completion(nil)
        return
    }
    
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.mp4")
    export.videoComposition = videoComposition
    export.outputURL = outputURL
    export.outputFileType = .mp4
    
    export.exportAsynchronously {
        switch export.status {
        case .completed:
            completion(outputURL)
        default:
            print("Export failed: \(String(describing: export.error))")
            completion(nil)
        }
    }
}

// 시간 증가 함수
func incrementTimeString(_ timeString: String, by seconds: Double) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
    
    guard let date = dateFormatter.date(from: timeString) else { return timeString }
    
    let newDate = date.addingTimeInterval(seconds)
    return dateFormatter.string(from: newDate)
}
