import Observation
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class TreeDragSession<ID: Hashable> {
    let contentType = UTType(exportedAs: "com.ohmydesign.tree." + UUID().uuidString.lowercased(), conformingTo: .data)
    private var token: UUID?
    private var source: ID?
    private var original: TreeStructure<ID>?
    var target: TreeDropTarget<ID>?

    @discardableResult
    func begin(_ id: ID, in structure: TreeStructure<ID>) -> UUID {
        let token = UUID()
        self.token = token
        self.source = id
        self.original = structure
        self.target = nil
        return token
    }

    func release(_ token: UUID) {
        if self.token == token { self.cancel() }
    }

    func proposal(at target: TreeDropTarget<ID>, in structure: TreeStructure<ID>, canMove: (TreeMove<ID>) -> Bool) -> TreeMove<ID>? {
        guard self.original == structure, let source,
              let move = structure.move(source, to: target), canMove(move) else { return nil }
        return move
    }

    func finish(at target: TreeDropTarget<ID>, in structure: TreeStructure<ID>, canMove: (TreeMove<ID>) -> Bool, perform: (TreeMove<ID>) -> Void) -> Bool {
        let move = self.proposal(at: target, in: structure, canMove: canMove)
        self.cancel()
        guard let move else { return false }
        perform(move)
        return true
    }

    func cancel() {
        self.token = nil
        self.source = nil
        self.original = nil
        self.target = nil
    }
}

struct TreeMoveConfiguration<ID: Hashable> {
    let structure: TreeStructure<ID>
    let session: TreeDragSession<ID>
    let canMove: (TreeMove<ID>) -> Bool
    let perform: (TreeMove<ID>) -> Void
}

struct TreeDragRow<ID: Hashable>: ViewModifier {
    let id: ID
    let acceptsChildren: Bool
    let configuration: TreeMoveConfiguration<ID>?
    @State private var height: CGFloat = 44
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if let configuration, isEnabled {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { self.height = $0 }
                .overlay { TreeDropIndicator(target: configuration.session.target, id: self.id) }
                .onDrag {
                    let token = configuration.session.begin(self.id, in: configuration.structure)
                    let session = configuration.session
                    let lifetime = TreeDragLifetime {
                        Task { @MainActor in session.release(token) }
                    }
                    let provider = NSItemProvider()
                    provider.registerDataRepresentation(for: configuration.session.contentType, visibility: .ownProcess) { completion in
                        withExtendedLifetime(lifetime) { completion(Data(), nil) }
                        return nil
                    }
                    return provider
                }
                .onDrop(of: [configuration.session.contentType], delegate: TreeDropDelegate(
                    configuration: configuration,
                    target: { point in
                        .row(self.id, fraction: point.y / max(self.height, 1), acceptsChildren: self.acceptsChildren)
                    },
                ))
        } else {
            content
        }
    }
}

struct TreeDropDelegate<ID: Hashable>: DropDelegate {
    let configuration: TreeMoveConfiguration<ID>
    let target: (CGPoint) -> TreeDropTarget<ID>

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [self.configuration.session.contentType])
    }

    func dropEntered(info: DropInfo) {
        self.update(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        self.update(info)
        return DropProposal(operation: self.configuration.session.target == nil ? .forbidden : .move)
    }

    func dropExited(info _: DropInfo) {
        self.configuration.session.target = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard self.validateDrop(info: info) else { return false }
        return self.configuration.session.finish(
            at: self.target(info.location), in: self.configuration.structure,
            canMove: self.configuration.canMove, perform: self.configuration.perform,
        )
    }

    private func update(_ info: DropInfo) {
        let target = target(info.location)
        self.configuration.session.target = self.configuration.session.proposal(
            at: target, in: self.configuration.structure, canMove: self.configuration.canMove,
        ) == nil ? nil : target
    }
}

struct TreeDropIndicator<ID: Hashable>: View {
    let target: TreeDropTarget<ID>?
    let id: ID
    @Environment(\.coreAccent) private var accent

    var body: some View {
        Group {
            switch self.target {
            case let .before(id) where id == self.id:
                self.line.frame(maxHeight: .infinity, alignment: .top)
            case let .after(id) where id == self.id:
                self.line.frame(maxHeight: .infinity, alignment: .bottom)
            case let .inside(id) where id == self.id:
                RoundedRectangle(cornerRadius: CoreRadius.small)
                    .strokeBorder(self.accent, lineWidth: CoreBorderWidth.thin)
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }

    private var line: some View {
        Rectangle().fill(self.accent).frame(height: CoreBorderWidth.thin)
    }
}

struct TreeRootDropZone<ID: Hashable>: View {
    let configuration: TreeMoveConfiguration<ID>
    @Environment(\.coreAccent) private var accent
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Color.clear
            .frame(height: 44)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if self.configuration.session.target == .rootEnd {
                    Rectangle().fill(self.accent).frame(height: CoreBorderWidth.thin)
                }
            }
            .onDrop(of: [self.configuration.session.contentType], delegate: TreeDropDelegate(
                configuration: self.configuration, target: { _ in .rootEnd },
            ))
            .allowsHitTesting(self.isEnabled)
            .accessibilityHidden(true)
    }
}

final nonisolated class TreeDragLifetime: Sendable {
    private let ended: @Sendable () -> Void

    init(ended: @escaping @Sendable () -> Void) {
        self.ended = ended
    }

    deinit { self.ended() }
}
