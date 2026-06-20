//
//  InlineImageAttachment.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 17/06/26.
//

import UIKit

// MARK: - ImageAttachmentHosting

/// Callbacks from an inline image attachment back to the owning view model.
protocol ImageAttachmentHosting: AnyObject {
    func openInlineImage(id: UUID)
    func deleteInlineImage(id: UUID)
}

// MARK: - ImageTextAttachment

/// An `NSTextAttachment` subclass representing an inline image.
///
/// The visible image view is provided via `NSTextAttachmentViewProvider`
/// (TextKit 2), so the text engine owns placement and no `layoutSubviews`
/// loop is needed.
///
/// `imageId` (the DB attachment UUID string) is encoded for persistence via
/// `NSKeyedArchiver`. `host` is weak and intentionally NOT encoded.
@objc(ImageTextAttachment)
final class ImageTextAttachment: NSTextAttachment {

    var imageId: String = ""
    weak var host: ImageAttachmentHosting?

    override class var supportsSecureCoding: Bool { true }

    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
    }

    convenience init(imageId: String) {
        self.init(data: nil, ofType: nil)
        self.imageId = imageId
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        imageId = (coder.decodeObject(of: NSString.self, forKey: "imageId") as? String) ?? ""
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(imageId as NSString, forKey: "imageId")
    }

    // MARK: - NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        let copy = ImageTextAttachment(imageId: self.imageId)
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
        let provider = ImageAttachmentViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }
}

// MARK: - ImageAttachmentViewProvider

/// TextKit 2 view provider that displays the image for each `ImageTextAttachment`.
/// The text engine calls `loadView()` once and owns the view's frame.
final class ImageAttachmentViewProvider: NSTextAttachmentViewProvider {

    private let imageHeight:     CGFloat = 192
    private let topPadding:      CGFloat = 12
    private let horizontalInset: CGFloat = 8

    override func loadView() {
        let container = AttachmentContainerView()
        container.backgroundColor = .clear

        let imageView = InlineTappableImageView(frame: .zero)
        imageView.contentMode     = .scaleAspectFill
        imageView.clipsToBounds   = true
        imageView.layer.cornerRadius = 12
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor,  constant:  horizontalInset),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalInset),
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: topPadding),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        view = container

        guard let att = textAttachment as? ImageTextAttachment,
              !att.imageId.isEmpty else { return }

        let imageId = att.imageId
        let id      = UUID(uuidString: imageId)
        let dbAtt   = id.flatMap { DatabaseService.shared.attachments.fetch(id: $0) }

        if let filePath = dbAtt?.filePath,
           let img = ImageService.load(relativeName: filePath) {
            imageView.image = img
        }

        // Wire tap → host
        imageView.onTap = { [weak att] in
            guard let id = UUID(uuidString: imageId) else { return }
            att?.host?.openInlineImage(id: id)
        }
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        let w = textContainer?.size.width ?? proposedLineFragment.width
        return CGRect(x: 0, y: 0, width: max(w, 200), height: imageHeight + topPadding)
    }
}

// MARK: - InlineTappableImageView

/// UIImageView subclass with a tap closure.
private final class InlineTappableImageView: UIImageView {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?() }
}
