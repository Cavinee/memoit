//
//  InlineAudioAttachment.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import UIKit
import Combine

// MARK: - AudioAttachmentHosting

/// Callbacks from an inline audio card back to the owning view model.
protocol AudioAttachmentHosting: AnyObject {
    func deleteInlineAudio(id: UUID)
}

// MARK: - AudioTextAttachment

/// An `NSTextAttachment` subclass representing an inline audio recording.
///
/// The attachment reserves a full-width slot in the text flow.
/// The visible `AudioCardView` is provided via `NSTextAttachmentViewProvider`
/// (TextKit 2), so the text engine owns placement — no layoutSubviews loop.
///
/// `audioId` (the DB attachment's UUID string) is encoded for persistence via
/// `NSKeyedArchiver`. `host` is a weak back-reference and is intentionally
/// NOT encoded.
@objc(AudioTextAttachment)
final class AudioTextAttachment: NSTextAttachment {

    var audioId: String = ""
    weak var host: AudioAttachmentHosting?

    override class var supportsSecureCoding: Bool { true }

    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
    }

    convenience init(audioId: String) {
        self.init(data: nil, ofType: nil)
        self.audioId = audioId
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        audioId = (coder.decodeObject(of: NSString.self, forKey: "audioId") as? String) ?? ""
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(audioId as NSString, forKey: "audioId")
    }

    // MARK: - NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        let copy = AudioTextAttachment(audioId: self.audioId)
        copy.host = self.host
        copy.bounds = self.bounds
        return copy
    }

    // MARK: - NSTextAttachmentViewProvider (TextKit 2)

    /// Called by TextKit 2 to obtain a view provider for this attachment.
    /// The provider creates and configures the `AudioCardView`.
    override func viewProvider(
        for parentView: UIView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        let provider = AudioAttachmentViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }
}

// MARK: - AudioAttachmentViewProvider

/// TextKit 2 view provider that creates and configures the `AudioCardView` for
/// each `AudioTextAttachment`. The text engine calls `loadView()` once and then
/// owns the view's frame — no manual `layoutSubviews` override needed.
final class AudioAttachmentViewProvider: NSTextAttachmentViewProvider {

    private let cardHeight: CGFloat = 84   // two-row card
    private let topPadding: CGFloat = 12   // gap above the card

    override func loadView() {
        // Transparent container — top `topPadding` stays clear, card fills the rest.
        let container = AttachmentContainerView()
        container.backgroundColor = .clear

        let card = AudioCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: topPadding),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container

        guard let att = textAttachment as? AudioTextAttachment,
              !att.audioId.isEmpty else { return }

        let audioId  = att.audioId
        let id       = UUID(uuidString: audioId)
        let dbAtt    = id.flatMap { DatabaseService.shared.attachments.fetch(id: $0) }
        let filename = dbAtt?.filename ?? "Recording"
        let audioURL = dbAtt.map { AudioService.url(forRelative: $0.filePath) }
        let duration = Double(dbAtt?.durationMs ?? 0) / 1000

        let uuid = UUID(uuidString: audioId) ?? UUID()
        card.configure(
            audioId:  uuid,
            filename: filename,
            audioURL: audioURL,
            duration: duration
        ) { [weak att] in
            att?.host?.deleteInlineAudio(id: uuid)
        }
    }

    /// Reserve a slot tall enough for the card plus the top gap.
    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        let w = textContainer?.size.width ?? proposedLineFragment.width
        return CGRect(x: 0, y: 0, width: max(w, 200), height: cardHeight + topPadding)
    }
}

// MARK: - AudioCardView

/// Pure-UIKit two-row card rendered as the view of an `AudioAttachmentViewProvider`.
///
/// Row 1: play button · filename · ellipsis menu
/// Row 2: elapsed label · scrub slider · total label
final class AudioCardView: UIView {

    // Row 1
    private let playButton = UIButton(type: .custom)
    private let fileLabel  = UILabel()
    private let menuButton = UIButton(type: .system)

    // Row 2
    private let slider       = UISlider()
    private let elapsedLabel = UILabel()
    private let totalLabel   = UILabel()

    private let playerController   = AudioPlayerController()
    private var playerCancellables = Set<AnyCancellable>()
    private var isScrubbing        = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func setupUI() {
        backgroundColor     = .white
        layer.cornerRadius  = 12
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius  = 8
        layer.shadowOffset  = CGSize(width: 0, height: 2)

        // --- Play button (circular) ---
        playButton.backgroundColor     = UIColor(named: "Colors/BluePrimary") ?? .systemBlue
        playButton.layer.cornerRadius  = 16
        playButton.layer.masksToBounds = true
        updatePlayIcon(playing: false)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)

        // --- Filename label ---
        fileLabel.font          = UIFont(name: "HelveticaNeue", size: 14) ?? .systemFont(ofSize: 14)
        fileLabel.textColor     = .label
        fileLabel.lineBreakMode = .byTruncatingMiddle
        fileLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        fileLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // --- Ellipsis menu button ---
        let ellipsisConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        menuButton.setImage(UIImage(systemName: "ellipsis", withConfiguration: ellipsisConfig), for: .normal)
        menuButton.tintColor = .secondaryLabel
        menuButton.transform = CGAffineTransform(rotationAngle: .pi / 2)
        menuButton.showsMenuAsPrimaryAction = true

