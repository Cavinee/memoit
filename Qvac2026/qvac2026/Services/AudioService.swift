//
//  AudioService.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import AVFoundation
import Foundation
import Combine

// MARK: - Path helpers

/// Static helpers for locating the app's audio storage directory.
enum AudioService {
    /// Persistent `Audio/` subdirectory inside the app Documents folder.
    /// Created on first access.
    static var audioDirectory: URL {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Audio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Resolves a relative filename (as stored in the DB) to its full on-disk URL.
    static func url(forRelative name: String) -> URL {
        audioDirectory.appendingPathComponent(name)
    }

    /// Silently deletes the file for a given relative filename.
    static func delete(relativeName: String) {
        try? FileManager.default.removeItem(at: url(forRelative: relativeName))
    }
}

// MARK: - AudioRecorderService

/// Records audio to an AAC .m4a file in the app's Audio directory.
@MainActor
final class AudioRecorderService {
    private var recorder: AVAudioRecorder?
    private var currentFilename: String?

    /// Requests microphone permission. Returns `true` if granted.
    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Configures the audio session and starts recording.
    /// - Returns: The relative filename of the newly created audio file.
    func start() throws -> String {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let filename = "Rec\(Int(Date().timeIntervalSince1970)).m4a"
        let url = AudioService.url(forRelative: filename)

        let settings: [String: Any] = [
            AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:          44100.0,
            AVNumberOfChannelsKey:    1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        currentFilename = filename
        return filename
    }

    /// Stops recording. Returns duration (ms) and file size (bytes).
    func stop() -> (durationMs: Int, sizeBytes: Int64) {
        let filename = currentFilename ?? ""
        let durationMs = Int((recorder?.currentTime ?? 0) * 1000)
        recorder?.stop()
        recorder = nil
        currentFilename = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let url = AudioService.url(forRelative: filename)
        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        return (durationMs, sizeBytes)
    }

    /// Cancels recording and deletes the partial file from disk.
    func cancel() {
        recorder?.stop()
        recorder = nil
        if let filename = currentFilename {
            AudioService.delete(relativeName: filename)
            currentFilename = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - AudioPlayerController

/// Wraps `AVAudioPlayer` and exposes playback state for UI binding.
///
/// Call `configure(url:duration:)` first to associate a track, then
/// `toggle()` to play/pause. Position is preserved across pause/resume.
/// `seek(to:)` moves playback to an arbitrary time.
final class AudioPlayerController: NSObject, ObservableObject, AVAudioPlayerDelegate {

    @Published private(set) var isPlaying:   Bool         = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration:    TimeInterval = 0

    private var player:   AVAudioPlayer?
    private var audioURL: URL?
    private var timer:    Timer?

    // MARK: Configuration

    /// Associates the controller with a track. If the URL changed, any active
    /// playback is stopped first. `duration` seeds the UI immediately from the
    /// DB value before the file is actually opened.
    func configure(url: URL, duration: TimeInterval) {
        if audioURL != url { stop() }
        audioURL = url
        if duration > 0 { self.duration = duration }
    }

    // MARK: Playback

    /// Toggles play/pause, preserving the current position across pauses.
    func toggle() {
        if isPlaying {
            player?.pause()
            stopTimer()
            isPlaying = false
        } else {
            guard let p = ensurePlayer() else { return }
            p.play()
            isPlaying = true
            startTimer()
        }
    }

    /// Moves the playback head to `time`, clamped to [0, duration].
    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        ensurePlayer()?.currentTime = clamped
        currentTime = clamped
    }

    /// Stops playback and resets position to 0.
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        stopTimer()
    }

    // MARK: Private

    @discardableResult
    private func ensurePlayer() -> AVAudioPlayer? {
        if let existing = player { return existing }
        guard let url = audioURL else { return nil }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            // If the DB didn't provide a duration, read it from the file.
            if duration == 0 { duration = p.duration }
            player = p
            return p
        } catch {
            print("AudioPlayerController: \(error)")
            return nil
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            self.currentTime = p.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPlaying   = false
            self.currentTime = 0
            self.player?.currentTime = 0
            self.stopTimer()
        }
    }

    deinit { stopTimer() }
}
