import Foundation
import UIKit
import AsyncDisplayKit
import LiquidGlassComponent
import UIKitRuntimeUtils

private final class SwitchNodeViewLayer: CALayer {
    override func setNeedsDisplay() {
    }
}

private final class SwitchNodeView: UISwitch {
    private var liquidCaret: LiquidCaretView?
    private let normalKnobView: UIView
    private let trackView: UIView
    
    private weak var panGestureRecognizer: UIPanGestureRecognizer?
    private var touchOffset: CGFloat = 0.0
    private var hasPanned: Bool = false
    private var touchDownLocation: CGPoint?
    
    // Configuration
    private let knobSize = CGSize(width: 37.0, height: 24.0)
    
    private let switchSize = CGSize(width: 63.0, height: 28.0)
    private let padding: CGFloat = 2.0
    
    override init(frame: CGRect) {
        self.normalKnobView = UIView()
        self.trackView = UIView()
        
        super.init(frame: frame)
        
        if #unavailable(iOS 26.0) {
            // ... (keep existing setup code roughly, but context is partial replacement, so be careful)
            // Custom Track Setup
            self.onTintColor = .clear
            self.tintColor = .clear
            self.backgroundColor = .clear
            self.thumbTintColor = .clear
            
            // Allow liquid to overflow bounds (critically important for the scaling/blob effect)
            self.clipsToBounds = false
            
            // Allow frame changes
            self.translatesAutoresizingMaskIntoConstraints = true
            
            // Track View
            trackView.layer.cornerRadius = switchSize.height / 2.0
            trackView.isUserInteractionEnabled = false // Let touches pass to switch
            trackView.backgroundColor = UIColor(rgb: 0xe0e0e0) // Default off
            self.addSubview(trackView)
            
            // Normal Knob View
            normalKnobView.frame = CGRect(origin: .zero, size: knobSize)
            normalKnobView.backgroundColor = .white
            normalKnobView.layer.cornerRadius = knobSize.height / 2.0
            normalKnobView.layer.shadowColor = UIColor.black.cgColor
            normalKnobView.layer.shadowOpacity = 0.15
            normalKnobView.layer.shadowOffset = CGSize(width: 0, height: 1)
            normalKnobView.layer.shadowRadius = 1.0
            self.addSubview(normalKnobView)
            
            // Interaction Handlers
            self.addTarget(self, action: #selector(touchDown), for: .touchDown)
            self.addTarget(self, action: #selector(touchUp), for: .touchUpInside)
            self.addTarget(self, action: #selector(touchCancelled), for: [.touchUpOutside, .touchCancel])
            
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
            self.addGestureRecognizer(panGesture)
            self.panGestureRecognizer = panGesture
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure clipping is disabled even if UIKit tries to reset it
        self.clipsToBounds = false
        
        // Force internal UIKit subviews to match our custom size (hiding them effectively or putting them behind)
        // Better: Hide them.
        if #unavailable(iOS 26.0) {
            for subview in self.subviews {
                if subview !== self.trackView && subview !== self.normalKnobView && subview !== self.liquidCaret {
                    subview.isHidden = true
                    subview.frame = self.bounds // Still force frame just in case
                }
            }
            
            // Layout Track
            // Centered in bounds (effectively filling 63x28 if bounds are correct)
            let trackFrame = CGRect(
                x: (self.bounds.width - switchSize.width) / 2.0,
                y: (self.bounds.height - switchSize.height) / 2.0,
                width: switchSize.width,
                height: switchSize.height
            )
            trackView.frame = trackFrame
            trackView.layer.cornerRadius = trackFrame.height / 2.0
            
            // Update Knob Position (Static if not interacting)
            updateKnobPosition(animated: false)
        }
    }
    
    private func currentKnobFrame(isOn: Bool) -> CGRect {
        let y = (self.bounds.height - knobSize.height) / 2.0
        let x: CGFloat
        if isOn {
            x = self.bounds.width - knobSize.width - padding
        } else {
            x = padding
        }
        return CGRect(x: x, y: y, width: knobSize.width, height: knobSize.height)
    }
    
    private func updateKnobPosition(animated: Bool) {
        // Only update normal knob if we don't have an active liquid caret taking over
        if liquidCaret == nil {
            let targetFrame = currentKnobFrame(isOn: self.isOn)
            
            if animated {
                UIView.animate(withDuration: 0.25, animations: {
                    self.normalKnobView.frame = targetFrame
                })
            } else {
                self.normalKnobView.frame = targetFrame
            }
            
            // Update Track Color
            let trackColor = self.isOn ? (self.onTintColor != .clear ? self.onTintColor : UIColor(rgb: 0x42d451)) : UIColor(rgb: 0xe0e0e0)
             UIView.animate(withDuration: 0.25) {
                self.trackView.backgroundColor = trackColor
            }
        }
    }
    
    // MARK: - Interaction
    
    @objc private func touchDown(_ sender: Any, with event: UIEvent?) {
        hasPanned = false
        if let touch = event?.allTouches?.first {
            touchDownLocation = touch.location(in: self)
        }
        startInteraction()
    }
    
    @objc private func touchUp(_ sender: Any, with event: UIEvent?) {
        // Safety: If pan gesture was active, it handles the end. Do not toggle.
        if hasPanned {
            return
        }
        
        // Manual Distance Check:
        // Even if PanGesture didn't fire (e.g. short drag), if we moved > 2pt, treat as drag (Snap) not Tap (Toggle).
        if let startLoc = touchDownLocation, let touch = event?.allTouches?.first {
            let endLoc = touch.location(in: self)
            let dist = hypot(endLoc.x - startLoc.x, endLoc.y - startLoc.y)
            
            if dist > 2.0 {
                 let shouldBeOn = (liquidCaret?.center.x ?? endLoc.x) > self.bounds.width / 2.0
                 finishInteraction(isOn: shouldBeOn)
                 return
            }
        }
        
        // Real Tap
        endInteraction()
    }
    
    @objc private func touchCancelled() {
        if hasPanned { return }
        // If pan gesture is active (began/changed), it has taken over control.
        if let gesture = self.panGestureRecognizer, (gesture.state == .began || gesture.state == .changed) {
            return
        }
        finishInteraction(isOn: self.isOn)
    }
    
    @objc private func panGesture(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            hasPanned = true
            startInteraction()
            let location = gesture.location(in: self)
            // Calculate offset of touch from the current knob center
            // We revert to simple offset tracking to ensure 1:1 movement ("grabbing the knob")
            // regardless of where you touch, preventing "jump to finger" which might feel like a bug.
            let currentKnobX = liquidCaret?.center.x ?? normalKnobView.center.x
            touchOffset = location.x - currentKnobX
            
        case .changed:
            hasPanned = true // Ensure set just in case
            let location = gesture.location(in: self)
            // Apply offset to get the intended center
            let rawX = location.x - touchOffset
            
            // Clamp location to valid center X range
            let halfKnobW = knobSize.width / 2.0
            let minX = padding + halfKnobW
            let maxX = self.bounds.width - padding - halfKnobW
            let clampedX = max(minX, min(rawX, maxX))
            
            liquidCaret?.setTargetPosition(x: clampedX)
            
            // Visual Color Feedback with Hysteresis
            // Change color based on progress within the VALID TRAVEL RANGE
            let range = maxX - minX
            if range > 0 {
                let progress = (clampedX - minX) / range
                
                if progress > 0.8 {
                     // Visually ON
                    let green = (self.onTintColor != nil && self.onTintColor != .clear) ? self.onTintColor : UIColor(rgb: 0x42d451)
                    UIView.animate(withDuration: 0.25) {
                        self.trackView.backgroundColor = green
                    }
                } else if progress < 0.2 {
                    // Visually OFF
                    let gray = UIColor(rgb: 0xe0e0e0)
                    UIView.animate(withDuration: 0.25) {
                        self.trackView.backgroundColor = gray
                    }
                }
            }
            
        case .ended, .cancelled:
            let location = gesture.location(in: self)
             // Velocity check for fling
            let velocity = gesture.velocity(in: self).x
            let shouldBeOn: Bool
            
            if abs(velocity) > 500 {
                shouldBeOn = velocity > 0
            } else {
                 // Use the "Virtual" knob position (finger - offset) for state,
                 // ignoring physics lag which might report a stale center.x
                 let finalX = location.x - touchOffset
                 shouldBeOn = finalX > self.bounds.width / 2.0
            }
            
           finishInteraction(isOn: shouldBeOn)
            
        default:
            break
        }
    }
    
    private func startInteraction() {
        guard liquidCaret == nil else { return }
        
        let caret = LiquidCaretView(frame: normalKnobView.frame)
        caret.resize(width: knobSize.width, height: knobSize.height)
        
        // Physics Tuning for "Swimming" feel
        // Lower tension = more lag/delay. Adjusted friction to keep it stable.
        caret.springTension = 180.0
        caret.springFriction = 28.0
        caret.stretchSensitivity = 0.2
        
        // Custom Configuration for Switch
        caret.configuration = LiquidASSView.Configuration(
            cornerRadius: knobSize.height / 2.0,
            blurIntensity: 0.5,
            lensDistortionStrength: 0.06,
            tintColor: nil,
            saturation: nil,
            brightness: nil,
            cornerSegments: 18,
            contentScale: UIScreen.main.scale,
            visualZoom: 0.75,
            bleedAmount: 10.0,
            showBorder: false,
            distortionPadding: 2.2,
            distortionMultiplier: 4.5,
            distortionExponent: 3.0
        )
        
        caret.isUserInteractionEnabled = false // Let touches pass to parent
        
        // Shadow (matching SliderComponent)
        caret.layer.shadowColor = UIColor.black.cgColor
        caret.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        caret.layer.shadowRadius = 8.0
        caret.layer.shadowOpacity = 0.2
        caret.layer.masksToBounds = false
        caret.clipsToBounds = false
        caret.backgroundColor = .clear
        
        self.addSubview(caret)
        self.liquidCaret = caret
        
        // Hide normal knob
        normalKnobView.isHidden = true
        
        // Start Dragging (enables physics loop)
        caret.startDragging(at: normalKnobView.center.x)
        
        // Expand Animation (Pop)
        // Scale from knobSize to expandedSize
        let scaleX = 1.5
        let scaleY = 1.5
        
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, options: [.beginFromCurrentState], animations: {
            caret.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        }, completion: nil)
    }
    
