//
//  ImageViewerView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import SwiftUI
import UIKit

/// Image viewer presented via `.fullScreenCover`.
///
/// Renders as a centered pop-up over a translucent dimmed scrim rather than an
/// opaque full-screen cover. Supports pinch-to-zoom, drag-to-pan (when zoomed),
/// double-tap to reset, a close button, a download button, and tap-outside-to-dismiss.
struct ImageViewerView: View {

    let image: UIImage

    @Environment(\.dismiss) private var dismiss

    @State private var scale:      CGFloat = 1
    @State private var offset:     CGSize  = .zero
    @State private var lastScale:  CGFloat = 1
    @State private var lastOffset: CGSize  = .zero
    @State private var showShare:  Bool    = false

    var body: some View {
        ZStack {
            // Translucent scrim — tap anywhere outside the image to dismiss
            Color.black
                .opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { dismiss() } }

            // Centered image
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(20)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in scale = max(1, lastScale * value) }
                            .onEnded   { _ in lastScale = scale },
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1 else { return }
                                offset = CGSize(
                                    width:  lastOffset.width  + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        scale      = 1
                        offset     = .zero
                        lastScale  = 1
                        lastOffset = .zero
                    }
                }

            // Top bar: close (leading) + download (trailing)
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20)

                    Spacer()

                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 52)
                Spacer()
            }
        }
        .presentationBackground(.clear)
        .sheet(isPresented: $showShare) {
            ActivityView(items: [image])
        }
    }
}

// MARK: - ActivityView

/// Thin `UIViewControllerRepresentable` wrapper around `UIActivityViewController`.
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
