// SelectableListSection.swift

import SwiftUI

// NOTE: ONLY INTENDED TO BE CALLED FROM STATIC VIEWS
// This view makes a copy of the list of selectable elements and will not react well to changes to
// that underlying list.

struct SelectableListSection<Element: Hashable, CustomListCell: View>: View {
    let sectionTitle: String
    
    let selectableList: [Element]
    
    let listCellBuilder: (Element) -> CustomListCell
    
    @Binding var selectedElements: Set<Element>
    
    var body: some View {
        Section(sectionTitle) {
            ForEach(selectableList, id: \.self) { element in
                HStack {
                    listCellBuilder(element)
                    if selectedElements.contains(element) {
                        Image(systemName: "checkmark.square.fill")
                            .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                            .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedElements.remove(element)
                            }
                    } else {
                        Image(systemName: "square")
                            .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                            .frame(height: Musubi.UI.ImageDimension.cellThumbnail.rawValue)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedElements.insert(element)
                            }
                    }
                }
                .listRowBackground(selectedElements.contains(element) ? Color.gray.opacity(0.5) : .none)
            }
        }
    }
}

//#Preview {
//    SelectableListSection()
//}