    private func endInteraction() {
        // If pan gesture handles end, it calls finishInteraction directly.
        // This is for tap. Toggle state.
        finishInteraction(isOn: !self.isOn)
    }
    
    private func finishInteraction(isOn: Bool) {
        guard let caret = liquidCaret else { return }
        
        self.setOn(isOn, animated: true) // Updates isOn state and triggers valueChanged event eventually
        self.sendActions(for: .valueChanged)
       
        let targetFrame = currentKnobFrame(isOn: isOn)
        
        // Update track color
         let trackColor = isOn ? UIColor(rgb: 0x42d451) : UIColor(rgb: 0xe0e0e0)
         UIView.animate(withDuration: 0.25) {
            self.trackView.backgroundColor = trackColor
        }
        
        // Animate Dismissal of Liquid Caret
        // If we are traveling a significant distance (toggle), use the custom "Fly" animation (stay big -> shrink at end)
        // If we are just snapping nearby (dragged to end), use standard dismissal.
        let dist = abs(caret.center.x - targetFrame.midX)
        let isToggle = dist > 15.0
        
        // Show normal knob starting at current caret position to avoid "ghost at destination"
        self.bringSubviewToFront(self.normalKnobView)
        self.normalKnobView.center = caret.center
        self.normalKnobView.isHidden = false
        self.normalKnobView.alpha = 0.0
        
        let fadeDelay = isToggle ? (0.35 * 0.8) : 0.0
        let animationDuration = isToggle ? 0.35 : 0.25
        
        // 1. Animate Position immediately to follow the liquid blob
        UIView.animate(withDuration: animationDuration, delay: 0.0, options: [.curveEaseOut], animations: {
            self.normalKnobView.frame = targetFrame
        }, completion: nil)
        
        // 2. Animate Alpha with delay (appear only when shrinking starts)
        UIView.animate(withDuration: 0.25, delay: fadeDelay, options: [.curveEaseOut], animations: {
            self.normalKnobView.alpha = 1.0
        }, completion: nil)
        
        if isToggle {
            caret.animateToggle(to: targetFrame) { [weak self] in
                self?.liquidCaret = nil
            }
        } else {
            caret.animateDismissal(to: targetFrame) { [weak self] in
                self?.liquidCaret = nil
            }
        }
    }
    
