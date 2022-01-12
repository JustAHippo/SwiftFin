//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import AVFAudio
import GoogleCast
import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
	static var orientationLock = UIInterfaceOrientationMask.all
    
    private var sessionManager: GCKSessionManager {
        GCKCastContext.sharedInstance().sessionManager
    }
    private var discoveryManager: GCKDiscoveryManager {
        GCKCastContext.sharedInstance().discoveryManager
    }

	func application(_ application: UIApplication,
	                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool
	{

		// Lazily initialize datastack
		_ = SwiftfinStore.dataStack
//        _ = ChromecastManager.main
        setupThis()

		let audioSession = AVAudioSession.sharedInstance()
		do {
			try audioSession.setCategory(.playback)
		} catch {
			print("setting category AVAudioSessionCategoryPlayback failed")
		}

		return true
	}

	func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
		AppDelegate.orientationLock
	}
}

extension AppDelegate {
    
    func setupThis() {
        let discoveryCriteria = GCKDiscoveryCriteria(applicationID: "F3E31345")
        let gckCastOptions = GCKCastOptions(discoveryCriteria: discoveryCriteria)
        
        let launchOptions = GCKLaunchOptions()
        launchOptions.androidReceiverCompatible = true
        gckCastOptions.launchOptions = launchOptions
        
        GCKCastContext.setSharedInstanceWith(gckCastOptions)
        discoveryManager.passiveScan = true
        discoveryManager.add(self)
        discoveryManager.startDiscovery()
    }
}

extension AppDelegate: GCKDiscoveryManagerListener {
    
    func didUpdateDeviceList() {
        
        let newDeviceCount = discoveryManager.deviceCount
        
        var newDevices: [GCKDevice] = []
        
        for deviceIndex in 0...(newDeviceCount - 1) {
            let device = discoveryManager.device(at: deviceIndex)
            newDevices.append(device)
        }
        
//        currentDevices = newDevices
        
        print(newDevices)
        
        print("New cast devices: ")
        print(newDevices)
    }
    
    func didInsert(_ device: GCKDevice, at index: UInt) {
        print("New device: \(device.friendlyName ?? "No name")")
    }
    
    func didHaveDiscoveredDeviceWhenStartingDiscovery() {
        print("here")
    }
}
