//
//  AppTabBar.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 16/06/26.
//

import SwiftUI

enum AppScreen { case home, graph, chat }

struct AppTabBar: View {
    @Binding var screen: AppScreen
    var onNew: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            item(icon: "house.fill", label: "Home", selected: screen == .home) {
                screen = .home
            }
            item(icon: "point.3.connected.trianglepath.dotted", label: "Graph", selected: screen == .graph) {
                screen = .graph
            }
            item(icon: "plus", label: "New", selected: false) {
                onNew()
            }
            item(icon: "sparkles", label: "ChatAI", selected: screen == .chat) {
                screen = .chat
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color.cardBackground)
                .overlay(Capsule().stroke(Color(.separator), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 2)
        )
        .padding(.horizontal, 44)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func item(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(label)
                    .font(.custom("HelveticaNeue-Medium", size: 11))
            }
            .foregroundStyle(selected ? Color.bluePrimary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule()
                    .fill(selected ? Color.blueLight.opacity(0.22) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        AppBackground()
        AppTabBar(screen: .constant(.home), onNew: {})
    }
}
