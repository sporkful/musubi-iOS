// CollectionDiffingWithMovesTests.swift

import XCTest
@testable import Musubi

final class CollectionDiffingWithMovesTests: XCTestCase {
    
    actor SimulatedRemote<RepeatableItem: Hashable> {
        typealias Element = RepeatableItem
        
        private var list: [Element]
        
        init(list: [Element]) {
            self.list = list
        }
        
        func insert(_ newElement: Element, at i: Int) async {
            self.list.insert(newElement, at: i)
        }
        
        func remove(at index: Int) async -> Element {
            return self.list.remove(at: index)
        }
        
        func move(removalOffset: Int, insertionOffset: Int) async {
            let elementToMove = self.list.remove(at: removalOffset)
            self.list.insert(elementToMove, at: insertionOffset)
        }
        
        func listCopy() async -> [Element] {
            return self.list
        }
    }
    
    func testWithSimulatedRemote<RepeatableItem: Hashable>(oldList: [RepeatableItem], newList: [RepeatableItem]) async throws {
        let simulatedRemote = SimulatedRemote(list: oldList)
        
        let oldDiffableList = Musubi.DiffableList(rawList: oldList)
        let newDiffableList = Musubi.DiffableList(rawList: newList)

        try await Musubi.DetailedListDifference(oldList: oldDiffableList, newList: newDiffableList)
            .applyWithSideEffects(
                insertionSideEffect: { element, offset in
                    await simulatedRemote.insert(element.item, at: offset)
                },
                removalSideEffect: { offset in
                    let _ = await simulatedRemote.remove(at: offset)
                },
                moveSideEffect: { removalOffset, insertionOffset in
                    await simulatedRemote.move(removalOffset: removalOffset, insertionOffset: insertionOffset)
                }
            )
        
        let simulatedRemoteState = await simulatedRemote.listCopy()
        XCTAssertEqual(simulatedRemoteState, newList, "")
    }

    func testSimpleForwardMove() async throws {
        try await testWithSimulatedRemote(
            oldList: ["a", "b", "c", "d", "e", "f"],
            newList: ["a", "x", "d", "b", "c", "e", "f", "z"]
        )
    }
    
    func testSimpleBackwardMove() async throws {
        try await testWithSimulatedRemote(
            oldList: ["a", "b", "c", "d", "e", "f"],
            newList: ["a", "c", "g", "d", "e", "b", "f", "z"]
        )
    }

}
