//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import Foundation
import GoogleCast

final class ChromecastManager: NSObject {
    
    static let main = ChromecastManager()
    
    private let sessionManager: GCKSessionManager
    private let discoveryManager: GCKDiscoveryManager
    
    private(set) var currentDevices: [GCKDevice]
    
    override init() {
        sessionManager = GCKCastContext.sharedInstance().sessionManager
        discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        currentDevices = []
        super.init()
        
        let discoveryCriteria = GCKDiscoveryCriteria(applicationID: "WXS2A2XYGO.com.swiftfin")
        let gckCastOptions = GCKCastOptions(discoveryCriteria: discoveryCriteria)
        GCKCastContext.setSharedInstanceWith(gckCastOptions)
        discoveryManager.passiveScan = true
        discoveryManager.add(self)
        discoveryManager.startDiscovery()
    }
    
    func search() {
        
    }
}

extension ChromecastManager: GCKDiscoveryManagerListener {
    
    func didUpdateDeviceList() {
        
        let newDeviceCount = discoveryManager.deviceCount
        
        var newDevices: [GCKDevice] = []
        
        for deviceIndex in 0...(newDeviceCount - 1) {
            let device = discoveryManager.device(at: deviceIndex)
            newDevices.append(device)
        }
        
        currentDevices = newDevices
        
        print("New cast devices: ")
        print(newDevices)
    }
    
    func didInsert(_ device: GCKDevice, at index: UInt) {
        print("New device: \(device.friendlyName ?? "No name")")
        currentDevices.append(device)
    }
}
