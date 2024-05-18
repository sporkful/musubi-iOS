// CollectionDiffingWithMoves.swift

import Foundation

// TODO: improve memory/perf - current asymptotics are atrocious but should be fine for MVP

/*
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
        
        init(rawList: [RepeatableItem]) throws {
            var counter: [RepeatableItem : Int] = [:]
            var uniquifiedList: [UniquifiedElement] = []
            for item in rawList {
                counter[item] = (counter[item] ?? 0) + 1
                uniquifiedList.append(UniquifiedElement(item: item, occurrence: counter[item]!))
            }
            self.uniquifiedList = uniquifiedList
            
            if Set(self.uniquifiedList).count != self.uniquifiedList.count {
                throw Error.DEV(detail: "failed to uniquify raw list")
            }
        }
 */

extension Musubi.ViewModel.AudioTrackList {
        func differenceCanonical(
            from other: Musubi.ViewModel.AudioTrackList
        ) async -> CollectionDifference<UniquifiedElement> {
            return self.contents.difference(from: other.contents).inferringMoves()
        }
        
        func differenceWithLiveMoves(
            from other: Musubi.ViewModel.AudioTrackList
        ) async throws -> [CollectionDifference<UniquifiedElement>.Change] {
            typealias Change = CollectionDifference<UniquifiedElement>.Change
            
            var differenceWithLiveMoves: [Change] = []
            
            let canonicalDifference = await self.differenceCanonical(from: other)
            
            // to track, at any given time, which removals haven't been applied yet
            // (skipped as part of a move)
            var unremovedElements: [UniquifiedElement] = []
            
            // to calculate the correct offsets for a move when it occurs and to verify final result
            var oldListCopy = other.contents
            
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
                        } else {
                            break
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
            
            if oldListCopy != self.contents {
                throw Error.DEV(detail: "result \(oldListCopy) != expected \(self.contents)")
            }
            
            return differenceWithLiveMoves
        }
        
        struct VisualChange: Equatable, Hashable {
            let element: UniquifiedElement
            var change: Change
            
            enum Change: Equatable, Hashable {
                case none
                case inserted(associatedWith: Int?)
                case removed(associatedWith: Int?)
                
                /*
                 Note: would prefer to not do this since it changes semantics of enum equality
                 with potential side effects for this enum in other parts of the code.
                 The alternative workaround (which is currently implemented) is to just set all
                 `associatedWith`s = nil until the final move calculation phase.
                 
                // Ignore associated values (for correct `firstIndexOf` lookup).
                static func ==(lhs: Change, rhs: Change) -> Bool {
                    switch (lhs, rhs) {
                    case (.none, .none), (.inserted, .inserted), (.removed, .removed):
                        true
                    default:
                        false
                    }
                }
                 */
            }
        }
        
        func visualDifference(
            from other: Musubi.ViewModel.AudioTrackList
        ) async throws -> [VisualChange] {
            var unifiedSummary: [VisualChange] = other.contents.map { uniquifiedElement in
                VisualChange(element: uniquifiedElement, change: .none)
            }
            
            let canonicalDifference = await self.differenceCanonical(from: other)
            
            var unremovedElements: [UniquifiedElement] = []
            
            for removal in canonicalDifference.removals.reversed() {
                switch removal {
                case let .remove(offset, element, _):
                    guard unifiedSummary[offset].element == element else {
                        throw Error.DEV(detail: "(visualDifference) mismatched initial removal offsets")
                    }
                    // associatedWith will be set during final phase.
                    unifiedSummary[offset].change = .removed(associatedWith: nil)
                    unremovedElements.append(element)
                default:
                    throw Error.DEV(detail: "(visualDifference) saw insertion in removals")
                }
            }
            
            for insertion in canonicalDifference.insertions {
                switch insertion {
                case let .insert(originalInsertionOffset, insertionElement, _):
                    var adjustedInsertionOffset = originalInsertionOffset
                    for unremovedElement in unremovedElements.reversed() {
                        guard let unremovedElementCurrentOffset = unifiedSummary.firstIndex(
                            of: VisualChange(
                                element: unremovedElement,
                                change: .removed(associatedWith: nil)
                            )
                        )
                        else {
                            throw Error.DEV(detail: "(visualDifference) can't find unremoved element")
                        }
                        if unremovedElementCurrentOffset <= adjustedInsertionOffset {
                            adjustedInsertionOffset += 1
                        } else {
                            break
                        }
                    }
                    
                    // associatedWith will be set during final phase.
                    unifiedSummary.insert(
                        VisualChange(
                            element: insertionElement,
                            change: .inserted(associatedWith: nil)
                        ),
                        at: adjustedInsertionOffset
                    )
                default:
                    throw Error.DEV(detail: "(visualDifference) saw removal in insertions")
                }
            }
            
            var unifiedSummaryIndexLookup: [VisualChange: Int] = [:]
            for (index, element) in zip(unifiedSummary.indices, unifiedSummary) {
                unifiedSummaryIndexLookup[element] = index
            }
            
            // Note choosing to iterate over removals or insertions is arbitrary here, since both
            // are supersets of the set of all moves.
            for removal in canonicalDifference.removals {
                switch removal {
                case let .remove(_, element, associatedWith):
                    if associatedWith != nil {
                        guard let removalIndex = unifiedSummaryIndexLookup[
                            VisualChange(
                                element: element,
                                change: .removed(associatedWith: nil)
                            )
                        ] else {
                            throw Error.DEV(detail: "(visualDifference) couldn't find moved element as removal")
                        }
                        guard let insertionIndex = unifiedSummaryIndexLookup[
                            VisualChange(
                                element: element,
                                change: .inserted(associatedWith: nil)
                            )
                        ] else {
                            throw Error.DEV(detail: "(visualDifference) couldn't find moved element as insertion")
                        }
                        
                        unifiedSummary[removalIndex].change = .removed(associatedWith: insertionIndex)
                        unifiedSummary[insertionIndex].change = .inserted(associatedWith: removalIndex)
                    }
                default:
                    throw Error.DEV(detail: "(visualDifference) saw insertion in removals")
                }
            }
            
            return unifiedSummary
        }
}
