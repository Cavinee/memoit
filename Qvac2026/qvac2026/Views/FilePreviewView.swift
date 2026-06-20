//
//  FilePreviewView.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import SwiftUI
import QuickLook

/// SwiftUI wrapper around `QLPreviewController` for previewing a local file.
///
/// Present via `.sheet(item:)` passing a `PreviewFile`.
struct FilePreviewView: UIViewControllerRepresentable {

    let url: URL

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator

        let nav = UINavigationController(rootViewController: preview)
        preview.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(Coordinator.doneTapped)
        )
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, QLPreviewControllerDataSource {

        let url: URL
        let dismiss: DismissAction

        init(url: URL, dismiss: DismissAction) {
            self.url     = url
            self.dismiss = dismiss
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }

        @objc func doneTapped() {
            dismiss()
        }
    }
}
