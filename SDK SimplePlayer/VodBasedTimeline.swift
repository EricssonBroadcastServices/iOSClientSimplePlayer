//
//  VodBasedTimeline.swift
//  SDK SimplePlayer
//
//  Created by Udaya Sri Senarathne on 2022-07-04.
//

import Foundation
import UIKit
import AVFoundation
import iOSClientExposure


class VodBasedTimeline: UIView {
    

    // Pass current time to the player, used in checking push next content
    var onCurrentTime: (Int64) -> Void = { _ in }
    
    // Main content view which holds the blur view
    let contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    // Blur View which holds all the elements
    //    let blurView: UIView = {
    //        let view = UIView()
    //        view.backgroundColor = UIColor.black
    //        view.layer.opacity = 0.5
    //        view.layer.borderColor = PlayerColors.active.textFieldPlaceholder.cgColor
    //        view.layer.cornerRadius = 5
    //        view.layer.borderWidth = 0.2
    //        return view
    //    }()
    
    let blurView: UIStackView = {
        let stackview = UIStackView()
        stackview.distribution = .fillProportionally
        stackview.axis = .horizontal
        return stackview
    }()
    
    // Three container stack views to hold content
    let leftContainerView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.axis = .horizontal
        stackView.alignment = .center
        return stackView
    }()
    
    let middleContainerView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fillProportionally
        stackView.axis = .horizontal
        stackView.alignment = .center
        return stackView
    }()
    
    let rightContainerView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.axis = .horizontal
        return stackView
    }()
    
    // Views related to left
    let leftTimeLabel: UILabel = {
        let label = UILabel()
        label.text = " "
        label.font = label.font.withSize(11)
        label.textColor = .gray
        return label
    }()
    
    // Views related to middle
    let playheadSlider: CustomSlider = {
        let slider = CustomSlider()
        slider.minimumTrackTintColor = .red
        slider.maximumTrackTintColor = .white
        slider.addTarget(self, action: #selector(seekAction(_:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(seekAction(_:)), for: .touchUpOutside)
        slider.addTarget(self, action: #selector(playheadSliderAction(_:event:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderDidEndSliding), for: [.touchUpInside, .touchUpOutside])
        //slider.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        return slider
    }()
    
    // Views related to right side
    let rightTimeLabel: UILabel = {
        let label = UILabel()
        label.text = " "
        label.font = label.font.withSize(11)
        label.textColor = .gray
        return label
    }()
    
    
    
    var spriteImageView: UIImageView = {
        let uiImageView = UIImageView()
        uiImageView.contentMode = .scaleAspectFill
        uiImageView.translatesAutoresizingMaskIntoConstraints = false
        return uiImageView
    }()
    
    private var spriteViewCenterXConstraint: NSLayoutConstraint!
    private var spriteViewCenterXConstraintConstant: Float = 0
    

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupLayout()

        // setup slider thumb
        //        let sliderThumbImage = UIImage(named: "sliderThumb")
        //        playheadSlider.setThumbImage(sliderThumbImage?.imageWithColor(color1: PlayerColors.active.accent), for: .normal)
        //        playheadSlider.setThumbImage(sliderThumbImage?.imageWithColor(color1: PlayerColors.active.accent), for: .highlighted)
        
        let sliderThumbImage = UIImage(named: "sliderThumb")
        playheadSlider.minimumTrackTintColor = .red
        playheadSlider.maximumTrackTintColor = .gray
        playheadSlider.setThumbImage(sliderThumbImage?.imageWithColor(color1: .red), for: .normal)
        playheadSlider.setThumbImage(sliderThumbImage?.imageWithColor(color1: .red), for: .highlighted)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.adDuration = 0
        stopLoop()
    }
    
    fileprivate var isSliding: Bool = false
    fileprivate var lastPlayheadSliderValue: Float?
    
    fileprivate var timerQueue = DispatchQueue(label: "com.emp.whitelabel.vodBasedTimeLine",
                                               qos: DispatchQoS.background,
                                               attributes: DispatchQueue.Attributes.concurrent)
    
    fileprivate var timer: DispatchSourceTimer?
    
    
    /// MARK: Configuration
    var currentPlayheadPosition: () -> Int64? = { return nil }
    var currentDuration: () -> Int64? = { return nil }
    var vodContentDuration: () -> Int64? = { return nil }
    
    var canFastForward: Bool = true {
        didSet {
            // Update UI restrictions
            if !canFastForward && !canRewind {
                playheadSlider.isUserInteractionEnabled = false
            }
            else {
                playheadSlider.isUserInteractionEnabled = true
            }
        }
    }
    var canRewind: Bool = true {
        didSet {
            // Update UI restrictions
            if !canFastForward && !canRewind {
                playheadSlider.isUserInteractionEnabled = false
            }
            else {
                playheadSlider.isUserInteractionEnabled = true
            }
        }
    }
    
    var adDuration: Int64 = 0
    var adMarkers = [MarkerPoint]()
    var isAdPlaying: Bool = false
    
    var startOverTrigger: () -> Void = { }
    var onSeek: (Int64) -> Void = { _ in }
    var onPlayheadStartAction:(Bool) ->Void = { _ in }
    var onScrubbing: (String) -> Void = { _ in }
}

