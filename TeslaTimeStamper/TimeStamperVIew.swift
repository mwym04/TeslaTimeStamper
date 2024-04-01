//
//  TimeStamperVIew.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 5/27/24.
//

import SwiftUI
import AVFoundation
import UIKit


struct TimeStamperVIew: View {
    
    @State var videoURL: URL?
    @State var creationDate: Date?
    
    var body: some View {
        
        Text("Completed")
            .onAppear {
                Task {
                    print(videoURL!)
                    let exportURL = await export(url: videoURL!)
                    await saveToLibrary(url: exportURL!)
                }
            }
    }
}


let sampleURL = URL(string: "file:///Users/mw/Library/Developer/CoreSimulator/Devices/CDEE7A78-2E59-4C8C-8A3B-2326B69EC2C2/data/Containers/Shared/AppGroup/0F326894-290B-4AC7-8B6B-BA66249A15D3/File%20Provider%20Storage/2024-05-23_18-08-03-front-3E6E2F59-A5DD-48A2-9F69-5F9888B6633E.MP4")!

let sampleDate = Date()

private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
}
