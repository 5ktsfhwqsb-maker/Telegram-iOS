//
//  LiquidASSView.swift
//  LiquidGlassComponent
//
//  Created by whoo on 13.12.2025.
//

import UIKit
import Foundation
import LiquidGlassComponentObjC

public final class LiquidASSView: UIView {

    public struct Configuration {
        public let cornerRadius: CGFloat
        public let blurIntensity: CGFloat
        public let lensDistortionStrength: CGFloat
        public let tintColor: UIColor?
        public let saturation: CGFloat?
        public let brightness: CGFloat?
        public let cornerSegments: Int?
        public let contentScale: CGFloat?
        public let visualZoom: CGFloat?
        public let bleedAmount: CGFloat?
        public let showBorder: Bool
        public let distortionPadding: CGFloat
        public let distortionMultiplier: CGFloat
        public let distortionExponent: CGFloat
        
        public init(
            cornerRadius: CGFloat,
            blurIntensity: CGFloat = 8.0,
            lensDistortionStrength: CGFloat = 0.5,
            tintColor: UIColor? = nil,
            saturation: CGFloat? = 1.0,
            brightness: CGFloat? = 0.0,
            cornerSegments: Int? = nil,
            contentScale: CGFloat? = nil,
            visualZoom: CGFloat? = 1.0,
            bleedAmount: CGFloat? = 10.0,
            showBorder: Bool = true,
            distortionPadding: CGFloat = 2.2,
            distortionMultiplier: CGFloat = 4.5,
            distortionExponent: CGFloat = 5.0
        ) {
            self.cornerRadius = cornerRadius
            self.blurIntensity = blurIntensity
            self.lensDistortionStrength = lensDistortionStrength
            self.tintColor = tintColor
            self.saturation = saturation
            self.brightness = brightness
            self.cornerSegments = cornerSegments
            self.contentScale = contentScale
            self.visualZoom = visualZoom
            self.bleedAmount = bleedAmount
            self.showBorder = showBorder
            self.distortionPadding = distortionPadding
            self.distortionMultiplier = distortionMultiplier
            self.distortionExponent = distortionExponent
        }
    }

    public var isDebugOn: Bool {
        get { debugMeshLayer?.isHidden ?? false }
        set { debugMeshLayer?.isHidden = newValue }
    }

    private weak var debugMeshLayer: CAShapeLayer?
    private weak var borderLayer: CAGradientLayer?
    private weak var tintLayer: CALayer?
    private weak var backdropLayer: CALayer?
    private var configuration: Configuration?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        fatalError()
    }

    public override func layoutSubviews() {
        if let configuration {
            apply(configuration: configuration)
        }
        super.layoutSubviews()
        
    }
    public func apply(configuration: Configuration) {
        self.configuration = configuration
        layer.cornerRadius = configuration.cornerRadius
        
        let scale = configuration.contentScale ?? 1.0
        layer.contentsScale = scale

        let backdrop: CALayer
        if let existing = self.backdropLayer {
            BackdropMeshHelper.updateBackdropLayer(
                existing,
                withBlurRadius: configuration.blurIntensity,
                saturation: configuration.saturation as NSNumber?,
                brightness: configuration.brightness as NSNumber?,
                bleedAmount: configuration.bleedAmount as NSNumber?
            )
            existing.frame = bounds
            existing.contentsScale = scale
            existing.rasterizationScale = scale
            backdrop = existing
        } else {
            let newLayer = BackdropMeshHelper.createBackdropLayer(
                withBlurRadius: configuration.blurIntensity,
                saturation: configuration.saturation as NSNumber?,
                brightness: configuration.brightness as NSNumber?,
                bleedAmount: configuration.bleedAmount as NSNumber?
            )
            newLayer.frame = bounds
            // Insert at bottom to ensure it's behind content/tint
            newLayer.contentsScale = scale
            newLayer.rasterizationScale = scale
            layer.insertSublayer(newLayer, at: 0)
            self.backdropLayer = newLayer
            backdrop = newLayer
        }

        if let meshTransform = BackdropMeshHelper.createOptimizedLensDistortionMesh(
            withDistortionStrength: configuration.lensDistortionStrength,
            bounds: bounds,
            cornerRadius: configuration.cornerRadius,
            cornerSegments: configuration.cornerSegments ?? 0,
            backdropScale: configuration.visualZoom ?? 1.0,
            distortionPadding: configuration.distortionPadding,
            distortionMultiplier: configuration.distortionMultiplier,
            distortionExponent: configuration.distortionExponent
        ) {
            // Apply to backdrop layer instead of container
            backdrop.setValue(meshTransform, forKey: "meshTransform")
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
        guard configuration.showBorder else { return }

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
