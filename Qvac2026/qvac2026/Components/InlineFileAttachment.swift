//
//  InlineFileAttachment.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import UIKit

// MARK: - FileAttachmentHosting

/// Callbacks from an inline file card back to the owning view model.
protocol FileAttachmentHosting: AnyObject {
    func openInlineFile(id: UUID)
    func deleteInlineFile(id: UUID)
}

// MARK: - FileTextAttachment

/// An `NSTextAttachment` subclass representing an inline file attachment.
///
/// The visible `FileCardView` is provided via `NSTextAttachmentViewProvider`
/// (TextKit 2), so the text engine owns placement — no layoutSubviews loop.
///
/// `fileId` (the DB attachment's UUID string) is encoded for persistence via
/// `NSKeyedArchiver`. `host` is a weak back-reference and is intentionally
/// NOT encoded.
@objc(FileTextAttachment)
final class FileTextAttachment: NSTextAttachment {

    var fileId: String = ""
    weak var host: FileAttachmentHosting?

    override class var supportsSecureCoding: Bool { true }

    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
    }

    convenience init(fileId: String) {
        self.init(data: nil, ofType: nil)
        self.fileId = fileId
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fileId = (coder.decodeObject(of: NSString.self, forKey: "fileId") as? String) ?? ""
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(fileId as NSString, forKey: "fileId")
    }

    // MARK: - NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        let copy = FileTextAttachment(fileId: self.fileId)
        copy.host = self.host
        copy.bounds = self.bounds
        return copy
    }

    // MARK: - NSTextAttachmentViewProvider (TextKit 2)

    override func viewProvider(
        for parentView: UIView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        let provider = FileAttachmentViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }
}

// MARK: - FileAttachmentViewProvider

/// TextKit 2 view provider that creates and configures the `FileCardView` for
/// each `FileTextAttachment`. The text engine calls `loadView()` once and then
/// owns the view's frame.
final class FileAttachmentViewProvider: NSTextAttachmentViewProvider {

    private let cardHeight: CGFloat = 64   // single-row card
    private let topPadding: CGFloat = 12   // gap above the card

    override func loadView() {
        let container = AttachmentContainerView()
        container.backgroundColor = .clear

        let card = FileCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: topPadding),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container

        guard let att = textAttachment as? FileTextAttachment,
              !att.fileId.isEmpty else { return }

        let fileId = att.fileId
        let id     = UUID(uuidString: fileId)
        let dbAtt  = id.flatMap { DatabaseService.shared.attachments.fetch(id: $0) }

        card.configure(
            filename:  dbAtt?.filename ?? "File",
            byteSize:  dbAtt?.sizeBytes ?? 0
        ) { [weak att] in
            guard let id = UUID(uuidString: fileId) else { return }
            att?.host?.openInlineFile(id: id)
        } onDelete: { [weak att] in
            guard let id = UUID(uuidString: fileId) else { return }
            att?.host?.deleteInlineFile(id: id)
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

// MARK: - FileCardView

/// Pure-UIKit single-row card for an inline file attachment.
///
/// Layout: [ 🟦doc icon ] [ filename / size ] ············ [ ⋯ menu ]
///
/// Tapping anywhere on the left content area (icon + labels) triggers `onTap`.
/// The ellipsis menu is independent and shows a destructive Delete action.
final class FileCardView: UIView {

    private let iconView   = UIView()
    private let iconImage  = UIImageView()
    private let nameLabel  = UILabel()
    private let sizeLabel  = UILabel()
    private let menuButton = UIButton(type: .system)

    private var onTap: (() -> Void)?

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

        // --- Circular icon background ---
        iconView.backgroundColor    = UIColor(named: "Colors/BlueMedium") ?? .systemBlue
        iconView.layer.cornerRadius = 16
        iconView.layer.masksToBounds = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        iconImage.image       = UIImage(systemName: "doc.fill", withConfiguration: iconConfig)
        iconImage.tintColor   = .white
        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImage)
        NSLayoutConstraint.activate([
            iconImage.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
        ])

        // --- Name label ---
        nameLabel.font          = UIFont(name: "HelveticaNeue", size: 14) ?? .systemFont(ofSize: 14)
        nameLabel.textColor     = .label
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // --- Size label ---
        sizeLabel.font      = UIFont(name: "HelveticaNeue", size: 11) ?? .systemFont(ofSize: 11)
        sizeLabel.textColor = .secondaryLabel
        sizeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sizeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // --- Labels stack ---
        let labelStack = UIStackView(arrangedSubviews: [nameLabel, sizeLabel])
        labelStack.axis    = .vertical
        labelStack.spacing = 2

        // --- Tappable left area (icon + labels) ---
        let leftContent = UIView()
        leftContent.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(contentTapped))
        leftContent.addGestureRecognizer(tap)

        iconView.translatesAutoresizingMaskIntoConstraints          = false
        labelStack.translatesAutoresizingMaskIntoConstraints        = false
        leftContent.translatesAutoresizingMaskIntoConstraints       = false
        leftContent.addSubview(iconView)
        leftContent.addSubview(labelStack)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leftContent.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: leftContent.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            labelStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            labelStack.trailingAnchor.constraint(equalTo: leftContent.trailingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: leftContent.centerYAnchor),
        ])

        // --- Ellipsis menu button ---
        let ellipsisConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        menuButton.setImage(UIImage(systemName: "ellipsis", withConfiguration: ellipsisConfig), for: .normal)
        menuButton.tintColor = .secondaryLabel
        menuButton.transform = CGAffineTransform(rotationAngle: .pi / 2)
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leftContent)
        addSubview(menuButton)

        NSLayoutConstraint.activate([
            menuButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            menuButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 24),
            menuButton.heightAnchor.constraint(equalToConstant: 24),

            leftContent.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            leftContent.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            leftContent.topAnchor.constraint(equalTo: topAnchor),
            leftContent.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Configuration

    func configure(
        filename: String,
        byteSize: Int64,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        nameLabel.text = filename
        sizeLabel.text = Self.formattedSize(byteSize)
        self.onTap     = onTap

        let deleteAction = UIAction(
            title:      "Delete",
            image:      UIImage(systemName: "trash"),
            attributes: .destructive
        ) { _ in onDelete() }
        menuButton.menu = UIMenu(children: [deleteAction])
    }

    // MARK: - Actions

    @objc private func contentTapped() {
        onTap?()
    }

    // MARK: - Helpers

    private static func formattedSize(_ bytes: Int64) -> String {
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useKB, .useMB, .useGB]
        fmt.countStyle   = .file
        return fmt.string(fromByteCount: bytes)
    }
}
