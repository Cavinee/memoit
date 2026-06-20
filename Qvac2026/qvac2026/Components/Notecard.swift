//
//  Notecard.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import SwiftUI
import UIKit

struct NoteCard: View {
    let note: Note

    var body: some View {
        HStack(spacing: 14) {
            NoteIcon(type: note.type)
            noteContent
            Spacer(minLength: 8)
            moreButton
        }
        .padding(16)
        .background(cardBackground)
    }

    private var noteContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(note.title)
                    .font(.custom("HelveticaNeue-Bold", size: 15))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.orange)
                }
            }

            Text(note.preview)
                .font(.custom("HelveticaNeue", size: 13))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)

            Text(note.timeAgo)
                .font(.custom("HelveticaNeue", size: 12))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
    }

    private var moreButton: some View {
        Button(action: {}) {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondary)
                .rotationEffect(.degrees(90))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.cardBackground)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

struct NoteIcon: View {
    let type: NoteType

    private var symbolName: String {
        switch type {
        case .text:   return "doc.text.fill"
        case .audio:  return "waveform"
        case .file: return "folder.fill"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.iconBackground)
                .frame(width: 58, height: 58)

            Image(systemName: symbolName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blueLight, Color.bluePrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        NoteCard(note: Note.samples[0])
        NoteCard(note: Note.samples[2])
    }
    .padding()
    .background(Color.bgMid)
}
