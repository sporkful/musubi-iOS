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
        
        func move(removalOffset: Int, insertionOffset: Int) async -> Element {
            let elementToMove = self.list.remove(at: removalOffset)
            self.list.insert(elementToMove, at: insertionOffset)
            return elementToMove
        }
        
        func listCopy() async -> [Element] {
            return self.list
        }
    }
    
    func testWithSimulatedRemote<RepeatableItem: Hashable>(
        oldList: [RepeatableItem],
        newList: [RepeatableItem],
        logging: Bool
    ) async throws {
        var log: [String] = []
        
        if logging {
            log.append("Old list of repeatable items: \(oldList)")
            log.append("New list of repeatable items: \(newList)")
        }
        
        let simulatedRemote = SimulatedRemote(list: oldList)
        
        let oldDiffableList = Musubi.DiffableList(rawList: oldList)
        let newDiffableList = Musubi.DiffableList(rawList: newList)
        
        if logging {
            log.append("Old list uniquified: \(oldDiffableList.uniquifiedList)")
            log.append("New list uniquified: \(newDiffableList.uniquifiedList)")
            log.append("=== START OPERATIONS ===")
            log.append("\t Remote state: \(await simulatedRemote.listCopy())")
        }

        try await Musubi.DetailedListDifference(oldList: oldDiffableList, newList: newDiffableList)
            .applyWithSideEffects(
                insertionSideEffect: { element, offset in
                    await simulatedRemote.insert(element.item, at: offset)
                    if logging {
                        log.append("Inserted new element \(element) at offset \(offset)")
                        log.append("\t Remote state: \(await simulatedRemote.listCopy())")
                    }
                },
                removalSideEffect: { offset in
                    let removedElement = await simulatedRemote.remove(at: offset)
                    if logging {
                        log.append("Removed item \"\(removedElement)\" at offset \(offset)")
                        log.append("\t Remote state: \(await simulatedRemote.listCopy())")
                    }
                },
                moveSideEffect: { removalOffset, insertionOffset in
                    let movedElement = await simulatedRemote.move(removalOffset: removalOffset, insertionOffset: insertionOffset)
                    if logging {
                        log.append("Moved item \"\(movedElement)\" from offset \(removalOffset) to \(insertionOffset)")
                        log.append("\t Remote state: \(await simulatedRemote.listCopy())")
                    }
                }
            )
        
        if logging {
            log.append("=== END OPERATIONS ===")
        }
        
        let finalRemoteList = await simulatedRemote.listCopy()
        XCTAssertEqual(finalRemoteList, newList, "")
        
        if logging {
            print(log.map({ "\t\($0)" }).joined(separator: "\n"))
        }
    }

    func testSimpleForwardMove() async throws {
        try await testWithSimulatedRemote(
            oldList: ["a", "b", "c", "d", "e", "f"],
            newList: ["a", "x", "d", "b", "c", "e", "f", "z"],
            logging: true
        )
    }
    
    func testSimpleBackwardMove() async throws {
        try await testWithSimulatedRemote(
            oldList: ["a", "b", "c", "d", "e", "f"],
            newList: ["a", "c", "g", "d", "e", "b", "f", "z"],
            logging: true
        )
    }

}
