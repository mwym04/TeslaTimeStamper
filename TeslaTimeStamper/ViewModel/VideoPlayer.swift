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
    
    func updatePlayer(with url: URL?) {
        if let url = url {
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
