//
//  VideoListViewModel.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/30/24.
//

import SwiftUI
import SwiftData

class VideoListViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var multiSelection = Set<String>()
    @Published var isFileImporterPresented = false
    @Published var showAlert = false
    @Published var isProcessing = false
    @Published var progress: Float = 0
    @Published var totalFiles: Int = 0
    @Published var processedFiles: Int = 0
    @Published var isEditing = false
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchVideos()
    }
    
    func fetchVideos() {
        let descriptor = FetchDescriptor<Video>(sortBy: [SortDescriptor(\.date)])
        do {
            let fetched = try modelContext.fetch(descriptor)
            DispatchQueue.main.async {
                self.videos = fetched
            }
        } catch {
            print("Failed to fetch videos: \(error)")
        }
    }
    
    func deleteSelectedVideos() {
        let fileManager = FileManager.default
        
        for date in multiSelection {
            guard let video = videos.first(where: { $0.date == date}) else { continue }
            func deleteFile(at url: URL?) {
                guard let url = url else { return }
                do {
                    try fileManager.removeItem(at: url)
                    print("파일 삭제 성공: \(url.lastPathComponent)")
                } catch {
                    print("파일 삭제 실패: \(url.lastPathComponent), 에러: \(error.localizedDescription)")
                }
            }
            deleteFile(at: video.getURL(from: video.frontVideo))
            deleteFile(at: video.getURL(from: video.backVideo))
            deleteFile(at: video.getURL(from: video.leftVideo))
            deleteFile(at: video.getURL(from: video.rightVideo))
            
            modelContext.delete(video)
        }
        multiSelection.removeAll()
        fetchVideos()
        DispatchQueue.main.async {
            self.multiSelection.removeAll()
            self.fetchVideos()
        }
    }
    
    func videoSaveToList(from url: URL) async {
        
        let fileName: String = url.deletingPathExtension().lastPathComponent
        let position: String = extractSuffix(from: fileName)
        
        if fileName == position {
            showAlert = true
            await MainActor.run {
                self.showAlert = true
            }
            return
        }
        
        if !["front", "back", "left_repeater", "right_repeater"].contains(position) {
            showAlert = true
            await MainActor.run {
                self.showAlert = true
            }
            return
        }
        
        let date: String = String(fileName.prefix(fileName.count - position.count - 1))
        print(date)
        
        let descriptor = FetchDescriptor<Video>(predicate: #Predicate { video in
            video.date == date
        })
        
        let videos: [Video]
        
        do {
            videos = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch videos: \(error)")
            return
        }
        
        await moveFile(from: url)
        
        await MainActor.run {
            if let video = videos.first {
                switch position {
                case "front":
                    video.frontVideo = url.lastPathComponent
                case "back":
                    video.backVideo = url.lastPathComponent
                case "left_repeater":
                    video.leftVideo = url.lastPathComponent
                case "right_repeater":
                    video.rightVideo = url.lastPathComponent
                default:
                    break
                }
            } else {
                let newVideo = Video(date: date)
                switch position {
                case "front":
                    newVideo.frontVideo = url.lastPathComponent
                case "back":
                    newVideo.backVideo = url.lastPathComponent
                case "left_repeater":
                    newVideo.leftVideo = url.lastPathComponent
                case "right_repeater":
                    newVideo.rightVideo = url.lastPathComponent
                default:
                    break
                }
                self.modelContext.insert(newVideo)
            }
            self.fetchVideos()
            
            do {
                try modelContext.save()
                print("Updated successfully")
            } catch {
                print("Failed to save changes: \(error)")
            }
        }
    }
    
    func extractSuffix(from input: String) -> String {
        let components = input.split(separator: "-")
        if let lastComponent = components.last {
            return String(lastComponent)
        }
        return ""
    }
    
    func moveFile(from sourceURL: URL) async {
        
        let fileManager = FileManager.default
        guard let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            print("라이브러리 디렉토리를 찾을 수 없습니다.")
            return
        }
        
        let videosDirectory = libraryDirectory.appendingPathComponent("Videos")
        
        do {
            try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Videos 디렉토리 생성 오류: \(error.localizedDescription)")
            return
        }
        
        let destinationURL = videosDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        
        guard sourceURL.startAccessingSecurityScopedResource() else {
            print("파일에 대한 접근 권한을 얻을 수 없습니다.")
            return
        }
        
        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            print("파일이동 오류: \(error.localizedDescription)")
        }
    }
    
    private func extractURL(from sourceURL: URL) -> String? {
        
        return sourceURL.lastPathComponent

    }
}
