//
//  VideoListView.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/1/24.
//

import SwiftUI
import SwiftData

struct VideoListView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    
    @Query(sort: \Video.date, order: .forward) private var videos: [Video]
    @State private var multiSelection = Set<Video>()
    
    @State var isFileImporterPresented = false
    @State private var showAlert = false
    @State private var isProcessing = false
    @State private var progress: Float = 0
    @State private var totalFiles: Int = 0
    @State private var processedFiles: Int = 0
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack{
            VStack {
                List(videos, id: \.self, selection: $multiSelection) { video in
                    if !isProcessing {
                        NavigationLink {
                            VideoView(video: video)
                                .onDisappear {
                                    multiSelection.remove(video)
                                }
                        } label: {
                            VStack(alignment: .leading, content: {
                                Text(video.convertDateFormat(video.date))
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
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, content: {
                                Text(video.convertDateFormat(video.date))
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
                        }
                    }
                }
                .animation(.smooth, value: videos)
                .animation(.snappy, value: isEditing)
                VStack {
                    if isProcessing {
                        ProgressView("비디오 불러오는 중...", value: progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                            .animation(.easeInOut, value: progress)
                        Text("\(processedFiles)/\(totalFiles) 파일 처리됨")
                    }
                }
            }
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack{
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                        }
                        Button(action: {
                            deleteSelectedVideos()
                        }, label: {
                            Image(systemName: "trash")
                                .tint(Color.red)
                                .opacity(isEditing ? 1 : 0)
                        })
                        .disabled(multiSelection.isEmpty)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        isFileImporterPresented = true
                    }, label: {
                        Image(systemName: "plus")
                    })
                }
            }
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .onChange(of: editMode?.wrappedValue, { oldValue, newValue in
                isEditing = (newValue == .active)
            })
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    
                    DispatchQueue.main.async {
                        isProcessing = true
                        totalFiles = urls.count
                        processedFiles = 0
                        progress = 0
                    }
                    
                    Task {
                        let taskId = UIApplication.shared.beginBackgroundTask()
                        
                        for url in urls {
                            await videoSaveToList(from: url)
                            
                            DispatchQueue.main.async {
                                processedFiles += 1
                                progress = Float(processedFiles) / Float(totalFiles)
                            }
                        }
                        
                        DispatchQueue.main.async {
                            isProcessing = false
                        }
                        
                        UIApplication.shared.endBackgroundTask(taskId)
                    }
                    
                case .failure(let error):
                    print("Failed to select video: \(error.localizedDescription)")
                }
            }
            .alert("Tesla 차량의 블랙박스 영상만 삽입됩니다.", isPresented: $showAlert, actions: {
                
            })
            .navigationTitle("블랙박스 영상")
            .navigationBarTitleDisplayMode(.automatic)
        }
        .onAppear(perform: {
            requestNotificationPermission()
        })
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            
        }
    }
    
    private func deleteSelectedVideos() {
        
        let fileManager = FileManager.default
        
        for video in multiSelection {
            func deleteFile(at url: URL?) {
                guard let url = url else { return }
                do {
                    try fileManager.removeItem(at: url)
                    print("파일 삭제 성공: \(url.lastPathComponent)")
                } catch {
                    print("파일 삭제 실패: \(url.lastPathComponent), 에러: \(error.localizedDescription)")
                }
            }
            deleteFile(at: video.frontVideo)
            deleteFile(at: video.backVideo)
            deleteFile(at: video.leftVideo)
            deleteFile(at: video.rightVideo)
            
            modelContext.delete(video)
        }
        multiSelection.removeAll()
        
    }
    
    private func videoSaveToList(from url: URL) async {
        
        let fileName: String = url.deletingPathExtension().lastPathComponent
        let position: String = extractSuffix(from: fileName)
        
        if fileName == position {
            showAlert = true
            return
        }
        
        if !["front", "back", "left_repeater", "right_repeater"].contains(position) {
            showAlert = true
            return
        }
        
        let date: String = String(fileName.prefix(fileName.count - position.count - 1))
        
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
        print(extractURL(from: url)!)
        
        DispatchQueue.main.async {
            if let video = videos.first {
                switch position {
                case "front":
                    video.frontVideo = extractURL(from: url)
                case "back":
                    video.backVideo = extractURL(from: url)
                case "left_repeater":
                    video.leftVideo = extractURL(from: url)
                case "right_repeater":
                    video.rightVideo = extractURL(from: url)
                default:
                    break
                }
            } else {
                let newVideo = Video(date: date)
                switch position {
                case "front":
                    newVideo.frontVideo = extractURL(from: url)
                case "back":
                    newVideo.backVideo = extractURL(from: url)
                case "left_repeater":
                    newVideo.leftVideo = extractURL(from: url)
                case "right_repeater":
                    newVideo.rightVideo = extractURL(from: url)
                default:
                    break
                }
                modelContext.insert(newVideo)
            }
        }
        
        do {
            try modelContext.save()
            print("Updated successfully")
        } catch {
            print("Failed to save changes: \(error)")
        }
    }
    
    private func extractSuffix(from input: String) -> String {
        let components = input.split(separator: "-")
        if let lastComponent = components.last {
            return String(lastComponent)
        }
        return ""
    }
    
    private func moveFile(from sourceURL: URL) async {
        
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
    
    private func extractURL(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            print("문서 디렉토리를 찾을 수 없습니다.")
            return nil
        }
        
        let videosDirectory = libraryDirectory.appendingPathComponent("Videos")
        
        let destinationURL = videosDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        
        return destinationURL
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Video.self, configurations: config)
        
        // 기존의 모든 Video 인스턴스 삭제
        try container.mainContext.delete(model: Video.self)
        
        // 새로운 Video 인스턴스 하나 추가
        let newVideo = Video(date: "2024-07-01_20-49-42")
        newVideo.frontVideo = URL(string: "file:///path/to/front.mp4")
        newVideo.backVideo = URL(string: "file:///path/to/back.mp4")
        newVideo.leftVideo = URL(string: "file:///path/to/left.mp4")
        newVideo.rightVideo = URL(string: "file:///path/to/right.mp4")
        container.mainContext.insert(newVideo)
        
        return VideoListView()
            .modelContainer(container)
    } catch {
        fatalError("Failed to create model container: \(error.localizedDescription)")
    }
}