        // --- Scrub slider ---
        slider.minimumValue          = 0
        slider.maximumValue          = 1
        slider.value                 = 0
        slider.minimumTrackTintColor = UIColor(named: "Colors/BluePrimary") ?? .systemBlue
        slider.addTarget(self, action: #selector(scrubBegan),   for: .touchDown)
        slider.addTarget(self, action: #selector(scrubChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(scrubEnded),   for: [.touchUpInside, .touchUpOutside])

        // --- Time labels ---
        let timeFont = UIFont(name: "HelveticaNeue", size: 11) ?? .systemFont(ofSize: 11)
        for label in [elapsedLabel, totalLabel] {
            label.font      = timeFont
            label.textColor = .secondaryLabel
            label.text      = "0:00"
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        // --- Row 1: play · filename · menu ---
        let row1 = UIStackView(arrangedSubviews: [playButton, fileLabel, menuButton])
        row1.axis      = .horizontal
        row1.spacing   = 12
        row1.alignment = .center

        // --- Row 2: elapsed · slider · total ---
        let row2 = UIStackView(arrangedSubviews: [elapsedLabel, slider, totalLabel])
        row2.axis      = .horizontal
        row2.spacing   = 8
        row2.alignment = .center

        // --- Outer vertical stack ---
        let outer = UIStackView(arrangedSubviews: [row1, row2])
        outer.axis      = .vertical
        outer.spacing   = 6
        outer.alignment = .fill
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)

        NSLayoutConstraint.activate([
            playButton.widthAnchor.constraint(equalToConstant: 32),
            playButton.heightAnchor.constraint(equalToConstant: 32),
            menuButton.widthAnchor.constraint(equalToConstant: 24),
            menuButton.heightAnchor.constraint(equalToConstant: 24),
            outer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            outer.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Observe player state
        playerController.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in self?.updatePlayIcon(playing: playing) }
            .store(in: &playerCancellables)

        playerController.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard let self, !self.isScrubbing else { return }
                self.slider.value      = Float(time)
                self.elapsedLabel.text = Self.timeString(time)
            }
            .store(in: &playerCancellables)

        playerController.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dur in
                guard let self else { return }
                self.slider.maximumValue = Float(max(dur, 1))
                self.totalLabel.text     = Self.timeString(dur)
            }
            .store(in: &playerCancellables)
    }

    // MARK: - Configuration

    func configure(
        audioId:  UUID,
        filename: String,
        audioURL: URL?,
        duration: TimeInterval,
        onDelete: @escaping () -> Void
    ) {
        fileLabel.text = filename

        if let url = audioURL {
            playerController.configure(url: url, duration: duration)
        }
        // Seed the UI immediately from the known DB duration.
        slider.maximumValue = Float(max(duration, 1))
        totalLabel.text     = Self.timeString(duration)

        // Rename action
        let renameAction = UIAction(
            title: "Rename",
            image: UIImage(systemName: "pencil")
        ) { [weak self] _ in
            guard let self else { return }
            self.presentRename(audioId: audioId, currentName: self.fileLabel.text ?? "")
        }

        // Download action
        let downloadAction = UIAction(
            title: "Download",
            image: UIImage(systemName: "arrow.down.to.line")
        ) { [weak self] _ in
            guard let self, let url = audioURL else { return }
            self.presentShare(items: [url])
        }

        // Delete action
        let deleteAction = UIAction(
            title:      "Delete",
            image:      UIImage(systemName: "trash"),
            attributes: .destructive
        ) { _ in onDelete() }

        menuButton.menu = UIMenu(children: [renameAction, downloadAction, deleteAction])
    }

    // MARK: - Rename / Download helpers

    private func presentRename(audioId: UUID, currentName: String) {
        let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text           = currentName
            tf.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let newName = alert?.textFields?.first?.text,
                  !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            let trimmed = newName.trimmingCharacters(in: .whitespaces)
            DatabaseService.shared.attachments.rename(id: audioId, filename: trimmed)
            self.fileLabel.text = trimmed
        })
        guard let vc = nearestViewController() else { return }
        alert.popoverPresentationController?.sourceView = menuButton
        vc.present(alert, animated: true)
    }

    private func presentShare(items: [Any]) {
        let share = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let vc = nearestViewController() else { return }
        share.popoverPresentationController?.sourceView = menuButton
        vc.present(share, animated: true)
    }

    // MARK: - Actions

    @objc private func playTapped() {
        playerController.toggle()
    }

    @objc private func scrubBegan() {
        isScrubbing = true
    }

    @objc private func scrubChanged() {
        elapsedLabel.text = Self.timeString(TimeInterval(slider.value))
    }

    @objc private func scrubEnded() {
        playerController.seek(to: TimeInterval(slider.value))
        isScrubbing = false
    }

    // MARK: - Helpers

    private func updatePlayIcon(playing: Bool) {
        let name   = playing ? "pause.fill" : "play.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        playButton.setImage(UIImage(systemName: name, withConfiguration: config), for: .normal)
        playButton.tintColor = .white
    }

    private static func timeString(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Walks the responder chain to find the nearest `UIViewController` for
    /// presenting alerts and share sheets.
    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}
