//
//  VideoPlayer.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/1/24.
//

import Foundation
import AVFoundation

class VideoPlay: ObservableObject {
    
    @Published var player: AVPlayer?
    @Published var activeVideoURL: URL?
    
    init(activeVideoURL: URL? = nil) {
        self.activeVideoURL = activeVideoURL
    }
    
    func changeActiveVideo(from sourceURL: URL?) {
        if let url = sourceURL {
            activeVideoURL = url
            player = AVPlayer(url: url)
        } else {
            activeVideoURL = nil
            player = nil
        }
    }
    
    func updatePlayer(with fileName: String?) {
        
        let fileManager = FileManager.default
        guard let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            print("라이브러리 디렉토리를 찾을 수 없습니다.")
            return
        }
        
        let videosDirectory = libraryDirectory.appendingPathComponent("Videos")
        
        if let fileName = fileName {
            let url = videosDirectory.appendingPathComponent(fileName)
            if player == nil {
                player = AVPlayer(url: url)
            } else {
                let item = AVPlayerItem(url: url)
                player?.replaceCurrentItem(with: item)
            }
            activeVideoURL = url
        } else {
            player = nil
            activeVideoURL = nil
        }
        
    }
    
}
