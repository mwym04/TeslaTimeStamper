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
        // 기존 player를 정리합니다.
        player?.replaceCurrentItem(with: nil)
        
        guard let url = sourceURL else {
            activeVideoURL = nil
            player = nil
            return
        }
        
        // AVPlayerItem을 사용하여 메모리 사용을 최적화합니다.
        let playerItem = AVPlayerItem(url: url)
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        activeVideoURL = url
    }
    
    func updatePlayer(with fileName: String?) {
        guard let fileName = fileName else {
            player = nil
            activeVideoURL = nil
            return
        }
        
        let fileManager = FileManager.default
        guard let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            print("라이브러리 디렉토리를 찾을 수 없습니다.")
            return
        }
        
        let videoURL = libraryDirectory.appendingPathComponent("Videos").appendingPathComponent(fileName)
        
        // 기존 player를 정리합니다.
        player?.replaceCurrentItem(with: nil)
        
        // AVPlayerItem을 사용하여 메모리 사용을 최적화합니다.
        let playerItem = AVPlayerItem(url: videoURL)
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        activeVideoURL = videoURL
    }
}
