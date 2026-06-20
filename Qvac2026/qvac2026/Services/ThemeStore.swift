//
//  ThemeStore.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 15/06/26.
//

import SwiftUI
import Combine

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published var appearance: Appearance

    private let key = "appearance"

    private init() {
        let raw = DatabaseService.shared.settings.string(forKey: key)
        appearance = Appearance(rawValue: raw ?? "") ?? .system
    }

    func set(_ new: Appearance) {
        appearance = new
        DatabaseService.shared.settings.set(new.rawValue, forKey: key)
    }
}
