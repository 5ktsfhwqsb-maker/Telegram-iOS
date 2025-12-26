import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import MultilineTextComponent
import LottieComponent
import UIKitRuntimeUtils
import BundleIconComponent
import BundleIconComponent
import TextBadgeComponent
import LiquidGlassComponent

public final class TabBarComponent: Component {
    public final class Item: Equatable {
        public let item: UITabBarItem
        public let action: (Bool) -> Void
        public let contextAction: ((ContextGesture, ContextExtractedContentContainingView) -> Void)?
        
        fileprivate var id: AnyHashable {
            return AnyHashable(ObjectIdentifier(self.item))
        }
        
        public init(item: UITabBarItem, action: @escaping (Bool) -> Void, contextAction: ((ContextGesture, ContextExtractedContentContainingView) -> Void)?) {
            self.item = item
            self.action = action
            self.contextAction = contextAction
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.item !== rhs.item {
                return false
            }
            if (lhs.contextAction == nil) != (rhs.contextAction == nil) {
                return false
            }
            return true
        }
    }
    
    public let theme: PresentationTheme
    public let items: [Item]
    public let selectedId: AnyHashable?
    public let isTablet: Bool
    public let maxItemWidth: CGFloat
    
    public init(
        theme: PresentationTheme,
        items: [Item],
        selectedId: AnyHashable?,
        isTablet: Bool,
        maxItemWidth: CGFloat = 85.0
    ) {
        self.theme = theme
        self.items = items
        self.selectedId = selectedId
        self.isTablet = isTablet
        self.maxItemWidth = maxItemWidth
    }
    
    public static func ==(lhs: TabBarComponent, rhs: TabBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        if lhs.isTablet != rhs.isTablet {
            return false
        }
        if lhs.maxItemWidth != rhs.maxItemWidth {
            return false
        }
        return true
    }
    
    public final class View: UIView, UITabBarDelegate, UIGestureRecognizerDelegate {
        private let backgroundView: GlassBackgroundView
        private let selectionView: GlassBackgroundView.ContentImageView
        private let contextGestureContainerView: ContextControllerSourceView
        private let nativeTabBar: UITabBar?
        
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        private var selectedItemViews: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var caretView: LiquidCaretView?
        private var caretHoveredItemId: AnyHashable?
        private var itemWithActiveContextGesture: AnyHashable?
        private var previousSelectedId: AnyHashable?
        private var ignoreNextSelectionAnimation: Bool = false
        
        private var component: TabBarComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            self.selectionView = GlassBackgroundView.ContentImageView()
            
            self.contextGestureContainerView = ContextControllerSourceView()
            self.contextGestureContainerView.isGestureEnabled = true
            
            if #available(iOS 26.0, *) {
                let nativeTabBar = UITabBar()
                self.nativeTabBar = nativeTabBar
                
                let itemFont = Font.semibold(10.0)
                let itemColor: UIColor = .clear
                
