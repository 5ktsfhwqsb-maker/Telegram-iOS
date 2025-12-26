import UIKit
import UIKitRuntimeUtils

@objc(LiquidCaretView) public final class LiquidCaretView: UIView {
    private let liquidView: LiquidASSView
    private var displayLink: CADisplayLink?
    
    // Physics State
    private var positionX: CGFloat = 0.0
    private var velocityX: CGFloat = 0.0
    private var targetPositionX: CGFloat = 0.0
    
    // Configuration
    public var springTension: CGFloat = 300.0
    public var springFriction: CGFloat = 25.0
    private let maxStretch: CGFloat = 5.0
    public var stretchSensitivity: CGFloat = 0.05
    
    // Interaction State
    public var isDragging: Bool = false
    
    // Customization
    public var configuration: LiquidASSView.Configuration = LiquidASSView.Configuration(cornerRadius: 0) {
        didSet { updateConfiguration() }
    }
    
    public override init(frame: CGRect) {
        self.liquidView = LiquidASSView(frame: .zero)
        
        super.init(frame: frame)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    private func setup() {
        self.configuration = LiquidASSView.Configuration(
            cornerRadius: self.bounds.height / 2.0,
            blurIntensity: 0.0,
            lensDistortionStrength: 0.05,
            tintColor: nil,
            saturation: nil,
            brightness: nil,
            cornerSegments: 18,
            contentScale: UIScreen.main.scale,
            visualZoom: 1.0,
            bleedAmount: 10.0,
            showBorder: false // Disable border for caret
        )
        liquidView.apply(configuration: self.configuration)
        liquidView.frame = bounds
        liquidView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Ensure transparent background for glass effect
        liquidView.backgroundColor = .clear 
        
        addSubview(liquidView)
        
        let displayLink = CADisplayLink(target: NetworkLinkTarget(self), selector: #selector(displayLinkUpdate))
        displayLink.add(to: .main, forMode: .common)
        displayLink.isPaused = true
        self.displayLink = displayLink
        displayLink.isPaused = true
        self.displayLink = displayLink
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure shadow path is set so shadow is visible even with clear background
        // This places the shadow behind the liquid content, visible through the glass
        if self.bounds.height > 0 {
            self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.bounds.height / 2.0).cgPath
        }
    }
    
    @objc public func configureForPhotoEditor() {
        self.configuration = LiquidASSView.Configuration(
             cornerRadius: self.bounds.height / 2.0,
             blurIntensity: 0,
             lensDistortionStrength: 0.06,
             tintColor: nil,
             saturation: nil,
             brightness: nil,
             cornerSegments: 18,
             contentScale: UIScreen.main.scale,
             visualZoom: 1.0,
             bleedAmount: 3.0,
             showBorder: false // Disable border for caret
         )
         self.springTension = 300.0
         self.springFriction = 28.0
         self.stretchSensitivity = 0.2
    }
    
    @objc public func setTargetPosition(x: CGFloat) {
        targetPositionX = x
        if let displayLink = self.displayLink, displayLink.isPaused {
            if !isDragging {
                // If not dragging (snap animation), we might want to let CoreAnimation handle it
                // BUT if we want "liquid" deformation, we need the loop.
                // For now, let's enable loop always when target changes for physics.
            }
            displayLink.isPaused = false
        }
    }
    
    @objc public func startDragging(at x: CGFloat) {
        isDragging = true
        positionX = x
        targetPositionX = x
        velocityX = 0
        displayLink?.isPaused = false
        
        // Appear immediately
        self.alpha = 1.0
        self.transform = .identity
    }
    
    @objc public func resize(width: CGFloat, height: CGFloat) {
        let oldCenter = self.center
        self.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        self.center = oldCenter
        
        // Update ONLY corner radius for the existing configuration
        let base = self.configuration
        let config = LiquidASSView.Configuration(
            cornerRadius: height / 2.0,
            blurIntensity: base.blurIntensity,
            lensDistortionStrength: base.lensDistortionStrength,
            tintColor: base.tintColor,
            saturation: base.saturation,
            brightness: base.brightness,
            cornerSegments: 18,
            contentScale: UIScreen.main.scale,
            visualZoom: base.visualZoom,
            bleedAmount: base.bleedAmount,
            showBorder: false // Maintain border state (or ensure false)
        )
        self.configuration = config
        liquidView.apply(configuration: config)
    }
    
    @objc public func animateDismissal(to targetFrame: CGRect, completion: @escaping () -> Void) {
        isDragging = false
        displayLink?.isPaused = true
        
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseOut, .beginFromCurrentState], animations: {
            // Animate position to target center
            self.center = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
            
            // Animate scale to target size
            // This avoids layout issues and provides the "shrink" effect user requested
            let currentSize = self.bounds.size
            if currentSize.width > 0 && currentSize.height > 0 {
                let scaleX = targetFrame.width / currentSize.width
                let scaleY = targetFrame.height / currentSize.height
                self.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            }
            
            // Reset internal liquid distortion
            self.liquidView.transform = .identity
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
    
    @objc public func animateToggle(to targetFrame: CGRect, shrinkStart: (() -> Void)? = nil, completion: @escaping () -> Void) {
        isDragging = false
        displayLink?.isPaused = true
        
        let duration: TimeInterval = 0.55
        
        // 1. Position Animation (Smooth ease-out drift)
        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseOut], animations: {
            self.center = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
            // Reset internal distortion
            self.liquidView.transform = .identity
        }, completion: nil)
        
        // Fire shrink callback at 80% (when shrink starts)
        let shrinkDelay = duration * 0.8
        if let shrinkStart = shrinkStart {
            DispatchQueue.main.asyncAfter(deadline: .now() + shrinkDelay) {
                shrinkStart()
            }
        }
        
        // 2. Scale Animation (Custom profile: Max at 20%, Shrink start at 80%)
        UIView.animateKeyframes(withDuration: duration, delay: 0.0, options: [], animations: {
            let currentSize = self.bounds.size
            let targetScaleX = (currentSize.width > 0) ? targetFrame.width / currentSize.width : 1.0
            let targetScaleY = (currentSize.height > 0) ? targetFrame.height / currentSize.height : 1.0
            
            // Phase 1: Expand/Hold at 1.5x (0% -> 20%)
            // We use relativeStartTime: 0.0, relativeDuration: 0.2
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            }
            
            // Phase 2: Hold (20% -> 80%)
            // relativeStartTime: 0.2, relativeDuration: 0.6
            UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.6) {
                self.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            }
            
            // Phase 3: Shrink to Target AND Fade Out (80% -> 100%)
            // relativeStartTime: 0.8, relativeDuration: 0.2
            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: targetScaleX, y: targetScaleY)
                self.alpha = 0.0
            }
            
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
    
    @objc public func updateTheme(color: UIColor) {
        self.liquidView.backgroundColor = color
    }
    
    private func updateConfiguration() {
        guard self.liquidView.superview != nil else { return }
        liquidView.apply(configuration: self.configuration)
    }
    
    @objc func displayLinkUpdate() {
        let dt: CGFloat = 1.0 / 60.0 // Simplified fixed timestep for stability
        
        // 1. Spring Physics for Position
        let displacement = positionX - targetPositionX
        let force = -springTension * displacement - springFriction * velocityX
        
        velocityX += force * dt
        positionX += velocityX * dt
        
        // 2. Deformation Physics (based on velocity)
        // Stretch width based on speed, compress height slightly to preserve volume concept
        let speed = abs(velocityX)
        let stretchFactor = min(speed * stretchSensitivity, maxStretch)
        
        // Visual Update
        // We move the CENTER of the view.
        
        // Enforce rigid clamping on the final position as well to prevent visual overshoot
        if let superview = self.superview {
            // Clamp based on visual edges (-20 ... width + 20)
            let clampLimit: CGFloat = 20.0
            let halfWidth = self.bounds.width / 2.0
            
            let minCenter = -clampLimit + halfWidth
            let maxCenter = superview.bounds.width + clampLimit - halfWidth
            
            if positionX < minCenter {
                positionX = minCenter
                velocityX = 0 
            } else if positionX > maxCenter {
                positionX = maxCenter
                velocityX = 0
            }
        }
        
        self.center = CGPoint(x: positionX, y: self.center.y)
        
        // Apply stretch to the INTERNAL liquid view
        let widthScale = 1.0 + (stretchFactor / 50.0) // Normalize by approx width
        let heightScale = 1.0 - (stretchFactor / 50.0) * 0.5 
        
        let transform = CGAffineTransform(scaleX: widthScale, y: heightScale)
        liquidView.transform = transform
        
        // Check for rest state
        if !isDragging && abs(displacement) < 0.1 && abs(velocityX) < 0.1 && self.alpha < 0.01 {
           // displayLink.isPaused = true // Paused by stopDragging transaction
        }
    }
}

// Helper for DisplayLink target to avoid retain cycle
private class NetworkLinkTarget {
    private weak var target: LiquidCaretView?
    
    init(_ target: LiquidCaretView) {
        self.target = target
    }
    
    @objc func displayLinkUpdate() {
        target?.perform(#selector(LiquidCaretView.displayLinkUpdate))
    }
}
