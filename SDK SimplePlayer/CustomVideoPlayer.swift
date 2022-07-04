//
//  CustomVideoPlayer.swift
//  SDK SimplePlayer
//
//  Created by Udaya Sri Senarathne on 2022-07-04.
//

import Foundation
import UIKit
import SwiftUI
import iOSClientExposure
import iOSClientExposurePlayback

struct CustomVideoPlayer: UIViewControllerRepresentable {
    
    var playable : AssetPlayable
    
    var env: iOSClientExposure.Environment {
        .init(
            baseUrl: "",
            customer: "",
            businessUnit: ""
        )
    }

    var sessionToken: SessionToken {
        .init(
            value: ""
        )
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let playerViewController = DefaultSkinPlayer()
        playerViewController.playable = playable
        playerViewController.environment = env
        playerViewController.sessionToken = sessionToken
        return playerViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // print(" Update UI View Controller ")
    }
}