    override func setOn(_ on: Bool, animated: Bool) {
        super.setOn(on, animated: animated)
        // If setOn called programmatically, update normal knob position if verified not interacting
        if liquidCaret == nil {
            updateKnobPosition(animated: animated)
        }
    }
    
    override class var layerClass: AnyClass {
        if #available(iOS 26.0, *) {
            return super.layerClass
        } else {
            return SwitchNodeViewLayer.self
        }
    }
    
    override var intrinsicContentSize: CGSize {
        if #available(iOS 26.0, *) {
            return super.intrinsicContentSize
        } else {
            return CGSize(width: 63.0, height: 28.0)
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if #available(iOS 26.0, *) {
            return super.sizeThatFits(size)
        } else {
            return CGSize(width: 63.0, height: 28.0)
        }
    }
}


open class SwitchNode: ASDisplayNode {
    public var valueUpdated: ((Bool) -> Void)?
    
    public var frameColor = UIColor(rgb: 0xe0e0e0) {
        didSet {
            if self.isNodeLoaded {
                if oldValue != self.frameColor {
                    (self.view as! UISwitch).tintColor = self.frameColor
                }
            }
        }
    }
    public var handleColor = UIColor(rgb: 0xffffff) {
        didSet {
            if self.isNodeLoaded {
                //(self.view as! UISwitch).thumbTintColor = self.handleColor
            }
        }
    }
    public var contentColor = UIColor(rgb: 0x42d451) {
        didSet {
            if self.isNodeLoaded {
                if oldValue != self.contentColor {
                    (self.view as! UISwitch).onTintColor = self.contentColor
                }
            }
        }
    }
    
