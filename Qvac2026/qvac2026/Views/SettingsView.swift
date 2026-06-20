//
//  SettingsView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 14/06/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore

    private let inactiveRows: [(label: String, icon: String)] = [
        ("Models",       "cpu"),
        ("Device Sync",  "macbook.and.iphone"),
        ("iCloud",       "icloud"),
        ("Help",         "questionmark.circle"),
    ]

    var body: some View {
        ZStack(alignment: .top) {   
            VStack(spacing: 0) {
                headerBar
                rowList
                Spacer()
                versionFooter
                    .padding(.bottom, 24)
            }
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
            }
            Text("Settings")
                .font(.custom("HelveticaNeue-Bold", size: 16))
                .foregroundStyle(Color.labelPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var rowList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.labelPrimary)
                    .frame(width: 22, height: 22)
                Text("Appearance")
                    .font(.custom("HelveticaNeue-Medium", size: 14))
                    .foregroundStyle(Color.labelPrimary)
                Spacer()
                Menu {
                    ForEach(Appearance.allCases) { option in
                        Button {
                            theme.set(option)
                        } label: {
                            if theme.appearance == option {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(theme.appearance.label)
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)

            ForEach(inactiveRows, id: \.label) { row in
                Button(action: {}) {
                    settingsRowContent(label: row.label, icon: row.icon)
                }
                .buttonStyle(.plain)
            }

            NavigationLink { TrashView() } label: {
                settingsRowContent(label: "Trash", icon: "trash")
            }
            .buttonStyle(.plain)
        }
    }

    private func settingsRowContent(label: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color.labelPrimary)
                .frame(width: 22, height: 22)
            Text(label)
                .font(.custom("HelveticaNeue-Medium", size: 14))
                .foregroundStyle(Color.labelPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
    }

    private var versionFooter: some View {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build  = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return Text("App Version \(short).\(build)")
            .font(.custom("HelveticaNeue", size: 14))
            .foregroundStyle(Color.labelSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(ThemeStore.shared)
}
