//
//  PlayButton.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/1/24.
//

import SwiftUI
import SwiftData

struct ButtonView: View {
    
    @State private var isFrontActive: Bool = true
    @State private var isBackActive: Bool = true
    @State private var isLeftActive: Bool = true
    @State private var isRightActive: Bool = true
    
    @ObservedObject var playerViewModel: VideoPlay
    @ObservedObject var exportViewModel: VideoExporter
    
    var video: Video
    let impact = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        HStack {
            Button(action: {
                playerViewModel.changeActiveVideo(from: video.getURL(from: video.frontVideo))
                updateButtonStates(active: "front")
                impact.impactOccurred()
                if exportViewModel.isCompleted {
                    exportViewModel.isCompleted = false
                }
            }, label: {
                Text("전")
                    .customButtonStyle(isActive: isFrontActive)
            })
            Button(action: {
                playerViewModel.changeActiveVideo(from: video.getURL(from: video.backVideo))
                updateButtonStates(active: "back")
                impact.impactOccurred()
                if exportViewModel.isCompleted {
                    exportViewModel.isCompleted = false
                }
            }, label: {
                Text("후")
                    .customButtonStyle(isActive: isBackActive)
                
            })
            Button(action: {
                playerViewModel.changeActiveVideo(from: video.getURL(from: video.leftVideo))
                updateButtonStates(active: "left")
                impact.impactOccurred()
                if exportViewModel.isCompleted {
                    exportViewModel.isCompleted = false
                }
            }, label: {
                Text("좌")
                    .customButtonStyle(isActive: isLeftActive)
            })
            Button(action: {
                playerViewModel.changeActiveVideo(from: video.getURL(from: video.rightVideo))
                updateButtonStates(active: "right")
                impact.impactOccurred()
                if exportViewModel.isCompleted {
                    exportViewModel.isCompleted = false
                }
            }, label: {
                Text("우")
                    .customButtonStyle(isActive: isRightActive)
            })
        }
        .disabled(exportViewModel.isExporting)
        .onChange(of: video, { oldValue, newValue in
            setInitialActiveButton()
        })
        .onAppear {
            setInitialActiveButton()
        }
    }
    
    private func updateButtonStates(active: String) {
        isFrontActive = active == "front"
        isBackActive = active == "back"
        isLeftActive = active == "left"
        isRightActive = active == "right"
    }
    
    private func setInitialActiveButton() {
        if video.frontVideo != nil {
            updateButtonStates(active: "front")
        } else if video.backVideo != nil {
            updateButtonStates(active: "back")
        } else if video.leftVideo != nil {
            updateButtonStates(active: "left")
        } else if video.rightVideo != nil {
            updateButtonStates(active: "right")
        }
    }
}

struct CustomButtonStyle: ViewModifier {
    
    var isActive: Bool
    
    func body(content: Content) -> some View {
            content
                .font(.title3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(isActive ? .blue : Color(red: 80/256, green: 80/256, blue: 80/256), in: RoundedRectangle(cornerSize: CGSize(width: 5, height: 5)))
    }
}

extension View {
    func customButtonStyle(isActive: Bool) -> some View {
        self.modifier(CustomButtonStyle(isActive: isActive))
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
        newVideo.frontVideo =  "file:///path/to/front.mp4"
        newVideo.backVideo = "file:///path/to/back.mp4"
        newVideo.leftVideo = "file:///path/to/left.mp4"
        newVideo.rightVideo =  "file:///path/to/right.mp4"
        container.mainContext.insert(newVideo)
        
        return ButtonView(playerViewModel: VideoPlay(), exportViewModel: VideoExporter(), video: newVideo)
            .modelContainer(container)
    } catch {
        fatalError("Failed to create model container: \(error.localizedDescription)")
    }
}
