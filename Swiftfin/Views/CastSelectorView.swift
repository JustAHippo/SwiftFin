//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import GoogleCast
import SwiftUI

struct CastSelectorView: View {
    
    @State
    private var devices: [GCKDevice] = []
    
    var body: some View {
        List(devices, id: \.self) { device in
            Text(device.friendlyName ?? "No name")
        }
        .navigationTitle("Chromecast")
        .navigationBarTitleDisplayMode(.inline)
//        .onChange(of: ChromecastManager.main.currentDevices) { newValue in
//            devices = newValue
//        }
    }
}
