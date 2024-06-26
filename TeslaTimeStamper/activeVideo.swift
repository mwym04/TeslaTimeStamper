//
//  activeVideo.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 6/26/24.
//

import SwiftUI
import Combine

class ActiveVideo: ObservableObject {
    
    @Published var activeVideo: String?
    @Published var frontVideoURL: URL?
    @Published var backVideoURL: URL?
    @Published var leftVideoURL: URL?
    @Published var rightVideoURL: URL?
    
    func getActiveVideo(url: URL) {
        activeVideo = "front"
    }
    
}
