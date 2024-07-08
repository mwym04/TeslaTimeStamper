//
//  CustomButton.swift
//  TeslaTimeStamper
//
//  Created by LeeMinwoo on 5/24/24.
//

import Foundation
import SwiftUI

struct BlueButton: View {
    var title: String
    
    var body: some View {
        Text(title)
            .font(.title3)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color.blue)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
            .padding()
    }
}

struct GrayButton: View {
    var title: String
    
    var body: some View {
        Text(title)
            .font(.title3)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color.gray)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
            .padding()
    }
}
