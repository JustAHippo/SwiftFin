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

class AppDelegate: NSObject, UIApplicationDelegate, GCKLoggerDelegate {
	static var orientationLock = UIInterfaceOrientationMask.all
    let kReceiverAppID = kGCKDefaultMediaReceiverApplicationID

	func application(_ application: UIApplication,
	                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool
	{

		// Lazily initialize datastack
		_ = SwiftfinStore.dataStack
        _ = ChromecastManager.main
        
        let criteria = GCKDiscoveryCriteria(applicationID: kReceiverAppID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        GCKCastContext.setSharedInstanceWith(options)
        
        print("APP ID: \(kReceiverAppID)")

        // Enable logger.
        GCKLogger.sharedInstance().delegate = self

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
    
    func logMessage(_ message: String,
                  at level: GCKLoggerLevel,
                  fromFunction function: String,
                  location: String) {
        print(function + " - " + message)
    }
}
