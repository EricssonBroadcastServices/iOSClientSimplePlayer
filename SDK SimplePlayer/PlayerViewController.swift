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
import GoogleCast
import iOSClientCast
import AVKit

class PlayerViewController: UIViewController, GCKRemoteMediaClientListener, AVPictureInPictureControllerDelegate {
    
    var environment: Environment!
    var sessionToken: SessionToken!
    
    var playable: Playable?
    var program: Program?
    var channel: Asset?
    
    let audioSession = AVAudioSession.sharedInstance()
    var offlineMediaPlayable: OfflineMediaPlayable?
    var playbackProperties = PlaybackProperties()
    fileprivate(set) var player: Player<HLSNative<ExposureContext>>!
    
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
    
    let pausePlayButton: UIButton = {
        let button = UIButton()
        button.tintColor = .white
        button.addTarget(self, action: #selector(actionPausePlay(_:)), for: .touchUpInside)
        return button
    }()
    
    
    let playerView = UIView()
    let programBasedTimeline = ProgramBasedTimeline()
    
    let vodBasedTimeline = VodBasedTimeline()
    
//    let castImage: UIImageView = {
//        let image = UIImage(named: "cast")
//        let imageView = UIImageView(image: image!)
//        return imageView
//    }()
    
    private var castButton: GCKUICastButton!
    
    var nowPlaying: Playable?
    var nowPlayingMetadata: Asset?
    var onChromeCastRequested: (Playable, Asset?, Int64?, Int64?) -> Void = { _,_,_,_ in }
    
    var castChannel: Channel = Channel()
    var castSession: GCKCastSession?
    
    var adsDuration: Float?
    
    private var pictureInPictureController: AVPictureInPictureController?
    
    override func loadView() {
        super.loadView()
        
        setUpLayout()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black
        self.title = channel?.assetId
        
        self.vodBasedTimeline.isHidden = true
        self.programBasedTimeline.isHidden = true
        
        setupPlayer(environment, sessionToken)
        self.enableAudioSeesionForPlayer()
        
        // Google Cast
        self.showChromecastButton() // Show cast button in the navigation menu
        GCKCastContext.sharedInstance().sessionManager.add(self)
        showCastButtonInPlayer() // Hide player controls & Show cast button if there is any active cast session
    }
    
    override func didMove(toParent parent: UIViewController?) {
        if let player = self.player, player.tech.isPlaying {
            if playable is ProgramPlayable || playable is ChannelPlayable {
                programBasedTimeline.stopLoop()
            } else if playable is AssetPlayable {
                vodBasedTimeline.stopLoop()
            }
            player.stop()
            
//            DispatchQueue.main.async {
//                // self.playerView.layer.sublayers = nil
//                self.avPlayerLayer = nil
//            }
           
        }
    }
    
    @objc func dissmissKeyboard() {
        view.endEditing(true)
    }
    
    deinit {
        // view.unbindToKeyboard()
    }
}

// MARK: - Setup Player
extension PlayerViewController {
    
