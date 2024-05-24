// SelectableListSection.swift

import SwiftUI

// TODO: - include ability to search through selection possibilities

// NOTE: ONLY INTENDED TO BE CALLED FROM STATIC VIEWS
// This view makes a copy of the list of selectable elements and will not react well to changes to
// that underlying list.

struct SelectableListSection<Element: Hashable, CustomListCell: View>: View {
    let selectableList: [Element]
    
    let listCellBuilder: (Element) -> CustomListCell
    
    @Binding var selectedElements: Set<Element>
    
    var body: some View {
        VStack {
            HStack {
                if selectedElements.count == selectableList.count {
                    Image(systemName: "checkmark.square.fill")
                        .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedElements.removeAll()
                        }
                } else if selectedElements.count == 0 {
                    Image(systemName: "square")
                        .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedElements.formUnion(selectableList)
                        }
                } else {
                    Image(systemName: "minus.square")
                        .font(.system(size: Musubi.UI.CHECKBOX_SYMBOL_SIZE))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedElements.removeAll()
                        }
                }
                Spacer()
            }
            .padding(.horizontal)
            Divider()
            ScrollView {
            LazyVStack(spacing: .zero) {
            ForEach(selectableList, id: \.self) { element in
                VStack(alignment: .leading, spacing: .zero) {
                Divider()
                HStack(spacing: .zero) {
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
                    listCellBuilder(element)
                        .padding(.leading)
                }
                .padding(.horizontal)
                .padding(.vertical, 9.87)
                .background(selectedElements.contains(element) ? Color.gray.opacity(0.5) : Color.clear)
                }
//                .listRowBackground(selectedElements.contains(element) ? Color.gray.opacity(0.5) : .none)
            }
            }
            }
        }
    }
}

//#Preview {
//    SelectableListSection()
//}
