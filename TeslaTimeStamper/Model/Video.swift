//
//  Video.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/1/24.
//

import SwiftData
import SwiftUI

@Model
final class Video {
    
    var date: String
    var leftVideo: String?
    var rightVideo: String?
    var frontVideo: String?
    var backVideo: String?
    
    init(date: String, leftVideo: String? = nil, rightVideo: String? = nil, frontVideo: String? = nil, backVideo: String? = nil) {
        self.date = date
        self.leftVideo = leftVideo
        self.rightVideo = rightVideo
        self.frontVideo = frontVideo
        self.backVideo = backVideo
    }
    
    func convertDateFormat(_ inputDate: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        guard let date = inputFormatter.date(from: inputDate) else {
            print("날짜 파싱 실패")
            return ""
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        
        return outputFormatter.string(from: date)
    }
    
    func getURL(from fileName: String?) -> URL? {
        let fileManager = FileManager.default
        guard let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            print("라이브러리 디렉토리를 찾을 수 없습니다.")
            return nil
        }
        
        let videosDirectory = libraryDirectory.appendingPathComponent("Videos")
        
        do {
            try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Videos 디렉토리 생성 오류: \(error.localizedDescription)")
            return nil
        }
        
        if let fileName = fileName {
            let destinationURL = videosDirectory.appendingPathComponent(fileName)
            return destinationURL
        }
        
        return nil
    }
}
