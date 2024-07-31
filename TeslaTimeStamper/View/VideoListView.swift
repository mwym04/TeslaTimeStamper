//
//  VideoListView.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/1/24.
//

import SwiftUI
import SwiftData

struct VideoListView: View {
    
    @StateObject private var viewModel: VideoListViewModel
    @ObservedObject var playerViewModel: VideoPlay = VideoPlay()
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: VideoListViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack {
                List(viewModel.videos, id: \.self, selection: $viewModel.multiSelection) { video in
                    HStack {
                        VStack(alignment: .leading, content: {
                            HStack {
                                Text(video.convertDateFormat(video.date))
                            }.transition(.slide)
                            HStack(alignment: .bottom, content: {
                                Spacer()
                                Text("전")
                                    .foregroundStyle(video.frontVideo != nil ? .blue : .white)
                                Text("후")
                                    .foregroundStyle(video.backVideo != nil ? .blue : .white)
                                Text("좌")
                                    .foregroundStyle(video.leftVideo != nil ? .blue : .white)
                                Text("우")
                                    .foregroundStyle(video.rightVideo != nil ? .blue : .white)
                            })
                        })
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .tint(Color(red: 51/255, green: 51/255, blue: 51/255))
                .animation(.smooth, value: viewModel.videos)
                
                VStack {
                    if viewModel.isProcessing {
                        ProgressView("비디오 불러오는 중...", value: viewModel.progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                            .animation(.easeInOut, value: viewModel.progress)
                        Text("\(viewModel.processedFiles)/\(viewModel.totalFiles) 파일 처리됨")
                    }
                }
            }
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack{
                        Button(viewModel.isEditing ? "완료" : "선택") {
                            withAnimation(.easeInOut) {
                                viewModel.isEditing.toggle()
                            }
                        }
                        Button(action: {
                            viewModel.deleteSelectedVideos()
                            viewModel.isEditing.toggle()
                        }, label: {
                            Image(systemName: "trash")
                                .tint(Color.red)
                                .opacity(viewModel.isEditing ? 1 : 0)
                        })
                        .disabled(viewModel.multiSelection.isEmpty)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.isFileImporterPresented = true
                    }, label: {
                        Image(systemName: "plus")
                    })
                }
            }
            .environment(\.editMode, .constant(viewModel.isEditing ? .active : .inactive))
            .fileImporter(isPresented: $viewModel.isFileImporterPresented, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    
                    DispatchQueue.main.async {
                        viewModel.isProcessing = true
                        viewModel.totalFiles = urls.count
                        viewModel.processedFiles = 0
                        viewModel.progress = 0
                    }
                    
                    Task {
                        let taskId = UIApplication.shared.beginBackgroundTask()
                        
                        for url in urls {
                            await viewModel.videoSaveToList(from: url)
                            
                            DispatchQueue.main.async {
                                viewModel.processedFiles += 1
                                viewModel.progress = Float(viewModel.processedFiles) / Float(viewModel.totalFiles)
                            }
                        }
                        
                        DispatchQueue.main.async {
                            viewModel.isProcessing = false
                        }
                        
                        UIApplication.shared.endBackgroundTask(taskId)
                    }
                    viewModel.fetchVideos()
                    
                case .failure(let error):
                    print("Failed to select video: \(error.localizedDescription)")
                }
            }
            .alert("Tesla 차량의 블랙박스 영상만 삽입됩니다.", isPresented: $viewModel.showAlert, actions: {})
            .navigationTitle("블랙박스 영상")
            .navigationBarTitleDisplayMode(.automatic)
        } detail: {
            if let video = viewModel.multiSelection.first {
                VideoView(video: video, playerViewModel: playerViewModel)
                    .onDisappear {
                        viewModel.multiSelection.remove(video)
                    }
            } else {
                Text("비디오를 선택하세요.")
            }
        }
        
        .onChange(of: viewModel.multiSelection.first, { oldValue, newValue in
            if let video = newValue {
                let videoURL = [video.frontVideo, video.backVideo, video.leftVideo, video.rightVideo].compactMap({ $0 }).first
                playerViewModel.updatePlayer(with: videoURL)
            }
        })
        
        .onAppear(perform: { requestNotificationPermission() })
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

#Preview {
    // SwiftData의 ModelContainer를 생성합니다.
    let container = try! ModelContainer(for: Video.self)
    
    // VideoListView를 반환합니다.
    return VideoListView(modelContext: container.mainContext)
        .modelContainer(container)
}
