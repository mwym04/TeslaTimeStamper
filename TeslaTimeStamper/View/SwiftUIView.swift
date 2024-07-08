//
//  SwiftUIView.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 7/8/24.
//

import SwiftUI

struct SwiftUIView: View {
    @Environment(\.editMode) private var editMode
    @State private var name = "Maria Ruiz"


    var body: some View {
        Form {
            if editMode?.wrappedValue.isEditing == true {
                TextField("Name", text: $name)
            } else {
                Text(name)
            }
        }
        .animation(nil, value: editMode?.wrappedValue)
        .toolbar { // Assumes embedding this view in a NavigationView.
            EditButton()
        }
    }
}


#Preview {
    SwiftUIView()
}
