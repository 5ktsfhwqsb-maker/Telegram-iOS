//
//  LiquidASSView.swift
//  GlassBackgroundDevTest
//
//  Created by whoo on 13.12.2025.
//

import UIKit
import Foundation
import BackdropMeshObjC

final class LiquidASSView: UIView {

    struct Configuration {
        let cornerRadius: CGFloat
        let blurIntensity: CGFloat
        let lensDistortionStrength: CGFloat
        let tintColor: UIColor?
        let saturation: CGFloat?
        let brightness: CGFloat?
        let cornerSegments: Int?
    }

    var isDebugOn: Bool {
        get { debugMeshLayer?.isHidden ?? false }
        set { debugMeshLayer?.isHidden = newValue }
    }

    private weak var debugMeshLayer: CAShapeLayer?
    private weak var borderLayer: CAGradientLayer?
    private weak var tintLayer: CALayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    override required init?(coder: NSCoder) {
        fatalError()
    }

    func apply(configuration: Configuration) {
        layer.cornerRadius = configuration.cornerRadius

        let backdropLayer = BackdropMeshHelper.createBackdropLayer(
            withBlurRadius: configuration.blurIntensity,
            saturation: configuration.saturation as NSNumber?,
            brightness: configuration.brightness as NSNumber?
        )
        backdropLayer.frame = bounds
        layer.addSublayer(backdropLayer)

        let config: [String: Any] = [
            "distortionStrength": configuration.lensDistortionStrength,
            "bounds": bounds,
            "cornerRadius": configuration.cornerRadius,
            "cornerSegments": configuration.cornerSegments ?? 0
        ]

        if let meshTransform = BackdropMeshHelper.createOptimizedLensDistortionMesh(withConfiguration: config) {
            // print("✅ Mesh created/retrieved from cache")

            // Apply to backdrop layer instead of container
            backdropLayer.setValue(meshTransform, forKey: "meshTransform")
        } else {
            print("❌ Mesh creation failed")
        }

        setupTintLayer(configuration: configuration)
        setupBorder(configuration: configuration)
//        setupDebugStuff(configuration: configuration)
    }
}

private extension LiquidASSView {

    func setup() {
        layer.masksToBounds = true
        backgroundColor = .clear
    }

    func setupTintLayer(configuration: Configuration) {
        tintLayer?.removeFromSuperlayer()
        guard let color = configuration.tintColor else { return }
        
        let tint = CALayer()
        tint.frame = bounds
        tint.backgroundColor = color.cgColor
        tint.cornerRadius = configuration.cornerRadius
        
        layer.addSublayer(tint)
        self.tintLayer = tint
    }
    
    func setupBorder(configuration: Configuration) {
        borderLayer?.removeFromSuperlayer()

        let gradient = CAGradientLayer()
        gradient.type = .conic
        gradient.frame = bounds
        
        // Align 0-start to Bottom-Right by pointing endPoint to (1,1)
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0) // 0 degrees at Bottom-Right (approx 45 deg)

        let cVisible = UIColor.white.withAlphaComponent(0.6).cgColor
        let cTransparent = UIColor.white.withAlphaComponent(0.9) // Less transparent as requested

        // Pattern depends on Conic direction (Clockwise).
        // 0.0 (BR): Visible
        // 0.25 (BL): Transparent
        // 0.5 (TL): Visible
        // 0.75 (TR): Transparent
        // 1.0 (BR): Visible (Wrap)

        gradient.colors = [
            cVisible,     // 0.0 BR
            cTransparent, // 0.25 BL
            cVisible,     // 0.5 TL
            cTransparent, // 0.75 TR
            cVisible      // 1.0 BR Wrap
        ]
        
        // Ensure locations are explicit to match corners exactly
        gradient.locations = [0.0, 0.25, 0.5, 0.75, 1.0]

        // Mask for the border
        let mask = CAShapeLayer()
        mask.path = UIBezierPath(roundedRect: bounds, cornerRadius: configuration.cornerRadius).cgPath
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.black.cgColor
        mask.lineWidth = 2.0 // Thin stroke as requested
        mask.frame = bounds
        
        gradient.mask = mask
        
        layer.addSublayer(gradient)
        self.borderLayer = gradient
    }

    func setupDebugStuff(configuration: Configuration) {
        let debugMesh = BackdropMeshHelper.debugMeshShape(
            withGridSize: 80,
            distortionStrength: configuration.lensDistortionStrength,
            bounds: bounds,
            cornerRadius: configuration.cornerRadius
        )
        debugMesh.frame = bounds // Ensure frame matches
        layer.addSublayer(debugMesh)
        self.debugMeshLayer = debugMesh
    }
}
