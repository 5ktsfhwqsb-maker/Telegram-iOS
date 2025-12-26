import UIKit
import Display
import BackdropMeshObjC

public final class ViewController: UIViewController {

    private var backdropContainerView: LiquidASSView?
    private var nativeGlassReferenceView: UIView?
    private var draggableTestView: UIView?

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupTestBackground()
        setupDraggableTestView()
        setupBackdropWithLensDistortion()
        setupNativeGlassReference()
        setupGestureRecognizers()
        setupDebugButton()
    }
    
    private func setupNativeGlassReference() {
        // Native reference using system material
        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let visualEffectView = UIVisualEffectView(effect: effect)
        
        visualEffectView.frame = CGRect(
            x: (view.bounds.width - 300) / 2,
            y: (view.bounds.height - 300) / 2 + 200, // Offset below the custom one
            width: 360,
            height: 60
        )
        visualEffectView.layer.cornerRadius = 30
        visualEffectView.layer.masksToBounds = true
        
        // Label
        let label = UILabel()
        label.text = "Native\nReference"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        let whiteColor: UIColor
        if #available(iOS 13.0, *) {
             whiteColor = .label
        } else {
             whiteColor = .white
        }
        label.textColor = whiteColor.withAlphaComponent(0.6)
        label.frame = visualEffectView.bounds
        visualEffectView.contentView.addSubview(label)
        
        view.addSubview(visualEffectView)
        nativeGlassReferenceView = visualEffectView
    }

    private func setupDebugButton() {
        let button = UIButton(type: .system)
        button.setTitle("Toggle Grid", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        button.addTarget(self, action: #selector(toggleDebugMesh), for: .touchUpInside)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])
    }
    
    @objc private func toggleDebugMesh() {
        backdropContainerView?.isDebugOn.toggle()
    }

    private func setupDraggableTestView() {
        // Container
        let container = UIView(frame: CGRect(x: 50, y: 300, width: 200, height: 100))
        container.backgroundColor = .clear
        
        // Content (The part to look at through glass)
        let contentView = UIView(frame: CGRect(x: 0, y: 40, width: 200, height: 60))
        contentView.backgroundColor = .systemPink
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor.white.cgColor
        
        // Add some detailing to see distortion better
        let stripe = UIView(frame: CGRect(x: 0, y: 20, width: 200, height: 10))
        stripe.backgroundColor = .white
        contentView.addSubview(stripe)
        
        let label = UILabel(frame: contentView.bounds)
        label.text = "Drag me under!\nTest Distortion"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: 18)
        label.textColor = .white
        contentView.addSubview(label)
        container.addSubview(contentView)
        
        // Handle (The protruding part) - Sticks out top
        let handle = UIView(frame: CGRect(x: 80, y: 0, width: 40, height: 50))
        handle.backgroundColor = .systemYellow
        handle.layer.cornerRadius = 20
        handle.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        handle.layer.borderWidth = 2
        handle.layer.borderColor = UIColor.black.withAlphaComponent(0.2).cgColor
        
        let handleDetail = UIView(frame: CGRect(x: 10, y: 10, width: 20, height: 4))
        handleDetail.backgroundColor = .black.withAlphaComponent(0.2)
        handleDetail.layer.cornerRadius = 2
        handle.addSubview(handleDetail)
        
        container.addSubview(handle)
        container.bringSubviewToFront(contentView) // Content covers handle bottom
        
        // Gesture
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        container.addGestureRecognizer(pan)
        
        view.addSubview(container)
        draggableTestView = container
    }

    private func setupTestBackground() {
        // Create UV Gradient background for distortion debugging
        view.backgroundColor = .black
        
        // Add some labels
        let titleLabel = UILabel()
        titleLabel.text = "Lens Distortion Test"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.frame = CGRect(x: 0, y: 50, width: view.bounds.width, height: 40)
        view.addSubview(titleLabel)
    }
    
    private func removeTintFromNativeReference() {
        guard let view = nativeGlassReferenceView else { return }
        
        // Hack to remove white tint from UIVisualEffectView
        for subview in view.subviews {
            let className = String(describing: type(of: subview))
            print("Native Subview: \(className)")
            
            // _UIVisualEffectBackdropView is the blur/mesh.
            // _UIVisualEffectSubview / _UIVisualEffectFilterView usually hold the tint.
            if className.contains("Backdrop") {
                // Keep this one
                print(" -> Keeping Backdrop")
            } else {
                // Hide others (tints, colored layers)
                print(" -> Hiding Potential Tint")
                subview.isHidden = true
                subview.alpha = 0
            }
        }
    }

    private func setupBackdropWithLensDistortion() {
        let liquidAssView = LiquidASSView(
            frame: CGRect(
                x: (view.bounds.width - 300) / 2,
                y: (view.bounds.height - 300) / 2,
                width: 360,
                height: 60
            )
        )
        liquidAssView.apply(
            configuration: LiquidASSView.Configuration(
                cornerRadius: 30,
                blurIntensity: 5.0,
                lensDistortionStrength: 1.0,
                tintColor: nil,
                saturation: 1.1,
                brightness: 0.15,
                cornerSegments: 14
            )
        )
        view.addSubview(liquidAssView)
        backdropContainerView = liquidAssView
//
//        // Add debug mesh visualization
//        let debugMesh = BackdropMeshHelper.debugMeshShape(
//            withGridSize: 40,
//            distortionStrength: 0.2,
//            bounds: liquidAssView.bounds // Use container bounds for the shape
//        )
//        debugMesh.frame = liquidAssView.bounds // Ensure frame matches
//        liquidAssView.layer.addSublayer(debugMesh)
//        self.debugMeshLayer = debugMesh // Store reference

        // Add label overlay
        let overlayLabel = UILabel()
        overlayLabel.text = "Blurred\nLens Effect"
        overlayLabel.numberOfLines = 0
        overlayLabel.textAlignment = .center
        overlayLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        overlayLabel.textColor = .white
        overlayLabel.frame = liquidAssView.bounds
        liquidAssView.addSubview(overlayLabel)
    }

    private func setupGestureRecognizers() {
        if let container = backdropContainerView {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            container.addGestureRecognizer(panGesture)
        }
        
        if let nativeRef = nativeGlassReferenceView {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            nativeRef.addGestureRecognizer(panGesture)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let targetView = gesture.view else { return }

        let translation = gesture.translation(in: view)

        // Move the container
        targetView.center = CGPoint(
            x: targetView.center.x + translation.x,
            y: targetView.center.y + translation.y
        )

        // Reset translation
        gesture.setTranslation(.zero, in: view)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Only center if not panned yet (simple check, or just skipping re-centering after load)
        // Ignoring to avoid resetting pan on random layout updates
    }
}
