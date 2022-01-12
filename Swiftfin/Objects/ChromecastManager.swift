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
    
    private var sessionManager: GCKSessionManager {
        GCKCastContext.sharedInstance().sessionManager
    }
    private var discoveryManager: GCKDiscoveryManager {
        GCKCastContext.sharedInstance().discoveryManager
    }
    
    private(set) var currentDevices: [GCKDevice] = []
    
    override init() {
        super.init()
        
        let discoveryCriteria = GCKDiscoveryCriteria(applicationID: "F3E31345")
        let gckCastOptions = GCKCastOptions(discoveryCriteria: discoveryCriteria)
        
        let launchOptions = GCKLaunchOptions()
        launchOptions.androidReceiverCompatible = true
        gckCastOptions.launchOptions = launchOptions
        
        GCKCastContext.setSharedInstanceWith(gckCastOptions)
        discoveryManager.passiveScan = true
        discoveryManager.add(self)
        discoveryManager.startDiscovery()
        
        setupCastLogging()
        
        LogManager.shared.log.debug("Starting Chromecast discovery")
    }
    
    func search() {
//        discoveryManager.startDiscovery()
        print(discoveryManager.discoveryState.rawValue)
    }
    
    func setupCastLogging() {
        let logFilter = GCKLoggerFilter()
        let classesToLog = ["GCKDeviceScanner", "GCKDeviceProvider", "GCKDiscoveryManager",
                            "GCKCastChannel", "GCKMediaControlChannel", "GCKUICastButton",
                            "GCKUIMediaController", "NSMutableDictionary"]
        logFilter.setLoggingLevel(.verbose, forClasses: classesToLog)
        GCKLogger.sharedInstance().filter = logFilter
        GCKLogger.sharedInstance().delegate = self
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
    
    func didHaveDiscoveredDeviceWhenStartingDiscovery() {
        print("here")
    }
}

extension ChromecastManager: GCKLoggerDelegate {
    func logMessage(_ message: String,
                  at level: GCKLoggerLevel,
                  fromFunction function: String,
                  location: String) {
        print(function + " - " + message)
    }
}
