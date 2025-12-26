import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import LegacyComponents
import ComponentFlow

import LiquidGlassComponent

public final class SliderComponent: Component {
    public final class Discrete: Equatable {
        public let valueCount: Int
        public let value: Int
        public let minValue: Int?
        public let markPositions: Bool
        public let valueUpdated: (Int) -> Void
        
        public init(valueCount: Int, value: Int, minValue: Int? = nil, markPositions: Bool, valueUpdated: @escaping (Int) -> Void) {
            self.valueCount = valueCount
            self.value = value
            self.minValue = minValue
            self.markPositions = markPositions
            self.valueUpdated = valueUpdated
        }
        
        public static func ==(lhs: Discrete, rhs: Discrete) -> Bool {
            if lhs.valueCount != rhs.valueCount {
                return false
            }
            if lhs.value != rhs.value {
                return false
            }
            if lhs.minValue != rhs.minValue {
                return false
            }
            if lhs.markPositions != rhs.markPositions {
                return false
            }
            return true
        }
    }
    
    public final class Continuous: Equatable {
        public let value: CGFloat
        public let minValue: CGFloat?
        public let valueUpdated: (CGFloat) -> Void
        
        public init(value: CGFloat, minValue: CGFloat? = nil, valueUpdated: @escaping (CGFloat) -> Void) {
            self.value = value
            self.minValue = minValue
            self.valueUpdated = valueUpdated
        }
        