    fileprivate func setupPlayer(_ environment: Environment, _ sessionToken: SessionToken) {
        /// This will configure the player with the `SessionToken` acquired in the specified `Environment`
        player = Player(environment: environment, sessionToken: sessionToken)
        player.configure(playerView: playerView)
        
//        if let layer = avPlayerLayer {
//            pictureInPictureController = AVPictureInPictureController(playerLayer: layer)
//            pictureInPictureController?.delegate = self
//        }
        
        
        
        // The preparation and loading process can be followed by listening to associated events.
        player
            .onPlaybackCreated{ [weak self] player, source in
                // Fires once the associated MediaSource has been created.
                // Playback is not ready to start at this point.
                self?.updateTimeLine(streamingInfo: source.streamingInfo)
                
                
            }
            .onPlaybackPrepared{ player, source in
                // Published when the associated MediaSource completed asynchronous loading of relevant properties.
                // Playback is not ready to start at this point.
            }
            .onPlaybackReady{ player, source in
                // When this event fires starting playback is possible (playback can optionally be set to autoplay instead)
                
                print("\n")
                
                self.programBasedTimeline.seekableTimeRanges = { [weak self] in
                    return self?.player.seekableTimeRanges
                }
                
                player.play()
            }
        
        // Once playback is in progress the Player continuously publishes events related media status and user interaction.
            .onPlaybackStarted{ [weak self] player, source in
                // Published once the playback starts for the first time.
                // This is a one-time event.
                guard let `self` = self else { return }
                
                /* if let currentItem = player.playerItem ,
                  let textStyle = AVTextStyleRule(textMarkupAttributes: [kCMTextMarkupAttribute_OrthogonalLinePositionPercentageRelativeToWritingDirection as String: 10]), let textStyle1:AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
                            kCMTextMarkupAttribute_CharacterBackgroundColorARGB as String: [0,0,1,0.3]
                            ]), let textStyle2:AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
                                kCMTextMarkupAttribute_ForegroundColorARGB as String: [1,0,1,1.0]
                    ]), let textStyleSize3: AVTextStyleRule = AVTextStyleRule(textMarkupAttributes: [
                        kCMTextMarkupAttribute_RelativeFontSize as String: 200
                    ]) {
                    
                    currentItem.textStyleRules = [textStyle, textStyle1, textStyle2, textStyleSize3]
                } */
                
                
            }
            .onPlaybackPaused{ [weak self] player, source in
                // Fires when the playback pauses for some reason
                guard let `self` = self else { return }
                
                self.togglePlayPauseButton(paused: true)
            }
            .onPlaybackResumed{ [weak self] player, source in
                // Fires when the playback resumes from a paused state
                guard let `self` = self else { return }
                self.togglePlayPauseButton(paused: false)
            }
            .onPlaybackAborted{ player, source in
                // Published once the player.stop() method is called.
                // This is considered a user action
                
            }
            .onPlaybackCompleted{ player, source in
                // Published when playback reached the end of the current media.
            }
        
        
            .onPlaybackStartWithAds { [weak self] vodDuration, adDuration, totalDurationInMs, adMarkers   in
                
                
                print(" on playback start with Ads ")
                
                guard let `self` = self else { return }

                
                self.vodBasedTimeline.isHidden = false
                self.programBasedTimeline.isHidden = true
                
                self.togglePlayPauseButton(paused: false)
                
                self.adsDuration = Float(adDuration)
                
                self.vodBasedTimeline.vodContentDuration = {
                    return ( totalDurationInMs - adDuration  )
                }
                
                
                
                // playback starts with ads which includes total actual clip duration (excluding ads ) & ad positions in the timeline
                if adMarkers.count != 0 {
                    self.vodBasedTimeline.adMarkers = adMarkers
                    self.vodBasedTimeline.showAdTickMarks(adMarkers: adMarkers, totalDuration: totalDurationInMs, vodDuration: totalDurationInMs - adDuration )
                }
            }
        
            .onServerSideAdShouldSkip { [weak self] skipTime in
                guard let `self` = self else { return }
                self.player.seek(toPosition: skipTime )
            }
            .onWillPresentInterstitial { [weak self] contractRestrictionService, clickThroughUrl, adTrackingUrls, adClipDuration, noOfAds, adIndex in

                print("onWillPresentInterstitial " )
                print("clickThroughUrl is available " , clickThroughUrl )
                print(" adClip Duration " , adClipDuration )
                
                
                guard let `self` = self else { return }
                self.vodBasedTimeline.pausedTimer()
                guard let policy = contractRestrictionService.contractRestrictionsPolicy else { return }
                self.vodBasedTimeline.canFastForward = policy.fastForwardEnabled
                self.vodBasedTimeline.canRewind = policy.rewindEnabled
                
                self.vodBasedTimeline.adDuration =  self.vodBasedTimeline.adDuration + adClipDuration
                // self.vodBasedTimeline.onAdStart = true
                self.vodBasedTimeline.isHidden = true
                
                
                print(" Ad Counter \(adIndex ) / \(noOfAds)")
              
                
            }
        
            .onDidPresentInterstitial { [weak self] contractRestrictionService  in
                guard let `self` = self else { return }

                print("onDidPresentInterstitial ")
                
                self.vodBasedTimeline.resumeTimer()
                guard let policy = contractRestrictionService.contractRestrictionsPolicy else { return }
                self.vodBasedTimeline.canFastForward = policy.fastForwardEnabled
                self.vodBasedTimeline.canRewind = policy.rewindEnabled
                // self?.vodBasedTimeline.startLoop()
                // self.vodBasedTimeline.onAdStop = true
                self.vodBasedTimeline.isHidden = false
                
                // print(" Player Time Range " , self.player.seekableTimeRanges )
            }
        
            .onTimedMetadataChanged { _,_, item in
                print(" Metada item ", item)
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

                
                self.activateSprites(sprites: source.sprites)
                
                
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
                
               print(" Error ")
            }
            
            .onWarning{ [weak self] player, source, warning in
                guard let `self` = self else { return }
                // self.showToastMessage(message: warning.message, duration: 5)
            }
        
        // Media Type
        .onMediaType { [weak self] type in
            // Media Type : audio / video
            
            print(" media Type " , type )
        }
        
        // Playback Progress
        programBasedTimeline.onSeek = { [weak self] offset in
            self?.player.seek(toTime: offset)
        }
        
        programBasedTimeline.currentPlayheadTime = { [weak self] in
            return self?.player.playheadTime
        }
        
        programBasedTimeline.timeBehindLiveEdge = { [weak self] in
            return self?.player.timeBehindLive
        }
        programBasedTimeline.goLiveTrigger = { [weak self] in
            self?.player.seekToLive()
        }
        programBasedTimeline.startOverTrigger = { [weak self] in
            if let programStartTime = self?.player.currentProgram?.startDate?.millisecondsSince1970 {
                self?.player.seek(toTime: programStartTime)
            }
        }
        
        vodBasedTimeline.onSeek = { [weak self] offset in
            
            print(" Vod timeline on seek " , offset )
            
            if let currentTime = self?.player.playheadPosition {
                self?.player.seek(toPosition: offset)
            }
            
            
            // self?.player.seek(toTime: offset)
            
            // self?.player.seek(toPosition: offset)
        }
        
        vodBasedTimeline.onScrubbing = { [weak self] time in
            
//            print(" Player Duration " , self?.player.duration )
//            print(" Player Duration " , self?.player.playerItem?.duration )
//
//            print(" Asset ID in the player " , self?.playable?.assetId )
            
            if let assetId = self?.playable?.assetId {
                let _ = self?.player.getSprite(time: time, assetId: assetId,callback: { image, startTime, endTime in
                    guard let image = image else { return }
                    self?.updateSpriteImage(image)
                })
            }
            
        }
        
        vodBasedTimeline.currentPlayheadPosition = { [weak self] in
            return self?.player.playheadPosition
        }
        vodBasedTimeline.currentDuration = { [weak self] in
            return self?.player.duration
        }
        
        player.playerItem?.currentTime()
        
        vodBasedTimeline.startOverTrigger = { [weak self] in
            self?.player.seek(toPosition:0)
        }
        
        // Start the playback
        self.startPlayBack(properties: playbackProperties)
        
    }
    