    private var _isOn: Bool = false
    public var isOn: Bool {
        get {
            return self._isOn
        } set(value) {
            if (value != self._isOn) {
                self._isOn = value
                if self.isNodeLoaded {
                    (self.view as! UISwitch).setOn(value, animated: false)
                }
            }
        }
    }
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            return SwitchNodeView(frame: .zero)
        })
    }
    
    override open func didLoad() {
        super.didLoad()
        
        self.view.isAccessibilityElement = false
        
        (self.view as! UISwitch).backgroundColor = self.backgroundColor
        (self.view as! UISwitch).tintColor = self.frameColor
        (self.view as! UISwitch).onTintColor = self.contentColor
        
        (self.view as! UISwitch).setOn(self._isOn, animated: false)
        
        (self.view as! UISwitch).addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
    }
    
    public func setOn(_ value: Bool, animated: Bool) {
        self._isOn = value
        if self.isNodeLoaded {
            (self.view as! UISwitch).setOn(value, animated: animated)
        }
    }
    
    override open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        if #available(iOS 26.0, *) {
            return CGSize(width: 63.0, height: 28.0)
        } else {
            // User requested 63x28
            return CGSize(width: 63.0, height: 28.0)
        }
    }
    
    @objc func switchValueChanged(_ view: UISwitch) {
        self._isOn = view.isOn
        self.valueUpdated?(view.isOn)
    }
}

