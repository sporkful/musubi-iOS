// CollectionDiffingWithMoves.swift

import Foundation

// TODO: improve memory/perf
// (this should be fine for now since we'll never have >2 of these and playlist sizes are relatively small)

// namespaces
extension Musubi {
    struct Diffing {
        private init() {}
        
        enum Error: LocalizedError {
            case misc(detail: String)
            case DEV(detail: String)

            var errorDescription: String? {
                let description = switch self {
                    case let .misc(detail): "(misc) \(detail)"
                    case let .DEV(detail): "(DEV) \(detail)"
                }
                return "[Musubi::Diffing] \(description)"
            }
        }
    }
}

extension Musubi.Diffing {
    struct DiffableList<RepeatableItem: Hashable> {
        struct UniquifiedElement: Hashable, Equatable {
            let item: RepeatableItem
            let occurrence: Int  // per-item-value counter starting at 1
        }
        
        let uniquifiedList: [UniquifiedElement]  // TODO: rename this to e.g. `contents`
        let indexLookup: [UniquifiedElement: Int]  // TODO: do we need this?
        
        init(rawList: [RepeatableItem]) throws {
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
            
            if Set(self.uniquifiedList).count != self.uniquifiedList.count {
                throw Error.DEV(detail: "failed to uniquify raw list")
            }
        }
        
        func differenceCanonical(
            from other: Self
        ) -> CollectionDifference<UniquifiedElement> {
            return self.uniquifiedList.difference(from: other.uniquifiedList).inferringMoves()
        }
        
        func differenceWithLiveMoves(
            from other: Self
        ) throws -> [CollectionDifference<UniquifiedElement>.Change] {
            typealias Change = CollectionDifference<UniquifiedElement>.Change
            
            var differenceWithLiveMoves: [Change] = []
            
            let canonicalDifference = self.differenceCanonical(from: other)
            
            // to track, at any given time, which removals haven't been applied yet
            // (skipped as part of a move)
            var unremovedElements: [UniquifiedElement] = []
            
            // to calculate the correct offsets for a move when it occurs and to verify final result
            var oldListCopy = other.uniquifiedList
            
            for removal in canonicalDifference.removals.reversed() {
                switch removal {
                case let .remove(offset, element, associatedWith):
                    if associatedWith == nil {
                        oldListCopy.remove(at: offset)
                        differenceWithLiveMoves.append(
                            Change.remove(
                                offset: offset,
                                element: element,
                                associatedWith: nil
                            )
                        )
                    } else {
                        // This removal is part of a move, so skip it for now.
                        // Since removals are iterated by high offset -> low offset, later removals
                        // in this loop won't be affected by this skip. Insertions may be affected,
                        // but we handle that dynamically in the later loop through insertions.
                        unremovedElements.append(element)
                    }
                default:
                    throw Error.DEV(detail: "saw insertion in removals")
                }
            }
            
            for insertion in canonicalDifference.insertions {
                switch insertion {
                case let .insert(originalInsertionOffset, insertionElement, associatedWith):
                    // Regardless of whether this insertion is a move, we need to adjust its offset to
                    // account for all unapplied removals at this moment in time.
                    var adjustedInsertionOffset = originalInsertionOffset
                    for unremovedElement in unremovedElements.reversed() {
                        // TODO: take advantage of fact that unremovedElements is already ordered(?)
                        guard let unremovedElementCurrentOffset = oldListCopy.firstIndex(of: unremovedElement) else {
                            throw Error.DEV(detail: "can't find unremoved elem in oldLstCopy")
                        }
                        if unremovedElementCurrentOffset <= adjustedInsertionOffset {
                            adjustedInsertionOffset += 1
                        }
                    }
                    
                    if associatedWith == nil {
                        oldListCopy.insert(insertionElement, at: adjustedInsertionOffset)
                        differenceWithLiveMoves.append(
                            Change.insert(
                                offset: adjustedInsertionOffset,
                                element: insertionElement,
                                associatedWith: nil
                            )
                        )
                    } else {
                        // This insertion is part of a move.
                        // There is a probably a clever way to adjust `associatedWith`s, but for now
                        // we brute-force search for the element-to-move's index at this particular
                        // moment in time. Correctness relies on the uniqueness of elements.
                        let elementToMove = insertionElement
                        guard let removalOffset = oldListCopy.firstIndex(of: elementToMove) else {
                            throw Error.DEV(detail: "can't find unremoved elem in oldLstCopy")
                        }
                        // If we had adjusted this insertion's offset to account for the unremoved
                        // elementToMove, then correct it to account for its actual removal now.
                        if removalOffset <= adjustedInsertionOffset {
                            adjustedInsertionOffset -= 1
                        }
                        // TODO: take advantage of fact that unremovedElements is already ordered(?)
                        if let unremovedElementIndex = unremovedElements.firstIndex(of: elementToMove) {
                            unremovedElements.remove(at: unremovedElementIndex)
                        } else {
                            throw Error.DEV(detail: "can't find unremoved elem in cache")
                        }
                        oldListCopy.remove(at: removalOffset)
                        oldListCopy.insert(elementToMove, at: adjustedInsertionOffset)
                        differenceWithLiveMoves.append(
                            Change.insert(
                                offset: adjustedInsertionOffset,
                                element: elementToMove,
                                associatedWith: removalOffset
                            )
                        )
                    }
                default:
                    throw Error.DEV(detail: "saw removal in insertions")
                }
            }
            
            if oldListCopy != self.uniquifiedList {
                throw Error.DEV(detail: "result \(oldListCopy) != expected \(self.uniquifiedList)")
            }
            
            return differenceWithLiveMoves
        }
    }
}

extension Musubi.Diffing.DiffableList<String>.UniquifiedElement: CustomStringConvertible {
    var description: String {
        "(\"\(self.item)\", \(self.occurrence))"
    }
}
