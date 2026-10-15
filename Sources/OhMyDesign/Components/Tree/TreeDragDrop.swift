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

    func end(_ token: UUID) {
        if self.token == token { self.cancel() }
    }

    func itemProvider(for token: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = token.uuidString
        provider.registerDataRepresentation(for: self.contentType, visibility: .ownProcess) { completion in
            completion(Data(), nil)
            return nil
        }
        return provider
    }

    func accepts(_ providers: [NSItemProvider]) -> Bool {
        guard let token = self.token, providers.count == 1 else { return false }
        return providers[0].suggestedName == token.uuidString
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
        if let configuration, self.isEnabled {
            HStack(spacing: 0) {
                content
                TreeDragHandle(id: self.id, configuration: configuration)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(Text("Move item", bundle: .module))
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { self.height = $0 }
            .overlay { TreeDropIndicator(target: configuration.session.target, id: self.id) }
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
        self.configuration.session.accepts(info.itemProviders(for: [self.configuration.session.contentType]))
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

#if canImport(UIKit)
    import UIKit

    struct TreeDragHandle<ID: Hashable>: UIViewRepresentable {
        let id: ID
        let configuration: TreeMoveConfiguration<ID>

        func makeCoordinator() -> Coordinator {
            Coordinator(id: self.id, configuration: self.configuration)
        }

        func makeUIView(context: Context) -> UIImageView {
            let view = UIImageView(image: UIImage(systemName: "line.3.horizontal", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17)))
            view.contentMode = .center
            view.tintColor = .secondaryLabel
            view.isUserInteractionEnabled = true
            let interaction = UIDragInteraction(delegate: context.coordinator)
            interaction.isEnabled = true
            view.addInteraction(interaction)
            return view
        }

        func updateUIView(_: UIImageView, context: Context) {
            context.coordinator.id = self.id
            context.coordinator.configuration = self.configuration
        }

        final class Coordinator: NSObject, UIDragInteractionDelegate {
            var id: ID
            var configuration: TreeMoveConfiguration<ID>
            private var tokens: [ObjectIdentifier: UUID] = [:]

            init(id: ID, configuration: TreeMoveConfiguration<ID>) {
                self.id = id
                self.configuration = configuration
            }

            func dragInteraction(_: UIDragInteraction, itemsForBeginning session: any UIDragSession) -> [UIDragItem] {
                let token = self.configuration.session.begin(self.id, in: self.configuration.structure)
                self.tokens[ObjectIdentifier(session)] = token
                return [UIDragItem(itemProvider: self.configuration.session.itemProvider(for: token))]
            }

            func dragInteraction(_: UIDragInteraction, session: any UIDragSession, didEndWith _: UIDropOperation) {
                if let token = self.tokens.removeValue(forKey: ObjectIdentifier(session)) {
                    self.configuration.session.end(token)
                }
            }

            func dragInteraction(_: UIDragInteraction, sessionIsRestrictedToDraggingApplication _: any UIDragSession) -> Bool {
                true
            }
        }
    }
#else
    struct TreeDragHandle<ID: Hashable>: View {
        let id: ID
        let configuration: TreeMoveConfiguration<ID>
        @State private var token: UUID?

        var body: some View {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(Color.contentSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .onDrag {
                    let token = self.configuration.session.begin(self.id, in: self.configuration.structure)
                    self.token = token
                    return self.configuration.session.itemProvider(for: token)
                }
                .onDragSessionUpdated { session in
                    if case .ended = session.phase, let token = self.token {
                        self.configuration.session.end(token)
                        self.token = nil
                    }
                }
        }
    }
#endif
