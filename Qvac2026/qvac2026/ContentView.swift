//
//  ContentView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import SwiftUI

enum NoteRoute: Hashable {
    case new(UUID)
    case existing(Note)

    var destinationID: String {
        switch self {
        case .new(let id):       "new-\(id.uuidString)"
        case .existing(let note): "existing-\(note.id.uuidString)"
        }
    }
}

struct ContentView: View {

    @State private var screen: AppScreen = .home
    @State private var path = NavigationPath()
    @State private var refreshTick = 0

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch screen {
                case .home: HomeView(refreshTick: refreshTick)
                case .graph:
                    TrustedGraphView(refreshTick: refreshTick) { note in
                        path.append(NoteRoute.existing(note))
                    }
                case .chat: ChatAIView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                AppTabBar(
                    screen: $screen,
                    onNew: { path.append(NoteRoute.new(UUID())) }
                )
            }
            .navigationDestination(for: NoteRoute.self) { route in
                switch route {
                case .new(let id):
                    NewNoteView(noteID: id)
                        .id(route.destinationID)
                case .existing(let note):
                    NoteDetailView(note: note)
                        .id(route.destinationID)
                }
            }
        }
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty { refreshTick += 1 }
        }
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .bgMid,    location: 0.00),
                .init(color: .bgMid,    location: 0.42),
                .init(color: .bgBottom, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension Color {
    static let labelPrimary   = Color("Colors/LabelPrimary")
    static let labelSecondary = Color("Colors/LabelSecondary")
    static let labelTertiary  = Color("Colors/LabelTertiary")
    static let bgTop          = Color("Colors/BgTop")
    static let bgMid          = Color("Colors/BgMid")
    static let bgBottom       = Color("Colors/BgBottom")
    static let cardBackground = Color("Colors/CardBackground")
    static let iconBackground = Color("Colors/IconBackground")
    static let bluePrimary    = Color("Colors/BluePrimary")
    static let blueLight      = Color("Colors/BlueLight")
    static let blueMedium     = Color("Colors/BlueMedium")
    static let blueBold       = Color("Colors/BlueBold")
    static let blueBorder     = Color("Colors/BlueBorder")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double(int >> 16) / 255
        let g = Double(int >> 8 & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
