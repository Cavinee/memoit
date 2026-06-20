//
//  AttachmentRowView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 16/06/26.
//

import SwiftUI

struct AttachmentRowView: View {
    let attachment: Attachment
    let onDelete: () -> Void

    @State private var showRename = false
    @State private var renameText = ""

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text(attachment.filename)
                .font(.custom("HelveticaNeue", size: 14))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Menu {
                if attachment.type == .audio {
                    Button { } label: {
                        Label("Transcribe", systemImage: "waveform.badge.mic")
                    }
                    Button { renameText = attachment.filename; showRename = true } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                }
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(90))
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .alert("Rename", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") {}
            Button("Cancel", role: .cancel) {}
        }
    }

    private var iconName: String {
        switch attachment.type {
        case .audio:  "play.fill"
        case .file:   "doc.fill"
        case .image:  "photo.fill"
        case .camera: "camera.fill"
        }
    }

    private var iconColor: Color {
        switch attachment.type {
        case .audio:          Color.bluePrimary
        case .file:           Color.blueMedium
        case .image, .camera: Color.blueLight
        }
    }
}
