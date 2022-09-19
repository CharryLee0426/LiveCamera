//
//  FrameView.swift
//  LiveCamera
//
//  Created by 李晨 on 2022/9/19.
//  Description: This is a SwiftUI view that render the frame on the screen.

import SwiftUI

struct FrameView: View {
    var image: CGImage?
    private let label = Text("Frame")
    
    var body: some View {
        if let image = image {
            Image(image, scale: 1.0, orientation: .up, label: label)
        } else {
            Color.black
        }
    }
}
