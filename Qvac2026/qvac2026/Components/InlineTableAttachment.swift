//
//  InlineTableAttachment.swift
//  qvac2026
//
//  Created by Revan Ferdinand on 18/06/26.
//

import UIKit

// MARK: - TableAttachmentHosting

/// Callbacks from an inline table attachment back to the owning view model.
protocol TableAttachmentHosting: AnyObject {
    /// Called when a cell's text changes — persist the note.
    func tableContentDidChange()
    /// Kept for protocol compatibility; structural edits now go through the VM directly.
    func tableLayoutDidChange()
    /// Called when a cell text field becomes first responder.
    func tableCellDidBeginEditing(_ att: TableTextAttachment, row: Int, col: Int)
    /// Called when a cell text field resigns first responder.
    func tableCellDidEndEditing(_ att: TableTextAttachment)
    /// Returns the shared UIView to use as `inputAccessoryView` for every cell field.
    func tableCellAccessoryView() -> UIView
}

// MARK: - TableTextAttachment

/// An `NSTextAttachment` subclass representing an inline editable table.
///
/// Cell data (`cells: [[String]]`) is encoded with `NSKeyedArchiver` so tables
/// round-trip through the same archive path used for audio / image / file attachments.
/// `host` and `currentProvider` are intentionally NOT encoded (runtime-only references).
@objc(TableTextAttachment)
final class TableTextAttachment: NSTextAttachment {

    /// The cell data model — rows of columns.
    var cells: [[String]] = [["", ""], ["", ""]]
    weak var host: TableAttachmentHosting?
    /// The live view provider. Set in `loadView()`, nil'd automatically when the provider
    /// is deallocated. Used by the VM to call `rebuild(focusing:)` in place.
    weak var currentProvider: TableAttachmentViewProvider?

    override class var supportsSecureCoding: Bool { true }

    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
    }

    convenience init(cells: [[String]] = [["", ""], ["", ""]]) {
        self.init(data: nil, ofType: nil)
        self.cells = cells
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let data = coder.decodeObject(of: NSData.self, forKey: "cells") as? Data,
           let decoded = try? JSONDecoder().decode([[String]].self, from: data) {
            cells = decoded
        }
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        if let data = try? JSONEncoder().encode(cells) {
            coder.encode(data as NSData, forKey: "cells")
        }
    }

    // MARK: NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        let copy = TableTextAttachment(cells: self.cells)
        copy.host = self.host
        copy.bounds = self.bounds
        return copy
    }

    // MARK: NSTextAttachmentViewProvider (TextKit 2)

    override func viewProvider(
        for parentView: UIView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        let provider = TableAttachmentViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }
}

// MARK: - TableCellTextField

/// A UITextField that carries its grid position, fires closures on text change and
/// focus events, and acts as its own UITextFieldDelegate.
private final class TableCellTextField: UITextField, UITextFieldDelegate {
    var cellRow = 0
    var cellCol = 0
    var onChange:    ((Int, Int, String) -> Void)?
    var onBeginEdit: (() -> Void)?
    var onEndEdit:   (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        addTarget(self, action: #selector(handleChange), for: .editingChanged)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func handleChange() {
        onChange?(cellRow, cellCol, text ?? "")
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        onBeginEdit?()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        onEndEdit?()
    }
}

// MARK: - TableCellView

/// A simple bordered cell container.
private final class TableCellView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - TableAttachmentViewProvider

/// TextKit 2 view provider that builds and manages the editable grid for each
/// `TableTextAttachment`. Structural edits (add/remove row or column) go through
/// `rebuild(focusing:)`, which updates the view hierarchy in-place without reassigning
/// the entire document's attributed text.
final class TableAttachmentViewProvider: NSTextAttachmentViewProvider {

    private let rowHeight:       CGFloat = 36
    private let topPadding:      CGFloat = 12
    private let minColWidth:     CGFloat = 100
    private let horizontalInset: CGFloat = 8

    /// Indexed cell text fields — used for focus restoration after rebuild.
    private var cellFields: [[TableCellTextField]] = []

    // MARK: Initial load

    override func loadView() {
        guard let att = textAttachment as? TableTextAttachment else {
            view = UIView(); return
        }

        let container = AttachmentContainerView()
        container.backgroundColor = .clear

        // Register this provider so the VM can call rebuild() without touching
        // the whole attributed text.
        att.currentProvider = self

        buildGrid(in: container, att: att)
        view = container
    }

    // MARK: In-place rebuild

    /// Tears down and rebuilds the grid inside the existing container view without
    /// reassigning `tv.attributedText`. After rebuilding:
    /// - Updates `container.bounds` so TextKit 2 (via `tracksTextAttachmentViewBounds`)
    ///   picks up the new height.
    /// - Invalidates TextKit 2 layout for just this attachment's range.
    /// - Asynchronously makes `target` cell first responder so the keyboard stays up.
    func rebuild(focusing target: (row: Int, col: Int)? = nil) {
        guard let att = textAttachment as? TableTextAttachment,
              let container = view else { return }

        let rows      = CGFloat(att.cells.count)
        let newHeight = topPadding + rows * rowHeight
        let newWidth  = container.bounds.width > 0
            ? container.bounds.width
            : max(textLayoutManager?.textContainer?.size.width ?? 300, 200)

        // Update bounds first — TextKit 2 observes this via KVO and adjusts layout.
        container.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)

