import Testing
@testable import OhMyDesign

struct TreeInsertionTests {
    private let rows = [
        TreeRow(id: "volume", level: 1, parent: nil, hasChildren: true),
        TreeRow(id: "chapter", level: 2, parent: "volume", hasChildren: false),
        TreeRow(id: "next", level: 1, parent: nil, hasChildren: false)
    ]

    @Test func rootInsertionFollowsAllVisibleRows() {
        let position = TreeInsertionPosition(parentID: nil, rows: rows, expanded: [])
        #expect(position?.afterID == "next")
        #expect(position?.level == 1)
    }

    @Test func childInsertionFollowsWholeSubtree() {
        let position = TreeInsertionPosition(parentID: "volume", rows: rows, expanded: ["volume"])
        #expect(position?.afterID == "chapter")
        #expect(position?.level == 2)
    }

    @Test func nestedDescendantsStayBeforeInsertion() {
        let nested = [
            TreeRow(id: "parent", level: 1, parent: nil, hasChildren: true),
            TreeRow(id: "child", level: 2, parent: "parent", hasChildren: true),
            TreeRow(id: "grandchild", level: 3, parent: "child", hasChildren: false),
            TreeRow(id: "sibling", level: 1, parent: nil, hasChildren: false)
        ]
        let position = TreeInsertionPosition(parentID: "parent", rows: nested, expanded: ["parent", "child"])
        #expect(position?.afterID == "grandchild")
        #expect(position?.level == 2)
    }

    @Test func hiddenOrMissingParentDoesNotBecomeRootInsertion() {
        #expect(TreeInsertionPosition(parentID: "volume", rows: rows, expanded: []) == nil)
        #expect(TreeInsertionPosition(parentID: "missing", rows: rows, expanded: ["missing"]) == nil)
    }

    @Test func emptyRootAndEmptyExpandedContainerAcceptInsertion() {
        let root = TreeInsertionPosition<String>(parentID: nil, rows: [], expanded: [])
        #expect(root?.level == 1)
        #expect(root?.afterID == nil)
        let empty = TreeInsertionPosition(parentID: "next", rows: rows, expanded: ["next"])
        #expect(empty?.afterID == "next")
        #expect(empty?.level == 2)
    }
}
