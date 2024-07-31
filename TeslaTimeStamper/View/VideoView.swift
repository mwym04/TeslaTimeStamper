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
    
    @ObservedObject var playerViewModel: VideoPlay
    @ObservedObject var exportViewModel: VideoExporter = VideoExporter()
    
    @State private var animation = false
    @State private var isIntergrated = false

    var body: some View {
        VStack {
            ButtonView(playerViewModel: playerViewModel, exportViewModel: exportViewModel, video: video)
                .padding()
                .padding(.top, 50)
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
                            .frame(width: geometry.size.width, height: geometry.size.height)
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
                                .monospacedDigit()
                        }
                    }
                }
            }
            Button {
                if isIntergrated {
                    if let videoURL = playerViewModel.activeVideoURL, let creationDate = convertStringToDate(video.date) {
                        Task {
                            let taskId = UIApplication.shared.beginBackgroundTask()
                            if let exportURL = try await exportViewModel.mergedVideo(url: videoURL, creationDate: creationDate) {
                                await exportViewModel.saveToLibrary(url: exportURL)
                            }
                            UIApplication.shared.endBackgroundTask(taskId)
                        }
                    }
                    
                } else {
                    if let videoURL = playerViewModel.activeVideoURL, let creationDate = convertStringToDate(video.date) {
                        Task {
                            let taskId = UIApplication.shared.beginBackgroundTask()
                            if let exportURL = try await exportViewModel.export(url: videoURL, creationDate: creationDate) {
                                await exportViewModel.saveToLibrary(url: exportURL)
                            }
                            UIApplication.shared.endBackgroundTask(taskId)
                        }
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
                if let _ = video.frontVideo, let _ = video.backVideo, let _ = video.rightVideo, let _ = video.leftVideo {
                    if !exportViewModel.isExporting {
                        Toggle("통합 비디오", isOn: $isIntergrated)
                            .toggleStyle(.switch)
                    }
                } else {
                    Toggle("통합 비디오", isOn: $isIntergrated)
                        .toggleStyle(.switch)
                        .disabled(true)
                }
                
                if exportViewModel.isExporting {
                    Button("") { }
                }
            }
        }
        .navigationBarBackButtonHidden(exportViewModel.isExporting)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func convertStringToDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        dateFormatter.locale = Locale.current
        
        return dateFormatter.date(from: dateString)
    }
}

struct PinchableVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PinchableVideoPlayer
        var lastScale: CGFloat = 1.0
        
        init(parent: PinchableVideoPlayer) {
            self.parent = parent
        }
        
        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let view = sender.view else { return }
            
            if sender.state == .began || sender.state == .changed {
                let scale = sender.scale
                view.transform = view.transform.scaledBy(x: scale, y: scale)
                sender.scale = 1.0
            }
        }
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinchGesture.delegate = context.coordinator
        view.addGestureRecognizer(pinchGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
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
        newVideo.frontVideo = "file:///path/to/front.mp4"
        newVideo.backVideo = "file:///path/to/back.mp4"
        newVideo.leftVideo = "file:///path/to/left.mp4"
        newVideo.rightVideo = "file:///path/to/right.mp4"
        container.mainContext.insert(newVideo)
        
        return VideoView(video: newVideo, playerViewModel: VideoPlay())
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
