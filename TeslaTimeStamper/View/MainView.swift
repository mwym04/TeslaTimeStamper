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
    @Environment(\.editMode) private var editMode
    
    var body: some View {
        VideoListView(modelContext: modelContext)
    }
}

#Preview {
    MainView()
        .modelContainer(for: Video.self)
}
