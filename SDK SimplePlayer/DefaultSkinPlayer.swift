//
//  PlayerViewController.swift
//  SDK SimplePlayer
//
//  Created by Udaya Sri Senarathne on 2022-07-04.
//

import Foundation
import UIKit
import iOSClientExposure
import iOSClientExposurePlayback
import iOSClientPlayer
import AVFoundation
import AVKit


class DefaultSkinPlayer: UIViewController, AVPictureInPictureControllerDelegate, AVPlayerViewControllerDelegate {
    
    var environment: Environment!
    var sessionToken: SessionToken!
    
    var playable: Playable?
    
    let audioSession = AVAudioSession.sharedInstance()
    var playbackProperties = PlaybackProperties()
    fileprivate(set) var player: Player<HLSNative<ExposureContext>>!
    
    @objc dynamic var playerViewController: AVPlayerViewController?
    
    fileprivate(set) var avPlayerLayer: AVPlayerLayer? = nil
    
    fileprivate let context = ManifestContext()
    fileprivate let tech = HLSNative<ManifestContext>()
    
    /// Main ContentView which holds player view & player control views
    let mainContentView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    let playerView = UIView()
    
    var adsDuration: Float?
    
    private var pictureInPictureController: AVPictureInPictureController?
    
    override func loadView() {
        super.loadView()
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        player.stop()
        player = nil
        avPlayerLayer?.removeFromSuperlayer()
        self.playerViewController = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black
        self.title = "Asset title "
        
        setupPlayer(environment, sessionToken)
        self.enableAudioSeesionForPlayer()
        
    }

    override func didMove(toParent parent: UIViewController?) {
        if let player = self.player, player.tech.isPlaying {
            
            avPlayerLayer?.removeFromSuperlayer()
            self.playerViewController = nil
            player.stop()
            
        }
    }
    
    
    deinit {
        // view.unbindToKeyboard()
    }
}

// MARK: - Setup Player
extension DefaultSkinPlayer {
    
    
    // reset by removing the playerViewController & creating a new one
    public func reset() -> AVPlayerViewController {
        
        if let playerViewController = self.playerViewController {
            playerViewController.removeFromParent()
            playerViewController.viewIfLoaded?.removeFromSuperview()
        }
        
        let newAVPlayerViewController = AVPlayerViewController()
        self.playerViewController = newAVPlayerViewController
        if let playerViewController = playerViewController {
            addChild(playerViewController)
            if isViewLoaded {
                view.addSubview(playerViewController.view)
            }
            playerViewController.delegate = self
        }
        return newAVPlayerViewController
    }
    
