//
//  WebViewProgressBar.swift
//  WebViewWrapper
//
//  Created by Sopnil Sohan on 11/12/25.
//

import SwiftUI

struct WebViewProgressBar: View {
    let progress: Double
    var height: CGFloat = 3
    var foregroundColor: Color = .blue
    var backgroundColor: Color = .gray.opacity(0.3)
    var animationDuration: Double = 0.2
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(backgroundColor)
                    .frame(width: geometry.size.width, height: height)
                
                Rectangle()
                    .fill(foregroundColor)
                    .frame(width: geometry.size.width * CGFloat(progress), height: height)
                    .animation(.easeInOut(duration: animationDuration), value: progress)
            }
        }
        .frame(height: height)
    }
}

