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
    #if canImport(UIKit)
        @State private var preview = TreeDragPreview()
    #endif
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if let configuration, self.isEnabled {
            HStack(spacing: 0) {
                content
                #if canImport(UIKit)
                    TreeDragHandle(id: self.id, configuration: configuration, preview: self.preview)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(Text("Move item", bundle: .module))
                #else
                    TreeDragHandle(id: self.id, configuration: configuration)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(Text("Move item", bundle: .module))
                #endif
            }
            #if canImport(UIKit)
            .background { TreeDragPreviewAnchor(preview: self.preview).allowsHitTesting(false) }
            #endif
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

    /// 只记录当前行的范围，不查找 SwiftUI 的私有视图层级。
    final class TreeDragPreview {
        weak var anchor: UIView?

        func makePreview() -> UITargetedDragPreview? {
            guard let anchor, let window = anchor.window else { return nil }
            let rect = anchor.convert(anchor.bounds, to: window)
            guard rect.width > 0, rect.height > 0 else { return nil }
            // 固定为当前行的位图，避免窗口快照在拖动层里复用底层渲染内容。
            var rendered = false
            let image = UIGraphicsImageRenderer(size: rect.size).image { context in
                context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
                rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            }
            guard rendered else { return nil }
            let snapshot = UIImageView(image: image)
            snapshot.isAccessibilityElement = false
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = UIColor(Color.surfaceRaised)
            parameters.visiblePath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: rect.size), cornerRadius: CoreRadius.small)
            return UITargetedDragPreview(
                view: snapshot, parameters: parameters,
                target: UIDragPreviewTarget(container: window, center: CGPoint(x: rect.midX, y: rect.midY)),
            )
        }
    }

    struct TreeDragPreviewAnchor: UIViewRepresentable {
        let preview: TreeDragPreview

        func makeUIView(context _: Context) -> UIView {
            let view = UIView()
            view.isUserInteractionEnabled = false
            self.preview.anchor = view
            return view
        }

        func updateUIView(_ view: UIView, context _: Context) {
            self.preview.anchor = view
        }
    }

    struct TreeDragHandle<ID: Hashable>: UIViewRepresentable {
        let id: ID
        let configuration: TreeMoveConfiguration<ID>
        let preview: TreeDragPreview

        func makeCoordinator() -> Coordinator {
            Coordinator(id: self.id, configuration: self.configuration, preview: self.preview)
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
            context.coordinator.preview = self.preview
        }

        final class Coordinator: NSObject, UIDragInteractionDelegate {
            var id: ID
            var configuration: TreeMoveConfiguration<ID>
            var preview: TreeDragPreview
            private var tokens: [ObjectIdentifier: UUID] = [:]
            private var liftedPreview: UITargetedDragPreview?
            private let liftFeedback = UIImpactFeedbackGenerator(style: .light)

            init(id: ID, configuration: TreeMoveConfiguration<ID>, preview: TreeDragPreview) {
                self.id = id
                self.configuration = configuration
                self.preview = preview
            }

            func dragInteraction(_: UIDragInteraction, itemsForBeginning session: any UIDragSession) -> [UIDragItem] {
                let token = self.configuration.session.begin(self.id, in: self.configuration.structure)
                self.tokens[ObjectIdentifier(session)] = token
                self.liftedPreview = self.preview.makePreview()
                self.liftFeedback.prepare()
                let item = UIDragItem(itemProvider: self.configuration.session.itemProvider(for: token))
                item.previewProvider = { [preview = self.liftedPreview] in
                    guard let preview else { return nil }
                    let parameters = UIDragPreviewParameters()
                    parameters.backgroundColor = preview.parameters.backgroundColor
                    parameters.visiblePath = preview.parameters.visiblePath
                    return UIDragPreview(view: preview.view, parameters: parameters)
                }
                return [item]
            }

            func dragInteraction(_: UIDragInteraction, previewForLifting _: UIDragItem, session _: any UIDragSession) -> UITargetedDragPreview? {
                self.liftedPreview
            }

            func dragInteraction(_: UIDragInteraction, previewForCancelling _: UIDragItem, withDefault defaultPreview: UITargetedDragPreview) -> UITargetedDragPreview? {
                self.preview.makePreview() ?? defaultPreview
            }

            func dragInteraction(_: UIDragInteraction, prefersFullSizePreviewsFor _: any UIDragSession) -> Bool {
                true
            }

            func dragInteraction(_: UIDragInteraction, sessionWillBegin _: any UIDragSession) {
                self.liftFeedback.impactOccurred()
            }

            func dragInteraction(_: UIDragInteraction, session: any UIDragSession, didEndWith _: UIDropOperation) {
                if let token = self.tokens.removeValue(forKey: ObjectIdentifier(session)) {
                    self.configuration.session.end(token)
                }
                self.liftedPreview = nil
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
