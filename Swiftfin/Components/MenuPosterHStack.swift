//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

enum PosterHStackState<Item: Poster> {
    case loading
    case noResults
    case items([Item])
}

struct MenuPosterHStack<Model: MenuPosterHStackModel, Content: View, ImageOverlay: View, ContextMenu: View>: View {

    @ObservedObject
    private var manager: Model

    private let type: PosterType
    private var itemScale: CGFloat
    private let singleImage: Bool
    private var content: (Model.Item) -> Content
    private var imageOverlay: (Model.Item) -> ImageOverlay
    private var contextMenu: (Model.Item) -> ContextMenu
    private var onSelect: (Model.Item) -> Void
    
    @ViewBuilder
    private var selectorMenu: some View {
        Menu {
            ForEach(manager.sections.keys.sorted(by: { manager.sectionMenuSort($0, $1) }), id: \.displayName) { section in
                Button {
                    manager.select(section: section)
                } label: {
                    if section == manager.selection {
                        Label(section.displayName, systemImage: "checkmark")
                    } else {
                        Text(section.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Group {
                    Text(manager.selection?.displayName ?? .emptyDash)
                        .fixedSize()
                    Image(systemName: "chevron.down")
                }
                .font(.title3.weight(.semibold))
            }
        }
    }

    var body: some View {
        if let selection = manager.selection, let section = manager.sections[selection] {
            switch section {
            case .loading:
                PosterHStack(
                    type: type,
                    state: PosterHStackState<Model.Item>.loading)
                .scaleItems(itemScale)
                .header {
                    selectorMenu
                }
            case .noResults:
                Text("No Results")
            case let .items(items):
                PosterHStack(
                    type: type,
                    items: items,
                    singleImage: singleImage
                )
                .scaleItems(itemScale)
                .header {
                    selectorMenu
                }
                .content(content)
                .imageOverlay(imageOverlay)
                .contextMenu(contextMenu)
                .onSelect { item in
                    onSelect(item)
                }
            }
        } else {
            PosterHStack(
                type: type,
                items: [BaseItemDto.noResults]
            )
        }
    }
}

extension MenuPosterHStack where Content == PosterButtonDefaultContentView<Model.Item>,
    ImageOverlay == EmptyView,
    ContextMenu == EmptyView
{

    init(
        type: PosterType,
        manager: Model,
        singleImage: Bool = false
    ) {
        self.init(
            manager: manager,
            type: type,
            itemScale: 1,
            singleImage: singleImage,
            content: { PosterButtonDefaultContentView(state: .item($0)) },
            imageOverlay: { _ in EmptyView() },
            contextMenu: { _ in EmptyView() },
            onSelect: { _ in }
        )
    }
}

extension MenuPosterHStack {
    
    func scaleItems(_ scale: CGFloat) -> Self {
        copy(modifying: \.itemScale, with: scale)
    }

    func content<C: View>(@ViewBuilder _ content: @escaping (Model.Item) -> C)
    -> MenuPosterHStack<Model, C, ImageOverlay, ContextMenu> {
        .init(
            manager: manager,
            type: type,
            itemScale: itemScale,
            singleImage: singleImage,
            content: content,
            imageOverlay: imageOverlay,
            contextMenu: contextMenu,
            onSelect: onSelect
        )
    }
    
    func imageOverlay<O: View>(@ViewBuilder _ imageOverlay: @escaping (Model.Item) -> O)
    -> MenuPosterHStack<Model, Content, O, ContextMenu> {
        .init(
            manager: manager,
            type: type,
            itemScale: itemScale,
            singleImage: singleImage,
            content: content,
            imageOverlay: imageOverlay,
            contextMenu: contextMenu,
            onSelect: onSelect
        )
    }
    
    func contextMenu<C: View>(@ViewBuilder _ contextMenu: @escaping (Model.Item) -> C)
    -> MenuPosterHStack<Model, Content, ImageOverlay, C> {
        .init(
            manager: manager,
            type: type,
            itemScale: itemScale,
            singleImage: singleImage,
            content: content,
            imageOverlay: imageOverlay,
            contextMenu: contextMenu,
            onSelect: onSelect
        )
    }

    func onSelect(_ action: @escaping (Model.Item) -> Void) -> Self {
        copy(modifying: \.onSelect, with: action)
    }
}
