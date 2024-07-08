//
//  VideoImport.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/3/24.
//

import Foundation

class VideoImport: ObservableObject {
    
    @Published var isProcessing = false
    @Published var progress: Float = 0
    @Published var totalFiles: Int = 0
    @Published var processedFiles: Int = 0
    
}