        public static func ==(lhs: Continuous, rhs: Continuous) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            if lhs.minValue != rhs.minValue {
                return false
            }
            return true
        }
    }
    
    public enum Content: Equatable {
        case discrete(Discrete)
        case continuous(Continuous)
    }
    
    public let content: Content
    public let useNative: Bool
    public let trackBackgroundColor: UIColor
    public let trackForegroundColor: UIColor
    public let minTrackForegroundColor: UIColor?
    public let knobSize: CGFloat?
    public let knobColor: UIColor?
    public let isTrackingUpdated: ((Bool) -> Void)?
    
    public init(
        content: Content,
        useNative: Bool = false,
        trackBackgroundColor: UIColor,
        trackForegroundColor: UIColor,
        minTrackForegroundColor: UIColor? = nil,
        knobSize: CGFloat? = nil,
        knobColor: UIColor? = nil,
        isTrackingUpdated: ((Bool) -> Void)? = nil
    ) {
        self.content = content
        self.useNative = useNative
        self.trackBackgroundColor = trackBackgroundColor
        self.trackForegroundColor = trackForegroundColor
        self.minTrackForegroundColor = minTrackForegroundColor
        self.knobSize = knobSize
        self.knobColor = knobColor
        self.isTrackingUpdated = isTrackingUpdated
    }
    
    public static func ==(lhs: SliderComponent, rhs: SliderComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.trackBackgroundColor != rhs.trackBackgroundColor {
            return false
        }
        if lhs.trackForegroundColor != rhs.trackForegroundColor {
            return false
        }
        if lhs.minTrackForegroundColor != rhs.minTrackForegroundColor {
            return false
        }
        if lhs.knobSize != rhs.knobSize {
            return false
        }
        if lhs.knobColor != rhs.knobColor {
            return false
        }
        return true
    }
    
    final class SliderView: UISlider {
        
    }
    
    private final class CustomSliderView: UIView {
        private let trackBackgroundLayer = CAShapeLayer()
        private let trackForegroundLayer = CAShapeLayer()
        private let knobView = UIImageView()
        private let liquidCaretView: LiquidCaretView
        
        private var component: SliderComponent?
        private var value: CGFloat = 0.0
        
        var valueChanged: ((CGFloat) -> Void)?
        var interactionBegan: (() -> Void)?
        var interactionEnded: (() -> Void)?
        
        override init(frame: CGRect) {
            self.liquidCaretView = LiquidCaretView(frame: CGRect(origin: .zero, size: CGSize(width: 37.0, height: 24.0)))
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.trackBackgroundLayer)
            self.layer.addSublayer(self.trackForegroundLayer)
            self.addSubview(self.knobView)
            self.addSubview(self.liquidCaretView)
            
            self.trackBackgroundLayer.lineCap = .round
            self.trackForegroundLayer.lineCap = .round
            
            self.liquidCaretView.isHidden = true
            self.liquidCaretView.isUserInteractionEnabled = false
            
            // Apply consistent shadow to liquid view
            self.liquidCaretView.layer.shadowColor = UIColor.black.cgColor
            self.liquidCaretView.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
            self.liquidCaretView.layer.shadowRadius = 8.0
            self.liquidCaretView.layer.shadowOpacity = 0.12
            // Ensure no clipping so shadow is visible
            self.liquidCaretView.clipsToBounds = false
            self.liquidCaretView.configuration = LiquidASSView.Configuration(
                cornerRadius: 12,
                blurIntensity: 0,
                lensDistortionStrength: 0.05,
                cornerSegments: 18,
                distortionPadding: 2.2,
                distortionMultiplier: 4.5,
                distortionExponent: 5.0
            )
            // Apply consistent shadow to static knob view (layer-based to avoid clipping in image context)
            self.knobView.layer.shadowColor = UIColor.black.cgColor
            self.knobView.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
            self.knobView.layer.shadowRadius = 8.0
            self.knobView.layer.shadowOpacity = 0.12
            self.knobView.clipsToBounds = false
            
            self.clipsToBounds = false
            
            self.configureForPhotoEditor()
            
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            self.addGestureRecognizer(panGesture)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func configureForPhotoEditor() {
            // Configuration matching LiquidCaretView.configureForPhotoEditor() in Swift
        }
        
        func update(component: SliderComponent, availableSize: CGSize) {
            self.component = component
            
            let trackHeight: CGFloat = 6.0 // User requested thickened line
            let knobSize = CGSize(width: 37.0, height: 24.0)
            
            self.trackBackgroundLayer.strokeColor = component.trackBackgroundColor.cgColor
            self.trackForegroundLayer.strokeColor = component.trackForegroundColor.cgColor
            self.trackBackgroundLayer.lineWidth = trackHeight
            self.trackForegroundLayer.lineWidth = trackHeight
            
            let path = UIBezierPath()
            path.move(to: CGPoint(x: trackHeight / 2.0, y: availableSize.height / 2.0))
            path.addLine(to: CGPoint(x: availableSize.width - trackHeight / 2.0, y: availableSize.height / 2.0))
            
            self.trackBackgroundLayer.path = path.cgPath
            
            // Generate or set knob image
            if self.knobView.image == nil {
                self.knobView.image = generateImage(knobSize, rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                    // Shadow is now handled via layer to avoid clipping
                    context.setFillColor(UIColor.white.cgColor)
                    let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2.0)
                    context.addPath(path.cgPath)
                    context.fillPath()
                })
            }
             self.knobView.frame = CGRect(origin: .zero, size: knobSize)
            
            switch component.content {

            case let .continuous(continuous):
                self.value = continuous.value
            case let .discrete(discrete):
                if discrete.valueCount > 1 {
                     self.value = CGFloat(discrete.value) / CGFloat(discrete.valueCount - 1)
                } else {
                    self.value = 0.0
                }
            }
            
            self.updateLayout(availableSize: availableSize)
        }
        
        private func updateLayout(availableSize: CGSize) {
            let trackHeight: CGFloat = 6.0
            let knobSize = CGSize(width: 37.0, height: 24.0)
            let usableWidth = availableSize.width - trackHeight // Padding for line cap
            
            let x = (trackHeight / 2.0) + self.value * usableWidth
            
            let knobFrame = CGRect(
                x: x - knobSize.width / 2.0,
                y: (availableSize.height - knobSize.height) / 2.0,
                width: knobSize.width,
                height: knobSize.height
            )
            
            self.knobView.frame = knobFrame
            
            let foregroundPath = UIBezierPath()
            foregroundPath.move(to: CGPoint(x: trackHeight / 2.0, y: availableSize.height / 2.0))
            foregroundPath.addLine(to: CGPoint(x: x, y: availableSize.height / 2.0))
            self.trackForegroundLayer.path = foregroundPath.cgPath
            
            // Update Liquid Caret frame only if not dragging (physics handles it otherwise) or just ensure it's centered
             if self.liquidCaretView.isHidden {
                 self.liquidCaretView.frame = knobFrame
                 self.liquidCaretView.resize(width: knobFrame.width, height: knobFrame.height)
             }
        }
        
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: self)
            let trackHeight: CGFloat = 6.0
            let availableWidth = self.bounds.width - trackHeight
            var newValue = (location.x - trackHeight / 2.0) / availableWidth
            newValue = max(0.0, min(1.0, newValue))
            
            switch gesture.state {
            case .began:
                self.interactionBegan?()
                self.knobView.isHidden = true
                
                // liquidCaretView might be removed by animateDismissal, so re-add if needed
                if self.liquidCaretView.superview == nil {
                    self.addSubview(self.liquidCaretView)
                }
                self.liquidCaretView.isHidden = false
                // Reset shadow opacity (might have been faded out)
                self.liquidCaretView.layer.shadowOpacity = 0.12
                self.liquidCaretView.startDragging(at: self.knobView.center.x)
                
                // Pop animation: Scale TO 1.4x (User requested 1.4x for active state)
                self.liquidCaretView.transform = .identity
                UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, options: [], animations: {
                    self.liquidCaretView.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
                }, completion: nil)
                
            case .changed:
                self.value = newValue
                self.valueChanged?(newValue)
                
                // Update visual position of caret
                // We need to map 0..1 value back to X coordinate
                let x = (trackHeight / 2.0) + self.value * availableWidth
                self.liquidCaretView.setTargetPosition(x: x)
                
                 let foregroundPath = UIBezierPath()
                foregroundPath.move(to: CGPoint(x: trackHeight / 2.0, y: self.bounds.height / 2.0))
                foregroundPath.addLine(to: CGPoint(x: x, y: self.bounds.height / 2.0))
                self.trackForegroundLayer.path = foregroundPath.cgPath
                
            case .ended, .cancelled:
                self.interactionEnded?()
                 let x = (trackHeight / 2.0) + self.value * availableWidth
                 let knobSize = CGSize(width: 37.0, height: 24.0)
                 let targetFrame = CGRect(
                    x: x - knobSize.width / 2.0,
                    y: (self.bounds.height - knobSize.height) / 2.0,
                    width: knobSize.width,
                    height: knobSize.height
                )
                
                // Show knob immediately with alpha 0 and animate in parallel
                self.knobView.isHidden = false
                self.knobView.frame = targetFrame
                self.knobView.alpha = 0.0
                
                UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseOut], animations: {
                    self.knobView.alpha = 1.0
                    // Fade out liquid shadow to prevent double shadow during cross-fade
                    self.liquidCaretView.layer.shadowOpacity = 0.0
                }, completion: nil)
                
                self.liquidCaretView.animateDismissal(to: targetFrame, completion: {
                    // animateDismissal removes it from superview
                })
                
            default:
                break
            }
        }
    }
    
    public final class View: UIView {
        private var nativeSliderView: SliderView?
        private var sliderView: CustomSliderView?
        
        private var component: SliderComponent?
        private weak var state: EmptyComponentState?
        
        public var hitTestTarget: UIView? {
            return self.sliderView
        }
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        public func cancelGestures() {
            if let sliderView = self.sliderView, let gestureRecognizers = sliderView.gestureRecognizers {
                for gestureRecognizer in gestureRecognizers {
                    gestureRecognizer.isEnabled = false
                    gestureRecognizer.isEnabled = true
                }
            }
        }
        
        func update(component: SliderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: availableSize.width, height: 44.0)
            
            if #available(iOS 26.0, *), component.useNative {
                let sliderView: SliderView
                if let current = self.nativeSliderView {
                    sliderView = current
                } else {
                    sliderView = SliderView()
                    sliderView.disablesInteractiveTransitionGestureRecognizer = true
                    sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
                    sliderView.layer.allowsGroupOpacity = true
                    
                    self.addSubview(sliderView)
                    self.nativeSliderView = sliderView
                    
                    switch component.content {
                    case let .continuous(continuous):
                        sliderView.minimumValue = Float(continuous.minValue ?? 0.0)
                        sliderView.maximumValue = 1.0
                    case let .discrete(discrete):
                        sliderView.minimumValue = 0.0
                        sliderView.maximumValue = Float(discrete.valueCount - 1)
                        sliderView.trackConfiguration = .init(numberOfTicks: discrete.valueCount)
                    }
                }
                switch component.content {
                case let .continuous(continuous):
                    sliderView.value = Float(continuous.value)
                case let .discrete(discrete):
                    sliderView.value = Float(discrete.value)
                }
                sliderView.minimumTrackTintColor = component.trackForegroundColor
                sliderView.maximumTrackTintColor = component.trackBackgroundColor
                
                transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: 44.0)))
            } else {
                var internalIsTrackingUpdated: ((Bool) -> Void)?
                if let isTrackingUpdated = component.isTrackingUpdated {
                    internalIsTrackingUpdated = { isTracking in
                        isTrackingUpdated(isTracking)
                    }
                }
                
                let sliderView: CustomSliderView
                if let current = self.sliderView {
                    sliderView = current
                } else {
                    sliderView = CustomSliderView()
                    self.sliderView = sliderView
                    self.addSubview(sliderView)
                    
                sliderView.valueChanged = { [weak self] value in
                        self?.updateValue(value)
                    }
                    
                    sliderView.interactionBegan = {
                        internalIsTrackingUpdated?(true)
                    }
                    sliderView.interactionEnded = {
                        internalIsTrackingUpdated?(false)
                    }
                }
                
                sliderView.update(component: component, availableSize: size)
                
                transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            }
            
            return size
        }
        
        private func updateValue(_ value: CGFloat) {
            guard let component = self.component else {
                return
            }
            switch component.content {
            case let .discrete(discrete):
                let intValue = Int(round(value * CGFloat(discrete.valueCount - 1)))
                discrete.valueUpdated(intValue)
            case let .continuous(continuous):
                continuous.valueUpdated(value)
            }
        }
        
        @objc private func sliderValueChanged() {
            guard let component = self.component else {
                return
            }
             // Handle native slider updates if needed, though we primarily use CustomSliderView now
             if let nativeSliderView = self.nativeSliderView {
                let floatValue = CGFloat(nativeSliderView.value)
                switch component.content {
                case let .discrete(discrete):
                    discrete.valueUpdated(Int(floatValue))
                case let .continuous(continuous):
                    continuous.valueUpdated(floatValue)
                }
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

