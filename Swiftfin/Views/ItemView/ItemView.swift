//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import GoogleCast
import Introspect
import JellyfinAPI
import SwiftUI

// Intermediary view for ItemView to set navigation bar settings
struct ItemNavigationView: View {
	private let item: BaseItemDto

	init(item: BaseItemDto) {
		self.item = item
	}

	var body: some View {
		ItemView(item: item)
			.navigationBarTitle(item.name ?? "", displayMode: .inline)
			.introspectNavigationController { navigationController in
				let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.clear]
				navigationController.navigationBar.titleTextAttributes = textAttributes
			}
	}
}

private struct ItemView: View {
	@EnvironmentObject
	var itemRouter: ItemCoordinator.Router

	@State
	private var orientation: UIDeviceOrientation = .unknown
	@Environment(\.horizontalSizeClass)
	private var hSizeClass
	@Environment(\.verticalSizeClass)
	private var vSizeClass

	private let viewModel: ItemViewModel

	init(item: BaseItemDto) {
		switch item.itemType {
		case .movie:
			self.viewModel = MovieItemViewModel(item: item)
		case .season:
			self.viewModel = SeasonItemViewModel(item: item)
		case .episode:
			self.viewModel = EpisodeItemViewModel(item: item)
		case .series:
			self.viewModel = SeriesItemViewModel(item: item)
		case .boxset:
			self.viewModel = CollectionItemViewModel(item: item)
		default:
			self.viewModel = ItemViewModel(item: item)
		}
	}

	var body: some View {
		Group {
			if hSizeClass == .compact && vSizeClass == .regular {
				ItemPortraitMainView()
					.environmentObject(viewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                itemRouter.route(to: \.castSelector)
                            } label: {
                                WrappedCastButton()
                            }
                        }
                    }
			} else {
				ItemLandscapeMainView()
					.environmentObject(viewModel)
			}
		}
	}
}

struct WrappedCastButton: UIViewRepresentable {
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
    
    func makeUIView(context: Context) -> some UIView {
        let castButton = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        castButton.tintColor = UIColor.white
        
        return castButton
    }
}