        buildGrid(in: container, att: att)

        // Nudge TextKit 2 to invalidate layout for this specific attachment range.
        if let tlm = textLayoutManager,
           let endLoc = tlm.location(self.location, offsetBy: 1),
           let range  = NSTextRange(location: self.location, end: endLoc) {
            tlm.invalidateLayout(for: range)
        }

        // Restore first responder after AutoLayout settles.
        if let target {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      target.row < self.cellFields.count,
                      target.col < self.cellFields[target.row].count else { return }
                self.cellFields[target.row][target.col].becomeFirstResponder()
            }
        }
    }

    // MARK: Grid builder

    private func buildGrid(in container: UIView, att: TableTextAttachment) {
        container.subviews.forEach { $0.removeFromSuperview() }
        cellFields = []

        let availableWidth = container.bounds.width > 0
            ? container.bounds.width - 2 * horizontalInset
            : max((textLayoutManager?.textContainer?.size.width ?? 300) - 2 * horizontalInset, 180)

        let colCount  = CGFloat(att.cells.first?.count ?? 1)
        let colWidth  = max(availableWidth / colCount, minColWidth)
        let gridWidth = colWidth * colCount

        // Horizontal scrolling when too many columns to fit.
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.bounces = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Vertical stack of row stacks.
        let gridStack = UIStackView()
        gridStack.axis      = .vertical
        gridStack.spacing   = 0
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        var rowFields: [[TableCellTextField]] = []
        for (r, row) in att.cells.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis         = .horizontal
            rowStack.spacing      = 0
            rowStack.distribution = .fill
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            rowStack.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

            var colFields: [TableCellTextField] = []
            for (c, cellText) in row.enumerated() {
                let (cellView, field) = makeCell(
                    row: r, col: c, text: cellText, att: att, colWidth: colWidth
                )
                rowStack.addArrangedSubview(cellView)
                colFields.append(field)
            }
            rowFields.append(colFields)
            gridStack.addArrangedSubview(rowStack)
        }
        cellFields = rowFields

        scrollView.addSubview(gridStack)

        // Anchor gridStack to the scroll view's content layout guide.
        NSLayoutConstraint.activate([
            gridStack.leadingAnchor.constraint(equalTo:  scrollView.contentLayoutGuide.leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            gridStack.topAnchor.constraint(equalTo:      scrollView.contentLayoutGuide.topAnchor),
            gridStack.bottomAnchor.constraint(equalTo:   scrollView.contentLayoutGuide.bottomAnchor),
            // Explicit content size drives horizontal scrolling.
            gridStack.widthAnchor.constraint(equalToConstant: gridWidth),
        ])

        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo:  container.leadingAnchor,   constant:  horizontalInset),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor,  constant: -horizontalInset),
            scrollView.topAnchor.constraint(equalTo:      container.topAnchor,       constant:  topPadding),
            scrollView.bottomAnchor.constraint(equalTo:   container.bottomAnchor),
        ])
    }

    // MARK: Cell factory

    private func makeCell(
        row r: Int, col c: Int, text: String,
        att: TableTextAttachment, colWidth: CGFloat
    ) -> (UIView, TableCellTextField) {
        let cell = TableCellView()
        cell.backgroundColor = .systemBackground
        cell.layer.borderWidth = 0.5
        cell.layer.borderColor = UIColor.separator.cgColor
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.widthAnchor.constraint(equalToConstant: colWidth).isActive = true

        let field = TableCellTextField()
        field.cellRow = r
        field.cellCol = c
        field.text    = text
        field.font    = UIFont(name: "HelveticaNeue", size: 13) ?? .systemFont(ofSize: 13)
        field.borderStyle = .none
        field.translatesAutoresizingMaskIntoConstraints = false

        // Text change → persist cell content.
        field.onChange = { [weak att] row, col, newText in
            guard let att,
                  row < att.cells.count,
                  col < att.cells[row].count else { return }
            att.cells[row][col] = newText
            att.host?.tableContentDidChange()
        }

        // Focus events → switch toolbar mode in the VM.
        field.onBeginEdit = { [weak att] in
            guard let att else { return }
            att.host?.tableCellDidBeginEditing(att, row: r, col: c)
        }
        field.onEndEdit = { [weak att] in
            guard let att else { return }
            att.host?.tableCellDidEndEditing(att)
        }

        // Table toolbar shown above the keyboard while editing this cell.
        field.inputAccessoryView = att.host?.tableCellAccessoryView()

        cell.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo:  cell.leadingAnchor,  constant:  6),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            field.centerYAnchor.constraint(equalTo:  cell.centerYAnchor),
        ])

        return (cell, field)
    }

    // MARK: Attachment bounds

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let att = textAttachment as? TableTextAttachment else { return .zero }
        let w      = textContainer?.size.width ?? proposedLineFragment.width
        let rows   = CGFloat(att.cells.count)
        let height = topPadding + rows * rowHeight
        return CGRect(x: 0, y: 0, width: max(w, 200), height: height)
    }
}
