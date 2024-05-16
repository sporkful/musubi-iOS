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
        
        let oldDiffableList = try Musubi.Diffing.DiffableList(rawList: oldList)
        let newDiffableList = try Musubi.Diffing.DiffableList(rawList: newList)
        
        if logging {
            log.append("Old list uniquified: \(oldDiffableList.uniquifiedList)")
            log.append("New list uniquified: \(newDiffableList.uniquifiedList)")
            log.append("=== START OPERATIONS ===")
            log.append("\t Remote state: \(await simulatedRemote.listCopy())")
        }
        
        for change in try newDiffableList.differenceWithLiveMoves(from: oldDiffableList) {
            switch change {
            case .insert(offset: let offset, element: let element, associatedWith: let associatedWith):
                if let associatedWith = associatedWith {
                    let movedElement = await simulatedRemote.move(
                        removalOffset: associatedWith,
                        insertionOffset: offset
                    )
                    
                    if logging {
                        log.append("Moved item \"\(movedElement)\" from offset \(associatedWith) to \(offset)")
                        log.append("\t Remote state: \(await simulatedRemote.listCopy())")
                    }
                    XCTAssertEqual(movedElement, element.item, "movedElement \(movedElement) != Change's \(element)")
                }
                else {
                    await simulatedRemote.insert(element.item, at: offset)
                    
                    if logging {
                        log.append("Inserted new element \(element) at offset \(offset)")
                        log.append("\t Remote state: \(await simulatedRemote.listCopy())")
                    }
                }
            case .remove(offset: let offset, element: let element, associatedWith: let associatedWith):
                let removedElement = await simulatedRemote.remove(at: offset)
                
                if logging {
                    log.append("Removed item \"\(removedElement)\" at offset \(offset)")
                    log.append("\t Remote state: \(await simulatedRemote.listCopy())")
                }
                XCTAssertEqual(associatedWith, nil, "remove unexpectedly associatedWith \(associatedWith ?? -1)")
                XCTAssertEqual(removedElement, element.item, "removedElement \(removedElement) != Change's \(element)")
            }
        }
        
        let finalRemoteList = await simulatedRemote.listCopy()
        
        if logging {
            log.append("=== END OPERATIONS ===")
            log.append("Final remote list: \(finalRemoteList)")
            log.append("Expected new list: \(newList)")
        }
        
        XCTAssertEqual(finalRemoteList, newList, "")
        
        log.append("VISUAL DIFFERENCE")
        let visualDifference = try newDiffableList.visualDifference(from: oldDiffableList)
        for visualChange in visualDifference {
            switch visualChange.change {
            case .none:
                log.append("  \(visualChange.element)")
            case .inserted(associatedWith: let associatedWith):
                if let associatedWith = associatedWith {
                    log.append("+ \(visualChange.element) (moved from \(associatedWith))")
                    XCTAssertEqual(visualChange.element, visualDifference[associatedWith].element, "mismatched visual move")
                } else {
                    log.append("+ \(visualChange.element)")
                }
            case .removed(associatedWith: let associatedWith):
                if let associatedWith = associatedWith {
                    log.append("- \(visualChange.element) (moved from \(associatedWith))")
                    XCTAssertEqual(visualChange.element, visualDifference[associatedWith].element, "mismatched visual move")
                } else {
                    log.append("- \(visualChange.element)")
                }
            }
        }
        
        let visualDifferenceResult = visualDifference.compactMap { visualChange in
            switch visualChange.change {
            case .none, .inserted:
                visualChange.element
            case .removed:
                nil
            }
        }
        XCTAssertEqual(visualDifferenceResult, newDiffableList.uniquifiedList, "unexpected visual diff result")
        
        if logging {
            log.append("*** END ITERATION ***\n")
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
    
    func testRandom1() async throws {
        try await testWithSimulatedRemote(
            oldList: ["A", "1", "5", "0", "C", "3", "B", "7", "B", "5", "3", "4", "8", "E", "A"],
            newList: ["D", "8", "0", "8", "3", "1", "8", "A", "8", "C", "F", "F", "E", "1", "6", "3"],
            logging: false
        )
    }
    
    func testRandom2() async throws {
        try await testWithSimulatedRemote(
            oldList: ["A", "J", "I", "G", "D", "G", "C", "B", "A", "C", "E", "D", "I", "E"],
            newList: ["A", "G", "D", "C", "G", "J", "B", "C", "D", "A", "E", "I", "E"],
            logging: false
        )
    }
    
    struct AlphabetizedRandomGenerator {
        enum Alphabet {
            case englishLetters
            case uInt16
            
            var maxValue: UInt16 {
                switch self {
                case .uInt16:
                    UInt16.max
                case .englishLetters:
                    25  // zero-indexed
                }
            }
        }
        
        let alphabet: Alphabet
        let numPossibleValues: UInt16
        
        init(alphabet: Alphabet, numPossibleValues: UInt16) throws {
            if (numPossibleValues - 1) > alphabet.maxValue {
                throw Error.misc(detail: "numPossibleValues out of alphabet's range")
            }
            
            self.alphabet = alphabet
            self.numPossibleValues = numPossibleValues
        }
        
        let A_AS_UINT16 = UInt16(("A" as UnicodeScalar).value)
        
        func randomValue() -> String {
            switch self.alphabet {
            case .englishLetters:
                String(Character(UnicodeScalar(UInt16.random(in: 0..<self.numPossibleValues) + A_AS_UINT16)!))
            case .uInt16:
                String(UInt16.random(in: 0..<self.numPossibleValues))
            }
        }
        
        func randomList(possibleLengths: Range<UInt>) -> [String] {
            let listLength = UInt.random(in: possibleLengths)
            switch self.alphabet {
            case .englishLetters:
                return (0..<listLength).map { _ in
                    String(Character(UnicodeScalar(UInt16.random(in: 0..<self.numPossibleValues) + A_AS_UINT16)!))
                }
            case .uInt16:
                return (0..<listLength).map { _ in
                    String(UInt16.random(in: 0..<self.numPossibleValues))
                }
            }
        }
        
        enum Error: LocalizedError {
            case misc(detail: String)

            var errorDescription: String? {
                let description = switch self {
                    case let .misc(detail): "\(detail)"
                }
                return "[Musubi::CollectionDiffingWithMoves] (TESTS) \(description)"
            }
        }
    }
    
    // TODO: allow specifying probability distribution of edits?
    func randomlyEdited(
        list: [String],
        possibleNumEdits: Range<UInt>,
        randomElementGenerator: AlphabetizedRandomGenerator
    ) throws -> [String] {
        var editedList = list
        for _ in 0..<UInt.random(in: possibleNumEdits) {
            switch UInt.random(in: 0..<3) {
            case 0:
                editedList.insert(
                    randomElementGenerator.randomValue(),
                    at: Int.random(in: 0...editedList.count)
                )
            case 1:
                if editedList.count == 0 {
                    continue
                }
                editedList.remove(at: Int.random(in: 0..<editedList.count))
            case 2:
                if editedList.count == 0 {
                    continue
                }
                let elementToMove = editedList.remove(at: Int.random(in: 0..<editedList.count))
                editedList.insert(elementToMove, at: Int.random(in: 0...editedList.count))
            default:
                continue
            }
        }
        return editedList
    }
    
    // TODO: parallelize?
    func fuzzNewFromScratch(
        numTests: UInt,
        randomGenerator: AlphabetizedRandomGenerator,
        possibleListLengths: Range<UInt>,
        logging: Bool
    ) async throws {
        for _ in 0..<numTests {
            try await testWithSimulatedRemote(
                oldList: randomGenerator.randomList(possibleLengths: possibleListLengths),
                newList: randomGenerator.randomList(possibleLengths: possibleListLengths),
                logging: logging
            )
        }
    }
    
    func fuzzEdits(
        numTests: UInt,
        randomGenerator: AlphabetizedRandomGenerator,
        possibleListLengths: Range<UInt>,
        possibleNumEdits: Range<UInt>,
        logging: Bool
    ) async throws {
        for _ in 0..<numTests {
            let oldList = randomGenerator.randomList(possibleLengths: possibleListLengths)
            let newList = try randomlyEdited(
                list: oldList,
                possibleNumEdits: possibleNumEdits,
                randomElementGenerator: randomGenerator
            )
            try await testWithSimulatedRemote(
                oldList: oldList,
                newList: newList,
                logging: logging
            )
        }
    }
    
    func testFuzzNewFromScratch0() async throws {
        try await fuzzNewFromScratch(
            numTests: 10,
            randomGenerator: AlphabetizedRandomGenerator(
                alphabet: .englishLetters,
                numPossibleValues: 26
            ),
            possibleListLengths: 10..<30,
            logging: true
        )
    }
    
    func testFuzzEdits0() async throws {
        try await fuzzEdits(
            numTests: 10,
            randomGenerator: AlphabetizedRandomGenerator(
                alphabet: .englishLetters,
                numPossibleValues: 26
            ),
            possibleListLengths: 10..<30,
            possibleNumEdits: 0..<30,
            logging: true
        )
    }
    
    func testFuzzNewFromScratch1() async throws {
        try await fuzzNewFromScratch(
            numTests: 100,
            randomGenerator: AlphabetizedRandomGenerator(
                alphabet: .uInt16,
                numPossibleValues: 200
            ),
            possibleListLengths: 0..<500,
            logging: false
        )
    }
    
    func testFuzzEdits1() async throws {
        try await fuzzEdits(
            numTests: 100,
            randomGenerator: AlphabetizedRandomGenerator(
                alphabet: .uInt16,
                numPossibleValues: 200
            ),
            possibleListLengths: 0..<500,
            possibleNumEdits: 0..<500,
            logging: false
        )
    }
    
    func testFuzzEditsPerf1() async throws {
        try await fuzzEdits(
            numTests: 100,
            randomGenerator: AlphabetizedRandomGenerator(
                alphabet: .uInt16,
                numPossibleValues: 1678
            ),
            possibleListLengths: 777..<888,
            possibleNumEdits: 61..<62,
            logging: false
        )
    }
    
    func testFuzzEditsPerf2() async throws {
        try await fuzzEdits(
            numTests: 100,
            randomGenerator: AlphabetizedRandomGenerator(
                alphabet: .uInt16,
                numPossibleValues: 1678
            ),
            possibleListLengths: 777..<888,
            possibleNumEdits: 170..<172,
            logging: false
        )
    }
}