    /// Start the playback with given properties
    ///
    /// - Parameter properties: playback properties
    func startPlayBack(properties: PlaybackProperties = PlaybackProperties() ) {
        
        nowPlaying = playable
        
        if let offlineMediaPlayable = offlineMediaPlayable {
            player.startPlayback(offlineMediaPlayable: offlineMediaPlayable )
        } else {
            if let playable = playable {
                
                if GCKCastContext.sharedInstance().sessionManager.hasConnectedCastSession() {
                    self.chromecast(playable: playable, in: environment, sessionToken: sessionToken, currentplayheadTime: self.player.playheadTime)
                } else {
                    
                    vodBasedTimeline.isHidden = true
                    programBasedTimeline.isHidden = true
                    
                    print(" Start play \(playable.assetId) ")
                    
                    let customAds:[String:Any] = ["TestKey1":1, "TestKey2":"test", "TestKey3": true]
                    player.startPlayback(playable: playable, properties: properties)
                    
                }
                
            }
        }
    }
    
    func activateSprites(sprites: [Sprites]?) {
        if let playable = playable, let sprites = sprites , let width = sprites.first?.width {
            let _ = self.player.activateSprites(assetId: playable.assetId, width: width, quality: .medium) {  spritesData, error in
                 print(" Sprites have been Activated " , spritesData )
            }
        }
    }
    