                nativeTabBar.traitOverrides.verticalSizeClass = .compact
                nativeTabBar.traitOverrides.horizontalSizeClass = .compact
                nativeTabBar.standardAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: itemColor,
                    .font: itemFont
                ]
                nativeTabBar.standardAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: itemColor,
                    .font: itemFont
                ]
                nativeTabBar.standardAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: itemColor,
                    .font: itemFont
                ]
                nativeTabBar.standardAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: itemColor,
                    .font: itemFont
                ]
                nativeTabBar.standardAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: itemColor,
                    .font: itemFont
                ]
                nativeTabBar.standardAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: itemColor,
                    .font: itemFont
                ]
            } else {
                self.nativeTabBar = nil
            }
            
            super.init(frame: frame)
            
            if #available(iOS 17.0, *) {
                self.traitOverrides.verticalSizeClass = .compact
                self.traitOverrides.horizontalSizeClass = .compact
            }
            
            self.addSubview(self.contextGestureContainerView)
            
            if let nativeTabBar = self.nativeTabBar {
                self.contextGestureContainerView.addSubview(nativeTabBar)
                nativeTabBar.delegate = self
            } else {
                self.contextGestureContainerView.addSubview(self.backgroundView)
                self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
                
                let caretGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleCaretGesture(_:)))
                caretGesture.minimumPressDuration = 0.2
                self.addGestureRecognizer(caretGesture)
            }
            
            self.contextGestureContainerView.shouldBegin = { [weak self] point in
                guard let self, let component = self.component else {
                    return false
                }
                for (id, itemView) in self.itemViews {
                    if let itemView = itemView.view {
                        if self.convert(itemView.bounds, from: itemView).contains(point) {
                            guard let item = component.items.first(where: { $0.id == id }) else {
                                return false
                            }
                            if item.contextAction == nil {
                                return false
                            }
                            
                            self.itemWithActiveContextGesture = id
                            
                            let startPoint = point
                            self.contextGestureContainerView.contextGesture?.externalUpdated = { [weak self] _, point in
                                guard let self else {
                                    return
                                }
                                
                                let dist = sqrt(pow(startPoint.x - point.x, 2.0) + pow(startPoint.y - point.y, 2.0))
                                if dist > 10.0 {
                                    self.contextGestureContainerView.contextGesture?.cancel()
                                }
                            }
                            
                            return true
                        }
                    }
                }
                return false
            }
            self.contextGestureContainerView.customActivationProgress = { [weak self] _, _ in
                let _ = self
                return
                /*guard let self, let itemWithActiveContextGesture = self.itemWithActiveContextGesture else {
                    return
                }
                guard let itemView = self.itemViews[itemWithActiveContextGesture]?.view else {
                    return
                }
                let scaleSide = itemView.bounds.width
                let minScale: CGFloat = max(0.7, (scaleSide - 15.0) / scaleSide)
                let currentScale = 1.0 * (1.0 - progress) + minScale * progress

                switch update {
                case .update:
                    let sublayerTransform = CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0)
                    itemView.layer.sublayerTransform = sublayerTransform
                case .begin:
                    let sublayerTransform = CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0)
                    itemView.layer.sublayerTransform = sublayerTransform
                case .ended:
                    let sublayerTransform = CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0)
                    let previousTransform = itemView.layer.sublayerTransform
                    itemView.layer.sublayerTransform = sublayerTransform

                    itemView.layer.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                }*/
            }
            self.contextGestureContainerView.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    return
                }
                guard let itemWithActiveContextGesture = self.itemWithActiveContextGesture else {
                    return
                }
                
                var itemView: ItemComponent.View?
                if self.nativeTabBar != nil {
                    itemView = self.selectedItemViews[itemWithActiveContextGesture]?.view as? ItemComponent.View
                } else {
                    itemView = self.itemViews[itemWithActiveContextGesture]?.view as? ItemComponent.View
                }
                
                guard let itemView else {
                    return
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    if let nativeTabBar = self.nativeTabBar {
                        func cancelGestures(view: UIView) {
                            for recognizer in view.gestureRecognizers ?? [] {
                                if NSStringFromClass(type(of: recognizer)).contains("sSelectionGestureRecognizer") {
                                    recognizer.state = .cancelled
                                }
                            }
                            for subview in view.subviews {
                                cancelGestures(view: subview)
                            }
                        }
                        
                        cancelGestures(view: nativeTabBar)
                    }
                }
                
                guard let item = component.items.first(where: { $0.id == itemWithActiveContextGesture }) else {
                    return
                }
                item.contextAction?(gesture, itemView.contextContainerView)
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            guard let component = self.component else {
                return
            }
            if let index = tabBar.items?.firstIndex(where: { $0 === item }) {
                if index < component.items.count {
                    component.items[index].action(false)
                }
            }
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        @objc private func onLongPressGesture(_ recognizer: UILongPressGestureRecognizer) {
            if case .began = recognizer.state {
                if let nativeTabBar = self.nativeTabBar {
                    func cancelGestures(view: UIView) {
                        for recognizer in view.gestureRecognizers ?? [] {
                            if NSStringFromClass(type(of: recognizer)).contains("sSelectionGestureRecognizer") {
                                recognizer.state = .cancelled
                            }
                        }
                        for subview in view.subviews {
                            cancelGestures(view: subview)
                        }
                    }
                    
                    cancelGestures(view: nativeTabBar)
                }
            }
        }
        
        @objc private func handleCaretGesture(_ recognizer: UILongPressGestureRecognizer) {
            guard let component = self.component else { return }
            
            let point = recognizer.location(in: self)
            
            switch recognizer.state {
            case .began:
                // Identify target item
                if let (_, frame) = self.itemAt(point: point) {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    self.selectionView.isHidden = true
                    
                    if self.caretView == nil {
                        // Position safely below badges/text but above background
                        let caretHeight = self.bounds.height * 1.3
                        let caretWidth: CGFloat = 117.0
                        let caret = LiquidCaretView(frame: CGRect(x: 0, y: 0, width: caretWidth, height: caretHeight))
                        
                        // Center vertically relative to the tab bar container
                        let centerY = self.bounds.midY
                        caret.frame = CGRect(x: frame.midX - caretWidth / 2.0, y: centerY - caretHeight / 2.0, width: caretWidth, height: caretHeight)
                        
                        // Insert above background
                        if let background = self.subviews.first(where: { $0 is GlassBackgroundView }) {
                            self.insertSubview(caret, aboveSubview: background)
                        } else {
                            self.addSubview(caret)
                        }
                        caret.isUserInteractionEnabled = false
                        
                        // Physics tuning for "swimming" lag (same as SwitchNode)
                        caret.springTension = 260.0
                        caret.springFriction = 28.0
                        caret.stretchSensitivity = 0.05
                        caret.configuration = LiquidASSView.Configuration(
                            cornerRadius: caretHeight / 2.0,
                            blurIntensity: 0.0,
                            lensDistortionStrength: 0.06,
                            tintColor: nil,
                            saturation: nil,
                            brightness: nil,
                            cornerSegments: 18,
                            contentScale: UIScreen.main.scale,
                            visualZoom: 1.0,
                            bleedAmount: 10.0,
                            showBorder: false,
                            distortionPadding: 2.2,
                            distortionMultiplier: 4.5,
                            distortionExponent: 3.0
                        )
                        self.caretView = caret
                    }
                    
                    self.caretView?.startDragging(at: point.x)
                    
                    // Reset parallax
                    self.contextGestureContainerView.transform = .identity
                } else {
                    recognizer.state = .cancelled
                }
                
            case .changed:
                // Relaxed clamping (overshoot allowed)
                // User wants edge to be max 5px out.
                // caretView center is what we control.
                // minCenter = -20 + halfWidth
                // maxCenter = width + 20 - halfWidth
                let clampLimit: CGFloat = 15.0
                let caretWidth: CGFloat = 117.0 // Updated width
                let halfWidth = caretWidth / 2.0
                
                let minCenter = -clampLimit + halfWidth
                let maxCenter = self.bounds.width + clampLimit - halfWidth
                
                let clampedX = max(minCenter, min(point.x, maxCenter))
                
                self.caretView?.setTargetPosition(x: clampedX)
                
                // Parallax shift
                let centerX = self.bounds.width / 2.0
                let deltaX = point.x - centerX
                let shift = deltaX * 0.01 // Parallax amount
                
                // Apply transform: translation only (parallax)
                self.contextGestureContainerView.transform = CGAffineTransform(translationX: shift, y: 0)
                
                // Haptic feedback on item change
                if let (id, _) = self.itemAt(point: point) {
                    if self.caretHoveredItemId != id {
                        self.caretHoveredItemId = id
                        let selection = UISelectionFeedbackGenerator()
                        selection.selectionChanged()
                    }
                }
                
            case .ended, .cancelled:
                // Animate parallax reset immediately
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.0, options: [], animations: {
                    self.contextGestureContainerView.transform = .identity
                }, completion: nil)
                
                if let (id, _) = self.itemAt(point: point) {
                    var targetFrame: CGRect?
                    
                    // Retrieve the view again to get its true resting frame (relative to container)
                    if let itemView = self.itemViews[id]?.view {
                         targetFrame = self.contextGestureContainerView.convert(itemView.bounds, from: itemView)
                    }
                    
                    if let frame = targetFrame {
                        // Fade in selection view parallel to dismissal
                        self.selectionView.isHidden = false
                        self.selectionView.alpha = 0.0
                        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseOut], animations: {
                            self.selectionView.alpha = 1.0
                        }, completion: nil)
                        
                        self.caretView?.animateDismissal(to: frame) { [weak self] in
                            self?.caretView = nil
                        }
                    } else {
                        // Fallback if view not found (unlikely)
                         self.caretView?.removeFromSuperview()
                         self.caretView = nil
                         self.selectionView.isHidden = false
                    }
                    
                    if let item = component.items.first(where: { $0.id == id }) {
                        self.ignoreNextSelectionAnimation = true
                        item.action(false)
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                } else {
                    // If released outside, just fade out/shrink to nothing?
                    // Or shrink to nearest?
                    // User said "shrink to size of backing". If no backing (no selection update), 
                    // maybe just fade?
                    // Let's fade if invalid target.
                    // But API changed. We need a fallback.
                    // Or just use previous logic for "outside" case.
                    self.caretView?.startDragging(at: point.x) // Hack to keep alive? No.
                    // Restore old stopDragging behavior for cancel?
                    // Or just kill it.
                    self.caretView?.removeFromSuperview()
                    self.caretView = nil
                    self.selectionView.isHidden = false
                }
                
                self.caretHoveredItemId = nil
                
            default:
                break
            }
        }
        
        private func itemAt(point: CGPoint) -> (AnyHashable, CGRect)? {
            guard let _ = self.component else { return nil }
            
            // Find closest is better than exact hit test for dragging
            var closest: (AnyHashable, CGRect, CGFloat)?
            
            for (id, itemView) in self.itemViews {
                guard let view = itemView.view else { continue }
                let frame = self.convert(view.bounds, from: view)
                let dist = abs(point.x - frame.midX)
                
                // Allow some vertical slack
                if point.y > frame.minY - 20 && point.y < frame.maxY + 20 {
                    if let current = closest {
                        if dist < current.2 {
                            closest = (id, frame, dist)
                        }
                    } else {
                        closest = (id, frame, dist)
                    }
                }
            }
            
            if let result = closest {
                return (result.0, result.1)
            }
            return nil
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                let point = recognizer.location(in: self)
                var closestItemView: (AnyHashable, CGFloat)?
                for (id, itemView) in self.itemViews {
                    guard let itemView = itemView.view else {
                        continue
                    }
                    let distance = abs(point.x - itemView.center.x)
                    if let previousClosestItemView = closestItemView {
                        if previousClosestItemView.1 > distance {
                            closestItemView = (id, distance)
                        }
                    } else {
                        closestItemView = (id, distance)
                    }
                }
                
                if let (id, _) = closestItemView {
                    guard let item = component.items.first(where: { $0.id == id }) else {
                        return
                    }
                    item.action(false)
                    /*if previousSelectedIndex != closestNode.0 {
                     if let selectedIndex = self.selectedIndex, let _ = self.tabBarItems[selectedIndex].item.animationName {
                     container.imageNode.animationNode.play(firstFrame: false, fromIndex: nil)
                     }
                     }*/
                }
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        public func frameForItem(at index: Int) -> CGRect? {
            guard let component = self.component else {
                return nil
            }
            if index < 0 || index >= component.items.count {
                return nil
            }
            guard let itemView = self.itemViews[component.items[index].id]?.view else {
                return nil
            }
            return self.convert(itemView.bounds, from: itemView)
        }
        
        public override func didMoveToWindow() {
            super.didMoveToWindow()
            
            self.state?.updated()
        }
        
        func update(component: TabBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let innerInset: CGFloat = 3.0
            
            let availableSize = CGSize(width: min(500.0, availableSize.width), height: availableSize.height)
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            self.overrideUserInterfaceStyle = component.theme.overallDarkAppearance ? .dark : .light
            
            if let nativeTabBar = self.nativeTabBar {
                if previousComponent?.items.map(\.item.title) != component.items.map(\.item.title) {
                    let items: [UITabBarItem] = (0 ..< component.items.count).map { i in
                        return UITabBarItem(title: component.items[i].item.title, image: nil, tag: i)
                    }
                    nativeTabBar.items = items
                    for (_, itemView) in self.itemViews {
                        itemView.view?.removeFromSuperview()
                    }
                    for (_, selectedItemView) in self.selectedItemViews {
                        selectedItemView.view?.removeFromSuperview()
                    }
                    if let index = component.items.firstIndex(where: { $0.id == component.selectedId }) {
                        nativeTabBar.selectedItem = nativeTabBar.items?[index]
                    }
                }
                
                nativeTabBar.frame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: component.isTablet ? 74.0 : 83.0))
                nativeTabBar.layoutSubviews()
            }
            
            var nativeItemContainers: [Int: UIView] = [:]
            var nativeSelectedItemContainers: [Int: UIView] = [:]
            if let nativeTabBar = self.nativeTabBar {
                for subview in nativeTabBar.subviews {
                    if NSStringFromClass(type(of: subview)).contains("PlatterView") {
                        for subview in subview.subviews {
                            if NSStringFromClass(type(of: subview)).hasSuffix("SelectedContentView") {
                                for subview in subview.subviews {
                                    if NSStringFromClass(type(of: subview)).hasSuffix("TabButton") {
                                        nativeSelectedItemContainers[nativeSelectedItemContainers.count] = subview
                                    }
                                }
                            } else if NSStringFromClass(type(of: subview)).hasSuffix("ContentView") {
                                for subview in subview.subviews {
                                    if NSStringFromClass(type(of: subview)).hasSuffix("TabButton") {
                                        nativeItemContainers[nativeItemContainers.count] = subview
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            var itemSize = CGSize(width: floor((availableSize.width - innerInset * 2.0) / CGFloat(component.items.count)), height: 56.0)
            itemSize.width = min(component.maxItemWidth, itemSize.width)
            
            if let itemContainer = nativeItemContainers[0] {
                itemSize = itemContainer.bounds.size
            }
            
            let contentHeight = itemSize.height + innerInset * 2.0
            var contentWidth: CGFloat = innerInset
            
            if self.selectionView.image?.size.height != itemSize.height {
                self.selectionView.image = generateStretchableFilledCircleImage(radius: itemSize.height * 0.5, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.selectionView.tintColor = component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.05)
            
            var validIds: [AnyHashable] = []
            var selectionFrame: CGRect?
            for index in 0 ..< component.items.count {
                let item = component.items[index]
                validIds.append(item.id)
                
                let itemView: ComponentView<Empty>
                var itemTransition = transition
                
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[item.id] = itemView
                }
                
                let selectedItemView: ComponentView<Empty>
                if let current = self.selectedItemViews[item.id] {
                    selectedItemView = current
                } else {
                    selectedItemView = ComponentView()
                    self.selectedItemViews[item.id] = selectedItemView
                }
                
                let isItemSelected = component.selectedId == item.id
                
                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        item: item,
                        theme: component.theme,
                        isSelected: self.nativeTabBar == nil ? isItemSelected : false
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                let _ = selectedItemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        item: item,
                        theme: component.theme,
                        isSelected: true
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                
                let itemFrame = CGRect(origin: CGPoint(x: contentWidth, y: floor((contentHeight - itemSize.height) * 0.5)), size: itemSize)
                if let itemComponentView = itemView.view as? ItemComponent.View, let selectedItemComponentView = selectedItemView.view as? ItemComponent.View {
                    if itemComponentView.superview == nil {
                        itemComponentView.isUserInteractionEnabled = false
                        selectedItemComponentView.isUserInteractionEnabled = false
                        
                        if self.nativeTabBar != nil {
                            if let itemContainer = nativeItemContainers[index] {
                                itemContainer.addSubview(itemComponentView)
                            }
                            if let itemContainer = nativeSelectedItemContainers[index] {
                                itemContainer.addSubview(selectedItemComponentView)
                            }
                        } else {
                            self.contextGestureContainerView.addSubview(itemComponentView)
                        }
                    }
                    if self.nativeTabBar != nil {
                        if let parentView = itemComponentView.superview {
                            let itemFrame = CGRect(origin: CGPoint(x: floor((parentView.bounds.width - itemSize.width) * 0.5), y: floor((parentView.bounds.height - itemSize.height) * 0.5)), size: itemSize)
                            itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                            itemTransition.setFrame(view: selectedItemComponentView, frame: itemFrame)
                        }
                    } else {
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                    
                    if let previousComponent, previousComponent.selectedId != item.id, isItemSelected {
                        itemComponentView.playSelectionAnimation()
                        selectedItemComponentView.playSelectionAnimation()
                    }
                }
                if isItemSelected {
                    selectionFrame = itemFrame
                }
                
                contentWidth += itemFrame.width
            }
            contentWidth += innerInset
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.view?.removeFromSuperview()
                    self.selectedItemViews[id]?.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
                self.selectedItemViews.removeValue(forKey: id)
            }
            
            if let selectionFrame, self.nativeTabBar == nil {
                var selectionViewTransition = transition
                if self.selectionView.superview == nil {
                    selectionViewTransition = selectionViewTransition.withAnimation(.none)
                    self.backgroundView.contentView.addSubview(self.selectionView)
                }
                selectionViewTransition.setFrame(view: self.selectionView, frame: selectionFrame)
            } else if self.selectionView.superview != nil {
                self.selectionView.removeFromSuperview()
            }
            
            // Trigger animation if selection changed (and used to select something else)
            // AND we are in "Custom Tab Bar" mode (nativeTabBar == nil)
            // AND we are not currently animating a gesture
            if self.nativeTabBar == nil {
                if self.ignoreNextSelectionAnimation {
                    self.ignoreNextSelectionAnimation = false
                } else if let previousId = self.previousSelectedId, previousId != component.selectedId, component.selectedId != nil {
                     // We need to find the OLD frame.
                     // The itemFrames depend on `contentWidth` logic which just ran above.
                     // However, since items list usually doesn't change relative order, and even if it did,
                     // we want the visual position.
                     
                     // We can find the view for the previous ID (it might still be in itemViews if not removed, or we just removed it?)
                     // "validIds" logic above handles removals. If the item is gone from the new list, we can't fly from it easily.
                     // But usually standard tab switching keeps items.
                     
                     var fromFrame: CGRect?
                     // We can try to recover the frame from the `itemViews` before layout updates or just assume current layout applies to old item too if it exists.
                     // The code above updated frames for ALL items in `itemViews`.
                     
                     if let previousView = self.itemViews[previousId]?.view {
                         fromFrame = previousView.frame
                     }
                     
                     if let startFrame = fromFrame, let endFrame = selectionFrame {
                         // Instantiate Caret
                         if self.caretView == nil {
                             // Create fresh caret
                             let caret = LiquidCaretView(frame: startFrame)
                             
                             // Physics Tuning
                             caret.springTension = 180.0
                             caret.springFriction = 28.0
                             caret.stretchSensitivity = 0.08
                             
                             // Config
                             let caretHeight = startFrame.height
                             caret.configuration = LiquidASSView.Configuration(
                                 cornerRadius: caretHeight / 2.0,
                                 blurIntensity: 0.0,
                                 lensDistortionStrength: 0.06,
                                 tintColor: nil,
                                 saturation: nil,
                                 brightness: nil,
                                 cornerSegments: 18,
                                 contentScale: UIScreen.main.scale,
                                 visualZoom: 1.0,
                                 bleedAmount: 10.0,
                                 showBorder: false,
                                 distortionPadding: 2.2,
                                 distortionMultiplier: 4.5,
                                 distortionExponent: 3.0
                             )
                             
                             // Insert above background
                             if let background = self.subviews.first(where: { $0 is GlassBackgroundView }) {
                                 self.insertSubview(caret, aboveSubview: background)
                             } else {
                                 self.addSubview(caret)
                             }
                             caret.isUserInteractionEnabled = false
                             self.caretView = caret
                             
                             // Initial State: Expanded at start position
                             caret.frame = startFrame
                             caret.startDragging(at: startFrame.midX) // Priming physics
                             
                             // Start at standard size (1.0) and let animateToggle handle the expansion
                             caret.transform = .identity
                         }
                         
                         // We have a caret (either just made or existing from gesture).
                         // If existing from gesture, it might be in weird state.
                         // But usually gesture ends -> dismiss -> nil.
                         // This path triggers on programmatic selection change (tap).
                         
                         if let caret = self.caretView {
                             self.selectionView.isHidden = true
                             self.selectionView.alpha = 0.0 // Ensure it starts invisible
                             
                             // Animate!
                             // shrinkStart callback fires when caret starts shrinking (at 80% mark)
                             // We fade IN the selection view then.
                             caret.animateToggle(to: endFrame, shrinkStart: { [weak self] in
                                 self?.selectionView.isHidden = false
                                 self?.selectionView.alpha = 0.0
                                 UIView.animate(withDuration: 0.2) {
                                     self?.selectionView.alpha = 1.0
                                 }
                             }, completion: { [weak self] in
                                 self?.caretView = nil
                                 // Ensure visibility in case shrinkStart missed or timing issue (safety)
                                 self?.selectionView.isHidden = false
                                 self?.selectionView.alpha = 1.0 
                             })
                         }
                     }
                }
            }
            
            self.previousSelectedId = component.selectedId
            
            // Enforce visibility logic: if caret exists, selection must be hidden
            if self.caretView != nil {
                self.selectionView.isHidden = true
            } else {
                self.selectionView.isHidden = false
            }
            
            let size = CGSize(width: min(availableSize.width, contentWidth), height: contentHeight)
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: component.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), transition: transition)
            
            if self.nativeTabBar != nil {
                let finalSize = CGSize(width: availableSize.width, height: 62.0)
                transition.setFrame(view: self.contextGestureContainerView, frame: CGRect(origin: CGPoint(), size: finalSize))
                return finalSize
            } else {
                transition.setFrame(view: self.contextGestureContainerView, frame: CGRect(origin: CGPoint(), size: size))
                return size
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

private final class ItemComponent: Component {
    let item: TabBarComponent.Item
    let theme: PresentationTheme
    let isSelected: Bool
    
    init(item: TabBarComponent.Item, theme: PresentationTheme, isSelected: Bool) {
        self.item = item
        self.theme = theme
        self.isSelected = isSelected
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.item != rhs.item {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let contextContainerView: ContextExtractedContentContainingView
        
        private var imageIcon: ComponentView<Empty>?
        private var animationIcon: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        private var badge: ComponentView<Empty>?
        
        private var component: ItemComponent?
        private weak var state: EmptyComponentState?
        
        private var setImageListener: Int?
        private var setSelectedImageListener: Int?
        private var setBadgeListener: Int?
        
        override init(frame: CGRect) {
            self.contextContainerView = ContextExtractedContentContainingView()
            
            super.init(frame: frame)
            
            self.addSubview(self.contextContainerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            if let component = self.component {
                if let setImageListener = self.setImageListener {
                    component.item.item.removeSetImageListener(setImageListener)
                }
                if let setSelectedImageListener = self.setSelectedImageListener {
                    component.item.item.removeSetSelectedImageListener(setSelectedImageListener)
                }
                if let setBadgeListener = self.setBadgeListener {
                    component.item.item.removeSetBadgeListener(setBadgeListener)
                }
            }
        }
        
        func playSelectionAnimation() {
            if let animationIconView = self.animationIcon?.view as? LottieComponent.View {
                animationIconView.playOnce()
            }
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            if previousComponent?.item.item !== component.item.item {
                if let setImageListener = self.setImageListener {
                    self.component?.item.item.removeSetImageListener(setImageListener)
                }
                if let setSelectedImageListener = self.setSelectedImageListener {
                    self.component?.item.item.removeSetSelectedImageListener(setSelectedImageListener)
                }
                if let setBadgeListener = self.setBadgeListener {
                    self.component?.item.item.removeSetBadgeListener(setBadgeListener)
                }
                self.setImageListener = component.item.item.addSetImageListener { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
                self.setSelectedImageListener = component.item.item.addSetSelectedImageListener { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
                self.setBadgeListener = UITabBarItem_addSetBadgeListener(component.item.item) { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
            }
            
            self.component = component
            self.state = state
            
            if let animationName = component.item.item.animationName {
                if let imageIcon = self.imageIcon {
                    self.imageIcon = nil
                    imageIcon.view?.removeFromSuperview()
                }
                
                let animationIcon: ComponentView<Empty>
                var iconTransition = transition
                if let current = self.animationIcon {
                    animationIcon = current
                } else {
                    iconTransition = iconTransition.withAnimation(.none)
                    animationIcon = ComponentView()
                    self.animationIcon = animationIcon
                }
                
                let iconSize = animationIcon.update(
                    transition: iconTransition,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: animationName
                        ),
                        color: component.isSelected ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor,
                        placeholderColor: nil,
                        startingPosition: .end,
                        size: CGSize(width: 48.0, height: 48.0),
                        loop: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 48.0, height: 48.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: -4.0), size: iconSize).offsetBy(dx: component.item.item.animationOffset.x, dy: component.item.item.animationOffset.y)
                if let animationIconView = animationIcon.view {
                    if animationIconView.superview == nil {
                        if let badgeView = self.badge?.view {
                            self.contextContainerView.contentView.insertSubview(animationIconView, belowSubview: badgeView)
                        } else {
                            self.contextContainerView.contentView.addSubview(animationIconView)
                        }
                    }
                    iconTransition.setFrame(view: animationIconView, frame: iconFrame)
                }
            } else {
                if let animationIcon = self.animationIcon {
                    self.animationIcon = nil
                    animationIcon.view?.removeFromSuperview()
                }
                
                let imageIcon: ComponentView<Empty>
                var iconTransition = transition
                if let current = self.imageIcon {
                    imageIcon = current
                } else {
                    iconTransition = iconTransition.withAnimation(.none)
                    imageIcon = ComponentView()
                    self.imageIcon = imageIcon
                }
                
                let iconSize = imageIcon.update(
                    transition: iconTransition,
                    component: AnyComponent(Image(
                        image: component.isSelected ? component.item.item.selectedImage : component.item.item.image,
                        tintColor: nil,
                        contentMode: .center
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: 3.0), size: iconSize)
                if let imageIconView = imageIcon.view {
                    if imageIconView.superview == nil {
                        if let badgeView = self.badge?.view {
                            self.contextContainerView.contentView.insertSubview(imageIconView, belowSubview: badgeView)
                        } else {
                            self.contextContainerView.contentView.addSubview(imageIconView)
                        }
                    }
                    iconTransition.setFrame(view: imageIconView, frame: iconFrame)
                }
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.item.item.title ?? " ", font: Font.semibold(10.0), textColor: component.isSelected ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: availableSize.height - 8.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.contextContainerView.contentView.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            if let badgeText = component.item.item.badgeValue, !badgeText.isEmpty {
                let badge: ComponentView<Empty>
                var badgeTransition = transition
                if let current = self.badge {
                    badge = current
                } else {
                    badgeTransition = badgeTransition.withAnimation(.none)
                    badge = ComponentView()
                    self.badge = badge
                }
                let badgeSize = badge.update(
                    transition: badgeTransition,
                    component: AnyComponent(TextBadgeComponent(
                        text: badgeText,
                        font: Font.regular(13.0),
                        background: component.theme.rootController.tabBar.badgeBackgroundColor,
                        foreground: component.theme.rootController.tabBar.badgeTextColor,
                        insets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 1.0, right: 6.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let contentWidth: CGFloat = 25.0
                let badgeFrame = CGRect(origin: CGPoint(x: floor(availableSize.width / 2.0) + contentWidth - badgeSize.width - 1.0, y: 5.0), size: badgeSize)
                if let badgeView = badge.view {
                    if badgeView.superview == nil {
                        self.contextContainerView.contentView.addSubview(badgeView)
                    }
                    badgeTransition.setFrame(view: badgeView, frame: badgeFrame)
                }
            } else if let badge = self.badge {
                self.badge = nil
                badge.view?.removeFromSuperview()
            }
            
            transition.setFrame(view: self.contextContainerView, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setFrame(view: self.contextContainerView.contentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.contextContainerView.contentRect = CGRect(origin: CGPoint(), size: availableSize)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