    fileprivate func setupPlayer(_ environment: Environment, _ sessionToken: SessionToken) {
        /// This will configure the player with the `SessionToken` acquired in the specified `Environment`
        player = Player(environment: environment, sessionToken: sessionToken)
        
        let newpPlayerViewController = reset()
        
        player.configureWithDefaultSkin(avPlayerViewController: newpPlayerViewController)
        
        //        if let layer = avPlayerLayer {
        //            pictureInPictureController = AVPictureInPictureController(playerLayer: layer)
        //            pictureInPictureController?.delegate = self
        //        }
        
        // The preparation and loading process can be followed by listening to associated events.
        player
            .onPlaybackCreated{ [weak self] player, source in
                // Fires once the associated MediaSource has been created.
                // Playback is not ready to start at this point.
                
            }
            .onPlaybackPrepared{ player, source in
                // Published when the associated MediaSource completed asynchronous loading of relevant properties.
                // Playback is not ready to start at this point.
            }
            .onPlaybackReady{ player, source in
                // When this event fires starting playback is possible (playback can optionally be set to autoplay instead)
                player.play()
            }
        
        // Once playback is in progress the Player continuously publishes events related media status and user interaction.
            .onPlaybackStarted{ [weak self] player, source in
                // Published once the playback starts for the first time.
                // This is a one-time event.
                guard let `self` = self else { return }
                
                print(" playback started ")
                print(" Player duration " , player.duration )
            }
            .onPlaybackPaused{ [weak self] player, source in
                // Fires when the playback pauses for some reason
                guard let `self` = self else { return }
                
            }
            .onPlaybackResumed{ [weak self] player, source in
                // Fires when the playback resumes from a paused state
                guard let `self` = self else { return }
                
            }
            .onPlaybackAborted{ player, source in
                // Published once the player.stop() method is called.
                // This is considered a user action
                
            }
            .onPlaybackCompleted{ player, source in
                // Published when playback reached the end of the current media.
            }
            .onPlaybackStartWithAds { [weak self] vodDuration, adDuration, totalDurationInMs, adMarkers   in
                guard let `self` = self else { return }
                
            }
        
            .onServerSideAdShouldSkip { [weak self] skipTime in
                guard let `self` = self else { return }
                self.player.seek(toPosition: skipTime )
            }
            .onWillPresentInterstitial { [weak self] contractRestrictionService, clickThroughUrl, adTrackingUrls, adClipDuration, noOfAds, adIndex in
                
                // `Ad` started playing
                
            }
        
            .onDidPresentInterstitial { [weak self] contractRestrictionService  in
                guard let `self` = self else { return }
                
                // `Ad` stopped playing
            }
        
            .onTimedMetadataChanged { _,_, item in
                // print(" Metada item ", item)
            }
        
        // Besides playback control events Player also publishes several status related events.
        player
            .onProgramChanged { [weak self] player, source, program in
                // Update user facing program information
                guard let `self` = self else { return }
                
            }
        
            .onEntitlementResponse { [weak self] player, source, entitlement  in
                // Fires when a new entitlement is received, such as after attempting to start playback
                guard let `self` = self else { return }
                
            }
            .onBitrateChanged{ player, source, bitrate in
                // Published whenever the current bitrate changes
                //self?.updateQualityIndicator(with: bitrate)
            }
            .onBufferingStarted{ player, source in
                // Fires whenever the buffer is unable to keep up with playback
            }
            .onBufferingStopped{ player, source in
                // Fires when buffering is no longer needed
            }
            .onDurationChanged{ player, source in
                // Published when the active media received an update to its duration property
            }
        
        // Error handling can be done by listening to associated event.
        player
            .onError{ [weak self] player, source, error in
                guard let `self` = self else { return }
                // print(" Player Error " , error)
            }
        
            .onWarning{ [weak self] player, source, warning in
                guard let `self` = self else { return }
                
                // warning
            }
        
        // Media Type
            .onMediaType { [weak self] type in
                // Media Type : audio / video
                // print(" Media Type \(type) ")
            }
        
        // Start the playback
        self.startPlayBack(properties: playbackProperties)
        
    }
    
    /// Start the playback with given properties
    ///
    /// - Parameter properties: playback properties
    func startPlayBack(properties: PlaybackProperties = PlaybackProperties() ) {
        
        guard let playable = playable else { return }
        player.startPlayback(playable: playable, properties: properties)
        
        
    }
}

extension DefaultSkinPlayer {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "isPictureInPicturePossible" else {
            return
        }
        
        if let pipController = object as? AVPictureInPictureController {
            if pipController.isPictureInPicturePossible {
                pipController.startPictureInPicture()
            }
        }
    }
    
    func picture(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        //Update video controls of main player to reflect the current state of the video playback.
        //You may want to update the video scrubber position.
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //Handle PIP will start event
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //Handle PIP did start event
    }
    
    func picture(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        //Handle PIP failed to start event
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //Handle PIP will stop event
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //Handle PIP did start event
    }
}


// MARK: - Layout
extension DefaultSkinPlayer {
    fileprivate func setUpLayout() {
        view.addSubview(mainContentView)
        mainContentView.addArrangedSubview(playerView)
    }
}

extension DefaultSkinPlayer {
    /// Enable the audio session for player
    fileprivate func enableAudioSeesionForPlayer() {
        do {
            if #available(iOS 11.0, *) {
                try audioSession.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.moviePlayback, policy: AVAudioSession.RouteSharingPolicy.longFormAudio)
            }
            else {
                try audioSession.setCategory(AVAudioSession.Category.playback)
            }
            try audioSession.setActive(true)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
    }
    
    
    /// Disable player audio session & continue the background playback
    fileprivate func resumeBackgroundAudio() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print ("setActive(false) ERROR : \(error)")
        }
    }
}