    func updateSpriteImage(_ image: UIImage) {
        // if let image = image {
        self.vodBasedTimeline.spriteImageView.image = image
        
    }
    
    func updateTimeLine(streamingInfo: StreamInfo?) {
        
        guard let streamingInfo = streamingInfo else {
            // print("Streaming Info is empty :: Using PlayV1 ")
            // let okAction = UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel, handler: {
            //     (alert: UIAlertAction!) -> Void in
            // })
            
            // let message = "Streaming Info is missing in the play response : You are using a older version of the SDK"
            // self.popupAlert(title: "Error" , message: message, actions: [okAction], preferedStyle: .alert)
            
            vodBasedTimeline.isHidden = false
            vodBasedTimeline.startLoop()
            programBasedTimeline.isHidden = true
            programBasedTimeline.stopLoop()
            
            return
        }
        if streamingInfo.live == true && streamingInfo.staticProgram == false {
            vodBasedTimeline.isHidden = true
            vodBasedTimeline.stopLoop()
            programBasedTimeline.isHidden = false
            programBasedTimeline.startLoop()
        }
        
        // This is a catchup program
        else if streamingInfo.live == false && streamingInfo.staticProgram == false {
            vodBasedTimeline.isHidden = true
            vodBasedTimeline.stopLoop()
            programBasedTimeline.isHidden = false
            programBasedTimeline.startLoop()
        }
        // This is a vod asset
        else if streamingInfo.staticProgram == true {
            vodBasedTimeline.isHidden = false
            vodBasedTimeline.startLoop()
            programBasedTimeline.isHidden = true
            programBasedTimeline.stopLoop()
        }
        else {
            print("something else")
        }
    }
}


// MARK: - Actions
extension PlayerViewController {
    
    /// Play - Pause Action
    ///
    /// - Parameter sender: pausePlayButton
    @objc fileprivate func actionPausePlay(_ sender: UIButton) {
        if player.isPlaying {
            player.pause()
        }
        else {
            player.play()
        }
    }
    
    /// Change play - pause image depending on user action
    ///
    /// - Parameter paused: user paused or not
    fileprivate func togglePlayPauseButton(paused: Bool) {
        if !paused {
            pausePlayButton.setImage(UIImage(named: "pause"), for: .normal)
        }
        else {
            pausePlayButton.setImage(UIImage(named: "play"), for: .normal)
        }
    }
}

extension PlayerViewController {
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
extension PlayerViewController {
    fileprivate func setUpLayout() {
        
        view.addSubview(mainContentView)
        mainContentView.addArrangedSubview(playerView)
        
        if #available(iOS 11, *) {
            mainContentView.anchor(top: view.safeAreaLayoutGuide.topAnchor, bottom: view.safeAreaLayoutGuide.bottomAnchor, leading: view.safeAreaLayoutGuide.leadingAnchor, trailing: view.safeAreaLayoutGuide.trailingAnchor)
        } else {
            mainContentView.anchor(top: view.topAnchor, bottom: view.bottomAnchor, leading: view.leadingAnchor, trailing: view.trailingAnchor)
        }
        
        // playerView.addSubview(programBasedTimeline)
        playerView.addSubview(vodBasedTimeline)
        
//        programBasedTimeline.anchor(top: nil, bottom: playerView.bottomAnchor, leading: playerView.leadingAnchor, trailing: playerView.trailingAnchor, padding: .init(top: 0, left: 4, bottom: -10, right: -4))
        
        vodBasedTimeline.anchor(top: nil, bottom: playerView.bottomAnchor, leading: playerView.leadingAnchor, trailing: playerView.trailingAnchor, padding: .init(top: 0, left: 4, bottom: -10, right: -4))
        
        playerView.addSubview(pausePlayButton)
        
        pausePlayButton.anchor(top: nil, bottom: nil, leading: playerView.leadingAnchor, trailing: playerView.trailingAnchor)
        pausePlayButton.centerXAnchor.constraint(equalTo: playerView.centerXAnchor).isActive = true
        pausePlayButton.centerYAnchor.constraint(equalTo: playerView.centerYAnchor).isActive = true
        
//        playerView.addSubview(castImage)
//        castImage.anchor(top: nil, bottom: nil, leading: nil, trailing: nil, padding: .init(top: 10, left: 10, bottom: -10, right: -10), size: .init(width: 100, height: 100))
//        castImage.centerXAnchor.constraint(equalTo: playerView.centerXAnchor).isActive = true
//        castImage.centerYAnchor.constraint(equalTo: playerView.centerYAnchor).isActive = true
        
    }
    
