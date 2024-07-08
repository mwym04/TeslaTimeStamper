//
//  VideoView.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/1/24.
//

import SwiftUI
import AVFoundation
import AVKit
import SwiftData
import Photos

struct VideoView: View {
    
    var video: Video
    
    @ObservedObject var playerViewModel: VideoPlay = VideoPlay()
    @ObservedObject var exportViewModel: VideoExporter = VideoExporter()
    @State private var animation = false

    var body: some View {
        VStack {
            ButtonView(playerViewModel: playerViewModel, exportViewModel: exportViewModel, video: video)
                .padding()
                .onAppear {
                    setupPlayer()
                }
            GeometryReader { geometry in
                ZStack {
                    if let player = playerViewModel.player {
                        VideoPlayer(player: player)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .onDisappear(perform: {
                                if exportViewModel.isCompleted {
                                    exportViewModel.isCompleted = false
                                }
                            })
                    } else {
                        Spacer()
                        Text("비디오가 없습니다")
                        Spacer()
                    }
                    if exportViewModel.isCompleted {
                        VStack{
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.green)
                                .symbolEffect(.bounce.up.byLayer, value: animation)
                                .onAppear(perform: {
                                    animation = true
                                })
                                .onDisappear {
                                    animation = false
                                }
                            Text("앨범에 저장되었습니다.")
                                .font(.caption)
                                .padding(5)
                        }
                    }
                    if exportViewModel.isExporting {
                        VStack {
                            ProgressView(value: exportViewModel.progress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .tint(Color.white)
                                .animation(.linear(duration: 0.1), value: exportViewModel.progress)
                                .padding()
                            Text("\(Int(exportViewModel.progress * 100))%")
                        }
                    }
                }
            }
            
            Button {
                if let videoURL = playerViewModel.activeVideoURL, let creationDate = convertStringToDate(video.date) {
                    
                    Task {
                        let taskId = UIApplication.shared.beginBackgroundTask()
                        if let exportURL = try await exportViewModel.export(url: videoURL, creationDate: creationDate) {
                            await exportViewModel.saveToLibrary(url: exportURL)
                        }
                        UIApplication.shared.endBackgroundTask(taskId)
                    }
                }
            } label: {
                Text("타임스탬프")
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .foregroundStyle(Color.white)
                    .background(exportViewModel.isExporting ? .gray : .blue, in: RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
                    .padding()
            }
            .disabled(exportViewModel.isExporting)
        }
        .toolbar {
            ToolbarItem {
                if exportViewModel.isExporting {
                    Button("") {
                        
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(exportViewModel.isExporting)
    }
    
    private func convertStringToDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        dateFormatter.locale = Locale.current
        
        return dateFormatter.date(from: dateString)
    }
    
    private func setupPlayer() {
        let videoURL = [
            video.frontVideo,
            video.backVideo,
            video.leftVideo,
            video.rightVideo
        ].compactMap({ $0 }).first
        playerViewModel.updatePlayer(with: videoURL)
    }
}



#Preview {
    
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Video.self, configurations: config)
        
        // 기존의 모든 Video 인스턴스 삭제
        try container.mainContext.delete(model: Video.self)

        // 새로운 Video 인스턴스 하나 추가
        let newVideo = Video(date: "2024_07_10-18-10-30")
        newVideo.frontVideo = URL(string: "file:///path/to/front.mp4")
        newVideo.backVideo = URL(string: "file:///path/to/back.mp4")
        newVideo.leftVideo = URL(string: "file:///path/to/left.mp4")
        newVideo.rightVideo = URL(string: "file:///path/to/right.mp4")
        container.mainContext.insert(newVideo)
        
        return VideoView(video: newVideo)
            .modelContainer(container)
    } catch {
        fatalError("Failed to create model container: \(error.localizedDescription)")
    }
    
    func extractDateFromFilename(_ filename: String) -> Date? {
        let components = filename.split(separator: "_")
        guard components.count >= 2 else { return nil }
        
        let dateString = components[0] + " " + components[1].replacingOccurrences(of: "-", with: ":")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale.current
        
        return dateFormatter.date(from: dateString)
    }
}