// MARK: - Timeline Updates
extension VodBasedTimeline {
    
    @objc func startOverAction() {
        startOverTrigger()
    }
    
    public func startLoop() {
        
        if let duration = currentDuration() {
            playheadSlider.maximumValue = Float(duration)
            playheadSlider.minimumValue = 0
        }

        timer = DispatchSource.makeTimerSource(queue: self.timerQueue)
        timer?.schedule(wallDeadline: .now(), repeating: .milliseconds(1000))
        timer?.setEventHandler { [weak self] in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                self.updateLoop()

            }
        }
        timer?.resume()
    }
    
    public func stopLoop() {
        timer?.setEventHandler{}
        timer?.cancel()
    }
    
    public func resumeTimer() {
        isAdPlaying = false
    }
    
    func pausedTimer() {

        isAdPlaying = true
    }
    
    
    fileprivate func updateLoop() {

              let playHeadPosition = currentPlayheadPosition()
              let duration = currentDuration()
              
              if let playhead = playHeadPosition, let duration = duration, duration > 0 {
                  isHidden = false
                  playheadSlider.isHidden = false
                  
                  // Chek if there are any Ad Breaks before the playhead position
                  var updatePlayhead = playhead
                  for marker in adMarkers {
                      
                      if let endOffset = marker.endOffset , let offset = marker.offset {
                          let adDuration = endOffset - offset
                          if endOffset <= playhead {
                              updatePlayhead = updatePlayhead - Int64(adDuration)
                          }
                      }
                  }
                  
                  if !isAdPlaying {
                      updateTimelabels(playhead: updatePlayhead, duration: duration)
                      self.onCurrentTime(playhead)
                  }
                  
                  updatePlayheadSlider(playhead: playhead, duration: duration)
                  
              }
              else {
                  isHidden = true
              }
    }
    
    fileprivate func updateTimelabels(playhead: Int64, duration: Int64) {
        
        if let vodDuration = vodContentDuration() {
                    rightTimeLabel.text = timeFormat(time: vodDuration )
        } else {
            rightTimeLabel.text = timeFormat(time: duration)
        }
        
        guard !isSliding else { return }
        leftTimeLabel.text = timeFormat(time: playhead)
    }
    
    fileprivate func updatePlayheadSlider(playhead: Int64, duration: Int64) {
        guard !isSliding else { return }
        
       
        if playhead <= duration {
            
            let progress = Float(playhead) / Float(duration)
            lastPlayheadSliderValue = progress
            playheadSlider.setValue(progress, animated: false)
        
        }
        else {
            lastPlayheadSliderValue = 1
            playheadSlider.setValue(1, animated: false)
        }
    }
    
    
    /// Playhead slider is in action
    ///
    /// - Parameters:
    ///   - sender: UISlider
    ///   - event: UIEvent
    @objc func playheadSliderAction(_ sender: UISlider, event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .began:
                isSliding = true
                onPlayheadStartAction(true)
                spriteViewCenterXConstraintConstant = Float(spriteViewCenterXConstraint.constant)
            case .moved:
                if let previousValue = lastPlayheadSliderValue {
                    if sender.value > previousValue && !canFastForward {
                        sender.value = previousValue
                        return
                    }
                    
                    if sender.value < previousValue && !canRewind {
                        sender.value = previousValue
                        return
                    }
                    
                    if let duration = currentDuration() {
                        let sliderPosition = Int64(sender.value * Float(duration))
                        
                        
                        leftTimeLabel.text = timeFormat(time: sliderPosition - adDuration )
                        
                        let currentTime = timeFormat(time: sliderPosition)
                        
                        let trackRect = playheadSlider.trackRect(forBounds: playheadSlider.bounds)
                        let thumbRect = playheadSlider.thumbRect(forBounds: playheadSlider.bounds, trackRect: trackRect, value: playheadSlider.value)

                        spriteViewCenterXConstraint.constant = (thumbRect.maxX + thumbRect.minX)/2
                        
                        onScrubbing(currentTime)
                    }
                }
            case .ended:
                isSliding = false
                onPlayheadStartAction(false)
                spriteViewCenterXConstraintConstant = Float(spriteViewCenterXConstraint.constant)
                spriteImageView.image = nil
            default:
                break
            }
        }
        
    }
    
    @objc func seekAction(_ sender: UISlider) {
        isSliding = false
        guard let duration = currentDuration() else { return }
        let rawOffset = Int64(sender.value * Float(duration))
        let seekOffset = min(duration - 1000, rawOffset)
        onSeek(seekOffset)
    }
    
    @objc func sliderDidEndSliding(_ sender: UISlider) {
        isSliding = false
        onPlayheadStartAction(false)
        spriteViewCenterXConstraintConstant = Float(spriteViewCenterXConstraint.constant)
        spriteImageView.image = nil
    }
}


