// CollectionDiffingWithMoves.swift

import Foundation

// TODO: improve memory/perf
// (this should be fine for now since we'll never have >2 of these and playlist sizes are relatively small)

extension Musubi {
    struct DiffableList<RepeatableItem: Hashable> {
        struct UniquifiedElement: Hashable, Equatable {
            let item: RepeatableItem
            let occurrence: Int  // per-item-value counter starting at 1
        }
        
        let uniquifiedList: [UniquifiedElement]
        let indexLookup: [UniquifiedElement: Int]
        
        init(rawList: [RepeatableItem]) {
            var counter: [RepeatableItem : Int] = [:]
            var uniquifiedList: [UniquifiedElement] = []
            for item in rawList {
                counter[item] = (counter[item] ?? 0) + 1
                uniquifiedList.append(UniquifiedElement(item: item, occurrence: counter[item]!))
            }
            self.uniquifiedList = uniquifiedList
            
            var indexLookup: [UniquifiedElement: Int] = [:]
            for (index, element) in zip(uniquifiedList.indices, uniquifiedList) {
                indexLookup[element] = index
            }
            self.indexLookup = indexLookup
            
            // TODO: remove
            assert(Set(self.uniquifiedList).count == self.uniquifiedList.count, "[Musubi::DiffableList] uniquify err")
        }
    }
    
    struct DetailedListDifference<RepeatableItem: Hashable> {
        typealias UniquifiedElement = DiffableList<RepeatableItem>.UniquifiedElement
        
        let oldList: DiffableList<RepeatableItem>
        let newList: DiffableList<RepeatableItem>
        
        let canonicalDifference: CollectionDifference<UniquifiedElement>
        
        init(oldList: DiffableList<RepeatableItem>, newList: DiffableList<RepeatableItem>) {
            self.oldList = oldList
            self.newList = newList
            self.canonicalDifference = newList.uniquifiedList
                .difference(from: oldList.uniquifiedList)
                .inferringMoves()
        }
        
        // TODO: rollback / atomicity
        /// - Parameter moveSideEffect: (removalOffset, insertionOffset) {
        ///         side effect for move equivalent to { remove at removalOffset then insert at insertionOffset }
        ///     }
        func applyWithSideEffects(
            insertionSideEffect: @escaping (UniquifiedElement, Int) async throws -> Void,
            removalSideEffect: @escaping (Int) async throws -> Void,
            moveSideEffect: @escaping (Int, Int) async throws -> Void
        ) async throws {
            // to track, at any given time, which removals haven't been applied yet (as part of a move)
            var unremovedElements = Set<UniquifiedElement>()
            
            // to calculate the correct offsets for a move when it occurs and to verify final result
            var oldListCopy = self.oldList.uniquifiedList
            
            for removal in self.canonicalDifference.removals.reversed() {
                switch removal {
                case let .remove(offset, element, associatedWith):
                    if associatedWith == nil {
                        oldListCopy.remove(at: offset)
                        try await removalSideEffect(offset)
                    } else {
                        // This removal is part of a move, so skip it for now.
                        // Since removals are iterated by high offset -> low offset, later removals
                        // in this loop won't be affected by this skip. Insertions may be affected,
                        // but we handle that dynamically in the later loop through insertions.
                        unremovedElements.insert(element)
                    }
                default:
                    throw Musubi.CollectionDiffingError.any(detail: "(impl err) saw insertion in removals")
                }
            }
            
            for insertion in self.canonicalDifference.insertions {
                switch insertion {
                case let .insert(originalInsertionOffset, insertionElement, associatedWith):
                    // Regardless of whether this insertion is a move, we need to adjust its offset to
                    // account for all unapplied removals at this moment in time.
                    var adjustedInsertionOffset = originalInsertionOffset
                    for unremovedElement in unremovedElements {
                        guard let unremovedElementCurrentOffset = oldListCopy.firstIndex(of: unremovedElement) else {
                            throw Musubi.CollectionDiffingError.any(detail: "(impl err) can't find unremoved element")
                        }
                        if unremovedElementCurrentOffset <= originalInsertionOffset {
                            adjustedInsertionOffset += 1
                        }
                    }
                    
                    if associatedWith == nil {
                        oldListCopy.insert(insertionElement, at: adjustedInsertionOffset)
                        try await insertionSideEffect(insertionElement, adjustedInsertionOffset)
                    } else {
                        // This insertion is part of a move.
                        // There is a probably a clever way to adjust `associatedWith`s, but for now
                        // we just brute-force search for the element-to-move's index at this particular
                        // moment in time. Correctness relies on the uniqueness of elements.
                        let elementToMove = insertionElement
                        guard let removalOffset = oldListCopy.firstIndex(of: elementToMove) else {
                            throw Musubi.CollectionDiffingError.any(detail: "(impl err) can't find unremoved element")
                        }
                        // If we had adjusted the insertion offset to account for the unremoved
                        // elementToMove (in the case that it's "earlier than" this insertion in the list),
                        // then correct it to account for the removal now actually being executed.
                        if removalOffset <= adjustedInsertionOffset {
                            adjustedInsertionOffset -= 1
                        }
                        unremovedElements.remove(elementToMove)
                        oldListCopy.remove(at: removalOffset)
                        oldListCopy.insert(elementToMove, at: adjustedInsertionOffset)
                        try await moveSideEffect(removalOffset, adjustedInsertionOffset)
                    }
                default:
                    throw Musubi.CollectionDiffingError.any(detail: "(impl err) saw removal in insertions")
                }
            }
            
            if oldListCopy != self.newList.uniquifiedList {
                throw Musubi.CollectionDiffingError.any(detail: "(impl err) newList != \(oldListCopy)")
            }
        }
        
        var pureInsertions: [CollectionDifference<UniquifiedElement>.Change] {
            return self.canonicalDifference.insertions.filter { change in
                switch change {
                case let .insert(_, _, associatedWith):
                    return associatedWith == nil
                default:
                    return false
                }
            }
        }
        
        var pureRemovals: [CollectionDifference<UniquifiedElement>.Change] {
            return self.canonicalDifference.removals.filter { change in
                switch change {
                case let .remove(_, _, associatedWith):
                    return associatedWith == nil
                default:
                    return false
                }
            }
        }
        
        var moveInsertions: [CollectionDifference<UniquifiedElement>.Change] {
            return self.canonicalDifference.insertions.filter { change in
                switch change {
                case let .insert(_, _, associatedWith):
                    return associatedWith != nil
                default:
                    return false
                }
            }
        }
    }
}

extension Musubi.DiffableList<String>.UniquifiedElement: CustomStringConvertible {
    var description: String {
        "(\"\(self.item)\", \(self.occurrence))"
    }
}