    func showCastButtonInPlayer() {
        if GCKCastContext.sharedInstance().sessionManager.hasConnectedCastSession() {
            
            programBasedTimeline.isHidden = true
            vodBasedTimeline.isHidden = true
            pausePlayButton.isHidden = true
            
            
        } else {
            programBasedTimeline.isHidden = false
            vodBasedTimeline.isHidden = false
            pausePlayButton.isHidden = false
            
        }
    }
}

extension PlayerViewController {
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


// MARK: - Chrome cast
extension PlayerViewController: GCKSessionManagerListener {
    
    
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        sessionManager.remove(self)
        
        // HACK: Instruct the relevant analyticsProviders that startCasting event took place
        // TODO: We do not have nor want a strong coupling between the Cast and Player framework.
        player.tech.currentSource?.analyticsConnector.providers
            .compactMap{ $0 as? ExposureAnalytics }
            .forEach{ $0.startedCasting() }
        
        player.stop()
        
        showCastButtonInPlayer()
        
        guard let env = environment, let token = sessionToken , let playable = nowPlaying else { return }
        let currentplayheadTime = self.player.playheadTime
        self.chromecast(playable: playable, in: env, sessionToken: token, currentplayheadTime : currentplayheadTime)
        
    }
    
    
    func chromecast(playable: Playable, in environment: iOSClientExposure.Environment, sessionToken: SessionToken, localOffset: Int64? = nil, localTime: Int64? = nil, currentplayheadTime : Int64?) {
        

        guard let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession else { return }
        
        let customData = CustomData(customer: environment.customer, businessUnit: environment.businessUnit).toJson
    
        let mediaInfoBuilder = GCKMediaInformationBuilder()
        mediaInfoBuilder.contentID = playable.assetId
        mediaInfoBuilder.textTrackStyle = .createDefault()
        
        let mediaInfo = mediaInfoBuilder.build()
        
        if let remoteMediaClient = session.remoteMediaClient {
            
            let mediaQueueItemBuilder = GCKMediaQueueItemBuilder()
            mediaQueueItemBuilder.mediaInformation = mediaInfo
            let mediaQueueItem = mediaQueueItemBuilder.build()
            let queueDataBuilder = GCKMediaQueueDataBuilder(queueType: .generic)
            queueDataBuilder.items = [mediaQueueItem]
            queueDataBuilder.repeatMode = remoteMediaClient.mediaStatus?.queueRepeatMode ?? .off

            let mediaLoadRequestDataBuilder = GCKMediaLoadRequestDataBuilder()
            mediaLoadRequestDataBuilder.credentials = "\(sessionToken.value)"
            mediaLoadRequestDataBuilder.queueData = queueDataBuilder.build()
            mediaLoadRequestDataBuilder.customData = customData
            
            
//            print(" sessionToken.value \(sessionToken.value)")
//            print(" Session \(sessionToken)")
            
//            if let playheadTime = currentplayheadTime {
//                mediaLoadRequestDataBuilder.startTime = TimeInterval(playheadTime/1000)
//            }
            let _ = remoteMediaClient.loadMedia(with: mediaLoadRequestDataBuilder.build())

        }
    
    }
    
    private func localTime(playable: Playable) -> (Int64?, Int64?) {
        if playable is ChannelPlayable || playable is ProgramPlayable {
            return (nil, player.playheadTime)
        }
        else if playable is AssetPlayable {
            return (player.playheadPosition, nil)
        }
        return (nil, nil)
    }
    
    private func showChromecastButton() {
        let button = GCKUICastButton(frame: CGRect(x: CGFloat(0), y: CGFloat(0), width: CGFloat(24), height: CGFloat(24)))
        button.sizeToFit()
        button.tintColor = .white
        var navItems = navigationItem.rightBarButtonItems ?? []
        navItems.append(UIBarButtonItem(customView: button))
        navigationItem.rightBarButtonItems = navItems
    }
}


