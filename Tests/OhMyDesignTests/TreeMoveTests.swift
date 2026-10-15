@testable import OhMyDesign
import SwiftUI
import Testing

@MainActor
struct TreeMoveTests {
    private var structure: TreeStructure<String> {
        TreeStructure([
            TreeJudgeNode(id: "a", children: [
                TreeJudgeNode(id: "x", children: nil),
                TreeJudgeNode(id: "y", children: nil),
            ]),
            TreeJudgeNode(id: "empty", children: []),
            TreeJudgeNode(id: "b", children: nil),
        ], id: \.id, children: \.children)
    }

    @Test func `resolves sibling and cross parent positions`() {
        #expect(self.structure.move("y", to: .before("x")) == TreeMove(id: "y", parentID: "a", beforeID: "x"))
        #expect(self.structure.move("b", to: .inside("empty")) == TreeMove(id: "b", parentID: "empty", beforeID: nil))
        #expect(self.structure.move("x", to: .after("a")) == TreeMove(id: "x", parentID: nil, beforeID: "empty"))
        #expect(self.structure.move("x", to: .rootEnd) == TreeMove(id: "x", parentID: nil, beforeID: nil))
    }

    @Test func `rejects cycles missing I ds and no changes`() {
        #expect(self.structure.move("a", to: .inside("a")) == nil)
        #expect(self.structure.move("a", to: .before("x")) == nil)
        #expect(self.structure.move("a", to: .inside("x")) == nil)
        #expect(self.structure.move("missing", to: .rootEnd) == nil)
        #expect(self.structure.move("b", to: .before("missing")) == nil)
        #expect(self.structure.move("x", to: .before("y")) == nil)
        #expect(self.structure.move("y", to: .after("x")) == nil)
        #expect(self.structure.move("b", to: .rootEnd) == nil)
    }

    @Test func `session rejects changed structure policy and cancellation`() {
        let session = TreeDragSession<String>()
        var calls = 0
        session.begin("b", in: self.structure)
        let changed = TreeStructure([TreeJudgeNode(id: "b", children: nil)], id: \.id, children: \.children)
        #expect(!session.finish(at: .inside("empty"), in: changed, canMove: { _ in true }, perform: { _ in calls += 1 }))
        session.begin("b", in: self.structure)
        #expect(!session.finish(at: .inside("empty"), in: self.structure, canMove: { _ in false }, perform: { _ in calls += 1 }))
        session.begin("b", in: self.structure)
        session.cancel()
        #expect(!session.finish(at: .inside("empty"), in: self.structure, canMove: { _ in true }, perform: { _ in calls += 1 }))
        #expect(calls == 0)
        session.begin("b", in: self.structure)
        #expect(session.finish(at: .inside("empty"), in: self.structure, canMove: { _ in true }, perform: { _ in calls += 1 }))
        #expect(!session.finish(at: .inside("empty"), in: self.structure, canMove: { _ in true }, perform: { _ in calls += 1 }))
        #expect(calls == 1)
    }

    @Test func `targets use container quarters and leaf halves`() {
        #expect(TreeDropTarget.row("a", fraction: 0.1, acceptsChildren: true) == .before("a"))
        #expect(TreeDropTarget.row("a", fraction: 0.5, acceptsChildren: true) == .inside("a"))
        #expect(TreeDropTarget.row("a", fraction: 0.9, acceptsChildren: true) == .after("a"))
        #expect(TreeDropTarget.row("b", fraction: 0.4, acceptsChildren: false) == .before("b"))
        #expect(TreeDropTarget.row("b", fraction: 0.6, acceptsChildren: false) == .after("b"))
    }
    @Test func oldProviderReleaseCannotCancelANewerDrag() {
        let session = TreeDragSession<String>()
        let first = session.begin("x", in: self.structure)
        let second = session.begin("b", in: self.structure)
        session.release(first)
        #expect(session.proposal(at: .inside("empty"), in: self.structure, canMove: { _ in true })?.id == "b")
        session.release(second)
        #expect(session.proposal(at: .inside("empty"), in: self.structure, canMove: { _ in true }) == nil)
    }
}
