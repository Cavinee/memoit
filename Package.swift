// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QVAC",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "QVACRuntime", targets: ["QVACRuntime"]),
        .executable(name: "qvac-runtime-harness", targets: ["QVACRuntimeHarness"]),
        .executable(name: "qvac-runtime-tests", targets: ["QVACRuntimeBehaviorTests"]),
        .executable(name: "chat-history-viewmodel-tests", targets: ["ChatHistoryViewModelBehaviorTests"])
    ],
    targets: [
        .target(
            name: "QVACRuntime",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "QVACRuntimeHarness",
            dependencies: ["QVACRuntime"]
        ),
        .executableTarget(
            name: "QVACRuntimeBehaviorTests",
            dependencies: ["QVACRuntime"]
        ),
        .executableTarget(
            name: "ChatHistoryViewModelBehaviorTests",
            dependencies: ["QVACRuntime"],
            path: ".",
            exclude: [
                ".scratch",
                "AGENTS.md",
                "CONTEXT.md",
                "docs",
                "qvac-smoke-host",
                "Sources",
                "Qvac2026/Podfile",
                "Qvac2026/Podfile.properties.json",
                "Qvac2026/Podfile.lock",
                "Qvac2026/Pods",
                "Qvac2026/Base.xcconfig",
                "Qvac2026/CLAUDE.MD",
                "Qvac2026/Debug.xcconfig",
                "Qvac2026/Local.xcconfig.example",
                "Qvac2026/PrivacyInfo.xcprivacy",
                "Qvac2026/Release.xcconfig",
                "Qvac2026/app.json",
                "Qvac2026/build",
                "Qvac2026/embedded-qvac-host",
                "Qvac2026/ios",
                "Qvac2026/node_modules",
                "Qvac2026/package.json",
                "Qvac2026/package-lock.json",
                "Qvac2026/qvac2026.xcodeproj",
                "Qvac2026/qvac2026.xcworkspace",
                "Qvac2026/qvac2026/Assets.xcassets",
                "Qvac2026/qvac2026/Components",
                "Qvac2026/qvac2026/ContentView.swift",
                "Qvac2026/qvac2026/Model",
                "Qvac2026/qvac2026/qvac2026App.swift",
                "Qvac2026/qvac2026/Services",
                "Qvac2026/qvac2026/ViewModel/GraphViewModel.swift",
                "Qvac2026/qvac2026/ViewModel/HomeViewModel.swift",
                "Qvac2026/qvac2026/ViewModel/NoteEditorViewModel.swift",
                "Qvac2026/qvac2026/ViewModel/TrashViewModel.swift",
                "Qvac2026/qvac2026/Views",
                "Qvac2026/scripts"
            ],
            sources: [
                "Qvac2026/qvac2026/ViewModel/ChatAIViewModel.swift",
                "Qvac2026/qvac2026/ViewModel/ChatHistoryViewModel.swift",
                "Tests/ChatHistoryViewModelBehaviorTests/main.swift"
            ]
        )
    ]
)
