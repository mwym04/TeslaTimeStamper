//
//  MainView.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/1/24.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    var body: some View {
        VideoListView()
            
    }
}

#Preview {
    MainView()
        .modelContainer(for: Video.self)
}
