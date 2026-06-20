import SwiftUI
import QVACRuntime

struct TrustedGraphView: View {
    var refreshTick: Int = 0
    var onOpenNote: (Note) -> Void

    @StateObject private var vm = GraphViewModel()
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var pan: CGSize = .zero
    @State private var zoom: CGFloat = 1
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var zoomDelta: CGFloat = 1

    private let minZoom: CGFloat = 0.6
    private let maxZoom: CGFloat = 2.4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            graphSurface
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { vm.refresh() }
        .task(id: refreshTick) {
            vm.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trusted Graph")
                    .font(.custom("HelveticaNeue-Bold", size: 34))
                    .foregroundStyle(Color.primary)
                Text("\(vm.graph.nodes.count) notes, \(vm.graph.edges.count) links")
                    .font(.custom("HelveticaNeue", size: 13))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button {
                vm.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh Trusted Graph")
        }
    }

    private var graphSurface: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.clear

                if vm.graph.nodes.isEmpty {
                    emptyState
                } else {
                    graphCanvas(in: proxy.size)
                }

                selectedPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 88)
            }
            .contentShape(Rectangle())
            .clipped()
            .onAppear {
                cacheLayout(in: proxy.size)
            }
            .onChange(of: vm.graph) { _, _ in
                cacheLayout(in: proxy.size)
            }
            .simultaneousGesture(panGesture)
            .simultaneousGesture(zoomGesture)
        }
    }

    private func graphCanvas(in size: CGSize) -> some View {
        let activeZoom = clamped(zoom * zoomDelta, minZoom, maxZoom)
        let activePan = CGSize(
            width: pan.width + dragDelta.width,
            height: pan.height + dragDelta.height
        )

        return ZStack {
            ForEach(Array(vm.graph.edges.enumerated()), id: \.offset) { _, edge in
                edgeView(edge)
            }

            ForEach(vm.graph.nodes) { node in
                nodeView(node)
                    .position(nodePositions[node.id] ?? center(of: size))
            }
        }
        .scaleEffect(activeZoom)
        .offset(activePan)
        .frame(width: size.width, height: size.height)
    }

    private func edgeView(_ edge: PresentationTrustedGraphEdge) -> some View {
        Path { path in
            guard
                let source = nodePositions[edge.sourceID],
                let target = nodePositions[edge.targetID]
            else { return }
            path.move(to: source)
            path.addLine(to: target)
        }
        .stroke(edgeColor(edge.provenance), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func nodeView(_ node: PresentationTrustedGraphNode) -> some View {
        let isSelected = vm.selectedNodeID == node.id
        let isPlaceholder = node.kind == .placeholderNote

        return Button {
            vm.select(node)
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: isPlaceholder ? "doc.badge.plus" : "note.text")
                        .font(.system(size: 14, weight: .semibold))
                    Text(node.title)
                        .font(.custom("HelveticaNeue-Medium", size: 13))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isPlaceholder {
                    Text("Placeholder")
                        .font(.custom("HelveticaNeue-Medium", size: 10))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isPlaceholder ? Color.orange : Color.blueBold)
            .frame(width: 128)
            .frame(minHeight: isPlaceholder ? 74 : 58)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(nodeBackground(isPlaceholder: isPlaceholder))
            .overlay(nodeBorder(isSelected: isSelected, isPlaceholder: isPlaceholder))
            .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 12 : 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaceholder ? "Placeholder Note \(node.title)" : "Note \(node.title)")
    }

    @ViewBuilder
    private var selectedPanel: some View {
        if let node = vm.selectedNode {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.title)
                        .font(.custom("HelveticaNeue-Bold", size: 16))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(node.kind == .placeholderNote ? "Placeholder Note" : "Note")
                        .font(.custom("HelveticaNeue", size: 12))
                        .foregroundStyle(node.kind == .placeholderNote ? Color.orange : Color.secondary)
                }

                Spacer()

                Button {
                    if let note = vm.openSelectedNote() {
                        onOpenNote(note)
                    }
                } label: {
                    Label("Open", systemImage: "arrow.up.forward")
                        .font(.custom("HelveticaNeue-Medium", size: 14))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.bluePrimary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blueBorder, lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.secondary)
            Text("No Trusted Graph links yet")
                .font(.custom("HelveticaNeue-Bold", size: 18))
                .foregroundStyle(Color.primary)
            Text("Create wikilinks between notes to build the graph.")
                .font(.custom("HelveticaNeue", size: 14))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                pan.width += value.translation.width
                pan.height += value.translation.height
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($zoomDelta) { value, state, _ in
                state = value
            }
            .onEnded { value in
                zoom = clamped(zoom * value, minZoom, maxZoom)
            }
    }

    private func cacheLayout(in size: CGSize) {
        let nodes = vm.graph.nodes
        let currentNodeIDs = Set(nodes.map(\.id))
        nodePositions = nodePositions.filter { currentNodeIDs.contains($0.key) }

        let missingNodes = nodes.filter { nodePositions[$0.id] == nil }
        guard !missingNodes.isEmpty else { return }

        let radius = max(96, min(size.width, size.height) * 0.32)
        let center = center(of: size)
        let sortedNodes = nodes.sorted { lhs, rhs in
            lhs.id.uuidString < rhs.id.uuidString
        }
        let total = max(sortedNodes.count, 1)

        for (index, node) in sortedNodes.enumerated() where nodePositions[node.id] == nil {
            let angle = (Double(index) / Double(total)) * Double.pi * 2 - Double.pi / 2
            nodePositions[node.id] = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }
    }

    private func center(of size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func nodeBackground(isPlaceholder: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.cardBackground)
            .overlay {
                if isPlaceholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.11))
                }
            }
    }

    private func nodeBorder(isSelected: Bool, isPlaceholder: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                isSelected ? Color.bluePrimary : (isPlaceholder ? Color.orange.opacity(0.8) : Color.blueBorder),
                style: StrokeStyle(lineWidth: isSelected ? 2 : 1.4, dash: isPlaceholder ? [6, 4] : [])
            )
    }

    private func edgeColor(_ provenance: TrustedGraphEdgeProvenance) -> Color {
        switch provenance {
        case .explicitLink:
            Color.blueBorder.opacity(0.9)
        case .acceptedRelationship:
            Color.orange.opacity(0.75)
        }
    }

    private func clamped(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

#Preview {
    TrustedGraphView(onOpenNote: { _ in })
}
