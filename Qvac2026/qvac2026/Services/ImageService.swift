//
//  ImageService.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import UIKit
import Foundation

/// Static helpers for storing and retrieving images attached to notes.
enum ImageService {

    /// Persistent `Images/` subdirectory inside the app Documents folder.
    /// Created on first access.
    static var imageDirectory: URL {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Resolves a relative filename (as stored in the DB) to its full on-disk URL.
    static func url(forRelative name: String) -> URL {
        imageDirectory.appendingPathComponent(name)
    }

    /// Writes `image` to the Images directory as a JPEG and returns the relative
    /// filename, or `nil` if encoding fails.
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let filename = "Img-\(UUID().uuidString).jpg"
        let fileURL  = url(forRelative: filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            print("ImageService.save: \(error)")
            return nil
        }
    }

    /// Loads and returns the image for a given relative filename, or `nil` if the
    /// file doesn't exist or can't be decoded.
    static func load(relativeName: String) -> UIImage? {
        UIImage(contentsOfFile: url(forRelative: relativeName).path)
    }

    /// Silently deletes the file for a given relative filename.
    static func delete(relativeName: String) {
        try? FileManager.default.removeItem(at: url(forRelative: relativeName))
    }
}