// MARK: - Layout
extension VodBasedTimeline {
    
    fileprivate func setupLayout() {
        addSubview(contentView)
        addSubview(blurView)
        
        addSubview(leftContainerView)
        leftContainerView.addArrangedSubview(leftTimeLabel)
        
        addSubview(middleContainerView)
        middleContainerView.addArrangedSubview(playheadSlider)
        
        addSubview(rightContainerView)
        rightContainerView.addArrangedSubview(rightTimeLabel)
        // rightContainerView.addArrangedSubview(startOverButton)
        
        contentView.addSubview(spriteImageView)
        
        // Main View
        contentView.anchor(top: self.topAnchor, bottom: self.bottomAnchor, leading: self.leadingAnchor, trailing: self.trailingAnchor)
        
        blurView.anchor(top: contentView.topAnchor, bottom: contentView.bottomAnchor, leading: contentView.leadingAnchor, trailing: contentView.trailingAnchor)
        
        // Left ContainerView
        leftContainerView.anchor(top: blurView.topAnchor, bottom: blurView.bottomAnchor, leading: blurView.leadingAnchor, trailing: nil)
        
        // Middle container
        middleContainerView.anchor(top: blurView.topAnchor, bottom: blurView.bottomAnchor, leading: leftContainerView.trailingAnchor, trailing: rightContainerView.leadingAnchor, padding: .init(top: 0, left: 2, bottom: 0, right: -3))
        
        //middleContainerView.widthAnchor.constraint(equalTo: blurView.widthAnchor, multiplier: 6/10).isActive = true
        middleContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        
        // playheadSlider.widthAnchor.constraint(equalTo: middleContainerView.widthAnchor).isActive = true
        
        playheadSlider.heightAnchor.constraint(equalToConstant: 8).isActive = true
        
        leftContainerView.widthAnchor.constraint(equalTo: blurView.widthAnchor, multiplier: 1/10).isActive = true
        rightContainerView.widthAnchor.constraint(equalTo: blurView.widthAnchor, multiplier: 1/10).isActive = true
        middleContainerView.widthAnchor.constraint(equalTo: blurView.widthAnchor, multiplier: 8/10).isActive = true
        
        // Right Container
        rightContainerView.anchor(top: blurView.topAnchor, bottom: blurView.bottomAnchor, leading: nil, trailing: contentView.trailingAnchor, padding: .init(top: 0, left:0, bottom: 0, right: 0))
        
        /* startOverButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
         startOverButton.heightAnchor.constraint(equalToConstant: 18).isActive = true  */
        
        spriteImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -80).isActive = true
        spriteViewCenterXConstraint = spriteImageView.centerXAnchor.constraint(equalTo: playheadSlider.leadingAnchor, constant: CGFloat(0))
        spriteViewCenterXConstraint.isActive = true
        
    }
    
    
    /// Show ad markers to the timeline
    /// - Parameters:
    ///   - adMarkers: adMarkers
    ///   - totalDuration: total duration including ads
    func showAdTickMarks(adMarkers: [MarkerPoint] , totalDuration:Int64, vodDuration: Int64 ) {
        
        // Remove any previously added subViews with tag `101`
        self.playheadSlider.subviews.filter({$0.tag == 101 }).forEach({$0.removeFromSuperview()})
        
        // playheadSlider.minimumValue = 0

        for (index,adMarker) in adMarkers.enumerated() {
                    
            if (adMarker.type == "Ad" ) {
                
                let sieForMilisecond = playheadSlider.bounds.width / CGFloat(totalDuration)
                
                if let offset = adMarker.offset {
                    if offset == 0 {
                        
                        if let endOffset = adMarker.endOffset {
                            let adMarkerLength = endOffset - offset
                            
                            let width = sieForMilisecond * CGFloat(adMarkerLength)
                            
                            let tick = UIView(frame: CGRect(x: 0 , y: 0, width: width, height: self.playheadSlider.trackRect(forBounds: playheadSlider.bounds).height))
                            tick.tag = 101
                            tick.backgroundColor = UIColor.yellow
                            self.playheadSlider.insertSubview(tick, belowSubview: self.playheadSlider)
                        }
                        
                        
                        
                    } else {
                        // if offset < vodDuration {
                            // let sieForMilisecond = playheadSlider.bounds.width / CGFloat(totalDuration)
                            let adMarkerStartingTimeinSeconds =  CGFloat(offset)
                        
                            let end = adMarker.endOffset ?? Int(totalDuration)
                        
                            let adMarkerLength = end - offset
                        
                            let width = sieForMilisecond * CGFloat(adMarkerLength)
                            
                            let adMarkerPostion = adMarkerStartingTimeinSeconds * sieForMilisecond
                            
                            // let tickHeight = playheadSlider.trackRect(forBounds: playheadSlider.bounds).height
                            let tick = UIView(frame: CGRect(x: adMarkerPostion , y: self.playheadSlider.trackRect(forBounds: playheadSlider.bounds).minY, width: width, height: self.playheadSlider.trackRect(forBounds: playheadSlider.bounds).height))
                            tick.tag = 101
                            tick.backgroundColor = .yellow
                            
                            if index == 0 {
                                self.playheadSlider.insertSubview(tick, belowSubview: self.playheadSlider)
                            } else {
                                let previousClip = adMarkers[index - 1]
                                if previousClip.endOffset != adMarker.offset {
                                    self.playheadSlider.insertSubview(tick, belowSubview: self.playheadSlider)
                                }
                            }
                        // }
                    }
                }
                
                // Check if we have post roll ads, if so Ad the marker to the end of the timeline.
//                if let endoffset = adMarker.endOffset {
//                   if(endoffset >= vodDuration) {
//
//                       let tick = UIView(frame: CGRect( x: (playheadSlider.layer.frame.size.width - 5 ) , y: 0, width: 5, height: 25))
//                        tick.tag = 101
//                        tick.backgroundColor = UIColor.green
//                        self.playheadSlider.insertSubview(tick, belowSubview: self.playheadSlider)
//                    }
//                }
            }
        }
    }
}

extension VodBasedTimeline {
    fileprivate func timeFormat(time: Int64) -> String {
        return time.timeFormat()
    }
}


extension UIImage {
    func imageWithColor(color1: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        color1.setFill()
        
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.setBlendMode(CGBlendMode.normal)
        
        let rect = CGRect(origin: .zero, size: CGSize(width: self.size.width, height: self.size.height))
        context?.clip(to: rect, mask: self.cgImage!)
        context?.fill(rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}


class CustomSlider: UISlider {
  
  //To set line height value from IB, set any value here
  @IBInspectable var trackLineHeight: CGFloat = 3
  
  //To set custom size of track so here override trackRect function of slider control
  override func trackRect(forBounds bound: CGRect) -> CGRect {
    return CGRect(origin: bound.origin, size: CGSize(width: bound.width, height: trackLineHeight))
  }
}
