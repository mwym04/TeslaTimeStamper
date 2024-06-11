//
//  ContentView.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 5/22/24.
//

import SwiftUI
import AVFoundation
import AVKit

struct ContentView: View {
    @State private var isFileImporterPresented = false
    @State private var isSheetPresented = false
    @State private var selectedVideoURL: URL?
    @State private var creationDate: Date?
    @State private var player: AVPlayer?
    @State private var playerItem: AVPlayerItem?
    @State private var animation = false
    @State private var showAlert = false
    
    @Environment(\.verticalSizeClass) var horizontalSizeClass

    @StateObject private var videoExporter: VideoExporter = VideoExporter()
    
    var body: some View {
        NavigationStack {
            
            Spacer()
            ZStack{
                VStack {
                    if let player = player {
                        VideoPlayer(player: player)
                        if horizontalSizeClass == .regular {
                            if let date = creationDate {
                                Text("촬영일시: \(formattedDate(date))")
                            } else {
                                Text("N/A")
                            }
                        } else {
                            
                        }
                    } else {
                        Text("비디오를 선택하세요.")
                            .padding()
                    }
                }
                if videoExporter.isCompleted {
                    VStack{
                        if #available(iOS 17.0, *) {
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
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.green)
                                .onAppear(perform: {
                                    animation = true
                                })
                                .onDisappear {
                                    animation = false
                                }
                        }
                    }
                }
                
                if videoExporter.isExporting {
                    VStack {
                        ProgressView(value: videoExporter.progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(Color.white)
                            .animation(.linear(duration: 0.1), value: videoExporter.progress)
                            .padding()
                        Text("\(Int(videoExporter.progress * 100))%")
                    }
                }
                Spacer()
            }
            Spacer()
            Button {
                Task {
                    if let exportURL = try await videoExporter.export(url: selectedVideoURL!, creationDate: creationDate!) {
                        await videoExporter.saveToLibrary(url: exportURL)
                    } else {
                        DispatchQueue.main.async {
                            self.showAlert = true
                        }
                    }
                }
            } label: {
                if selectedVideoURL != nil, horizontalSizeClass == .regular {
                        Text("타임스탬프")
                            .font(.title3)
                            .bold()
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(videoExporter.isExporting ? Color.gray : Color.blue)
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
                            .padding()
                }
            }
            .disabled(videoExporter.isExporting)
        
            .alert(Text("주의"), isPresented: $showAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("인코딩 중 백그라운드로 넘어가면 작업이 취소됩니다.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        isFileImporterPresented = true
                    }, label: {
                        Text("선택")
                            .foregroundStyle(videoExporter.isExporting ? Color.gray : Color.blue)
                    })
                    .disabled(videoExporter.isExporting)
                }
            }
            
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        handleNewVideoURL(url)
                        videoExporter.isCompleted = false
                    }
                case .failure(let error):
                    print("Failed to select video: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleNewVideoURL(_ url: URL) {
        let gotAccess = url.startAccessingSecurityScopedResource()
        if !gotAccess {
            print("Could not get access to the resource.")
            return
        }
        
        if let oldURL = selectedVideoURL {
            oldURL.stopAccessingSecurityScopedResource()
        }
        
        selectedVideoURL = url
        
        Task {
            await loadCreationDate(from: url)
            let playerItem = AVPlayerItem(url: url)
            DispatchQueue.main.async {
                if self.player == nil {
                    self.player = AVPlayer(playerItem: playerItem)
                } else {
                    self.player?.replaceCurrentItem(with: playerItem)
                }
                self.playerItem = playerItem
            }
        }
    }
    
    private func loadCreationDate(from url: URL) async {
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration) + 1
            
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
            
            if let creationDate = resourceValues.creationDate {
                if let newDate = Calendar.current.date(byAdding: .second, value: -Int(seconds), to: creationDate) {
                    self.creationDate = newDate
                }
            } else {
                self.creationDate = nil
            }
            
        } catch {
            print("Failed to load metadata: \(error.localizedDescription)")
            creationDate = nil
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }
    
}

#Preview {
    ContentView()
}
