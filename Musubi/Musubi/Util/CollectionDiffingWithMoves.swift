// CollectionDiffingWithMoves.swift

import Foundation

// TODO: improve memory/perf - current asymptotics are atrocious but should be fine for MVP

extension Musubi.ViewModel.AudioTrackList {
        func differenceCanonical(
            from other: Musubi.ViewModel.AudioTrackList
        ) async throws -> CollectionDifference<Musubi.ViewModel.AudioTrack> {
            try await self.initialHydrationTask.value
            try await other.initialHydrationTask.value
            
            return self.contents
                .difference(
                    from: other.contents,
                    by: { ($0.audioTrackID == $1.audioTrackID) && ($0.occurrence == $1.occurrence) }
                )
                .inferringMoves()
        }
        
        func differenceWithLiveMoves(
            from other: Musubi.ViewModel.AudioTrackList
        ) async throws -> [CollectionDifference<Musubi.ViewModel.AudioTrack>.Change] {
            try await self.initialHydrationTask.value
            try await other.initialHydrationTask.value
            
            typealias Change = CollectionDifference<Musubi.ViewModel.AudioTrack>.Change
            
            var differenceWithLiveMoves: [Change] = []
            
            let canonicalDifference = try await self.differenceCanonical(from: other)
            
            // to track, at any given time, which removals haven't been applied yet
            // (skipped as part of a move)
            var unremovedElements: [Musubi.ViewModel.AudioTrack] = []
            
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
                    throw CustomError.DEV(detail: "saw insertion in removals")
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
                            throw CustomError.DEV(detail: "can't find unremoved elem in oldLstCopy")
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
                            throw CustomError.DEV(detail: "can't find unremoved elem in oldLstCopy")
                        }
                        // If we had adjusted this insertion's offset to account for the unremoved
                        // elementToMove, then correct it to account for its actual removal now.
                        if removalOffset <= adjustedInsertionOffset {
                            adjustedInsertionOffset -= 1
                        }
                        if let unremovedElementIndex = unremovedElements.firstIndex(of: elementToMove) {
                            unremovedElements.remove(at: unremovedElementIndex)
                        } else {
                            throw CustomError.DEV(detail: "can't find unremoved elem in cache")
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
                    throw CustomError.DEV(detail: "saw removal in insertions")
                }
            }
            
            if oldListCopy != self.contents {
                throw CustomError.DEV(detail: "result \(oldListCopy) != expected \(self.contents)")
            }
            
            return differenceWithLiveMoves
        }
        
        struct VisualChange: Equatable, Hashable {
            let element: Musubi.ViewModel.AudioTrack
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
            try await self.initialHydrationTask.value
            try await other.initialHydrationTask.value
            
            var unifiedSummary: [VisualChange] = other.contents.map { element in
                VisualChange(element: element, change: .none)
            }
            
            let canonicalDifference = try await self.differenceCanonical(from: other)
            
            var unremovedElements: [Musubi.ViewModel.AudioTrack] = []
            
            for removal in canonicalDifference.removals.reversed() {
                switch removal {
                case let .remove(offset, element, _):
                    guard unifiedSummary[offset].element == element else {
                        throw CustomError.DEV(detail: "(visualDifference) mismatched initial removal offsets")
                    }
                    // associatedWith will be set during final phase.
                    unifiedSummary[offset].change = .removed(associatedWith: nil)
                    unremovedElements.append(element)
                default:
                    throw CustomError.DEV(detail: "(visualDifference) saw insertion in removals")
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
                            throw CustomError.DEV(detail: "(visualDifference) can't find unremoved element")
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
                    throw CustomError.DEV(detail: "(visualDifference) saw removal in insertions")
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
                            throw CustomError.DEV(detail: "(visualDifference) couldn't find moved element as removal")
                        }
                        guard let insertionIndex = unifiedSummaryIndexLookup[
                            VisualChange(
                                element: element,
                                change: .inserted(associatedWith: nil)
                            )
                        ] else {
                            throw CustomError.DEV(detail: "(visualDifference) couldn't find moved element as insertion")
                        }
                        
                        unifiedSummary[removalIndex].change = .removed(associatedWith: insertionIndex)
                        unifiedSummary[insertionIndex].change = .inserted(associatedWith: removalIndex)
                    }
                default:
                    throw CustomError.DEV(detail: "(visualDifference) saw insertion in removals")
                }
            }
            
            return unifiedSummary
        }
}
