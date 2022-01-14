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
    
    @EnvironmentObject
    var castSelectorRouter: CastSelectorCoordinator.Router
    @State
    private var devices: [GCKDevice] = []
    @State
    private var currentSelectedDevice: GCKDevice?
    
    var body: some View {
        Group {
            if devices.isEmpty {
                Text("No devices found")
            } else {
                List(devices, id: \.self) { device in
                    if let currentSelectedDevice = currentSelectedDevice,
                       currentSelectedDevice.deviceID == device.deviceID {
                        Button {
                            ChromecastManager.main.stopCast()
                        } label: {
                            Label(device.friendlyName ?? "No Name", systemImage: "checkmark")
                        }
                    } else {
                        Button {
                            ChromecastManager.main.select(device: device)
                        } label: {
                            Text(device.friendlyName ?? "No Name")
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Chromecast", displayMode: .inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    castSelectorRouter.dismissCoordinator()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
        .onChange(of: ChromecastManager.main.currentDevices) { newValue in
            devices = newValue
        }
        .onChange(of: ChromecastManager.main.selectedDevice, perform: { newValue in
            currentSelectedDevice = newValue
        })
        .onAppear {
            devices = ChromecastManager.main.currentDevices
            currentSelectedDevice = ChromecastManager.main.selectedDevice
        }
    }
}
