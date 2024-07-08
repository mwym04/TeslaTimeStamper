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
    var leftVideo: URL?
    var rightVideo: URL?
    var frontVideo: URL?
    var backVideo: URL?
    
    init(date: String, leftVideo: URL? = nil, rightVideo: URL? = nil, frontVideo: URL? = nil, backVideo: URL? = nil) {
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
    
}
