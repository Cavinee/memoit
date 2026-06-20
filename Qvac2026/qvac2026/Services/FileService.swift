//
//  FileService.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import Foundation

/// Static helpers for storing and retrieving generic file attachments.
enum FileService {

    /// Persistent `Files/` subdirectory inside the app Documents folder.
    /// Created on first access.
    static var fileDirectory: URL {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Files", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Resolves a relative filename (as stored in the DB) to its full on-disk URL.
    static func url(forRelative name: String) -> URL {
        fileDirectory.appendingPathComponent(name)
    }

    /// Copies `sourceURL` into the Files directory under a unique name that
    /// preserves the original extension.
    ///
    /// - Returns: The relative filename, the original display name
    ///   (`lastPathComponent`), and the byte size; or `nil` if the copy fails.
    static func save(from sourceURL: URL) -> (relativeName: String, displayName: String, sizeBytes: Int64)? {
        let displayName  = sourceURL.lastPathComponent
        let ext          = sourceURL.pathExtension
        let uniquePrefix = UUID().uuidString
        let relativeName = ext.isEmpty ? uniquePrefix : "\(uniquePrefix).\(ext)"
        let destURL      = url(forRelative: relativeName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let sizeBytes = (try? FileManager.default
                .attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
            return (relativeName, displayName, sizeBytes)
        } catch {
            print("FileService.save: \(error)")
            return nil
        }
    }

    /// Silently deletes the file for a given relative filename.
    static func delete(relativeName: String) {
        try? FileManager.default.removeItem(at: url(forRelative: relativeName))
    }
}
