//
//  BackdropMeshHelper.h
//  LiquidGlassComponent
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackdropMeshHelper : NSObject

/**
 Creates a CABackdropLayer with blur filter and optional color adjustments
 @param blurRadius The blur radius
 @param saturation Optional saturation override (default 1.0 if nil)
 @param brightness Optional brightness override (default 0.0 if nil)
 @return Configured CABackdropLayer
 */
+ (CALayer *)createBackdropLayerWithBlurRadius:(CGFloat)blurRadius
                                    saturation:(nullable NSNumber *)saturation
                                    brightness:(nullable NSNumber *)brightness
                                   bleedAmount:(nullable NSNumber *)bleedAmount;

/**
 Updates an existing CABackdropLayer with new filter values
 @param layer The layer to update
 @param blurRadius The blur radius
 @param saturation Optional saturation override
 @param brightness Optional brightness override
 */
+ (void)updateBackdropLayer:(CALayer *)layer
             withBlurRadius:(CGFloat)blurRadius
                 saturation:(nullable NSNumber *)saturation
                 brightness:(nullable NSNumber *)brightness
                bleedAmount:(nullable NSNumber *)bleedAmount;

/**
 Creates a lens distortion mesh transform
 @param gridSize Number of subdivisions in each dimension (e.g., 20 for 20x20
 grid)
 @param distortionStrength Strength of the lens effect (0.0 to 1.0, typical:
 0.5)
 @param bounds The bounds of the view to apply the transform to
 @return CAMeshTransform with lens distortion, or nil if unavailable
 */
+ (nullable id)createLensDistortionMeshWithGridSize:(NSInteger)gridSize
                                 distortionStrength:(CGFloat)distortionStrength
                                             bounds:(CGRect)bounds
                                       cornerRadius:(CGFloat)cornerRadius;

/**
 Creates a lens distortion mesh transform with custom center point
 @param gridSize Number of subdivisions in each dimension (e.g., 20 for 20x20
 grid)
 @param distortionStrength Strength of the lens effect (0.0 to 1.0, typical:
 0.5)
 @param bounds The bounds of the view to apply the transform to
 @param center The center point of distortion in normalized coordinates (0.0
 to 1.0)
 @param cornerRadius The corner radius of the view (in points)
 @return CAMeshTransform with lens distortion, or nil if unavailable
 */
+ (nullable id)createLensDistortionMeshWithGridSize:(NSInteger)gridSize
                                 distortionStrength:(CGFloat)distortionStrength
                                             bounds:(CGRect)bounds
                                             center:(CGPoint)center
                                       cornerRadius:(CGFloat)cornerRadius;

/**
 Creates an optimized lens distortion mesh using adaptive topology (dense edges,
 sparse center) and caching.
 @param config Dictionary configuration
 @return Cached or new CAMeshTransform
 */
+ (nullable id)
    createOptimizedLensDistortionMeshWithDistortionStrength:
        (CGFloat)distortionStrength
                                                     bounds:(CGRect)bounds
                                               cornerRadius:
                                                   (CGFloat)cornerRadius
                                             cornerSegments:
                                                 (NSInteger)cornerSegments
                                              backdropScale:
                                                  (CGFloat)backdropScale
                                          distortionPadding:
                                              (CGFloat)distortionPadding
                                       distortionMultiplier:
                                           (CGFloat)distortionMultiplier
                                         distortionExponent:
                                             (CGFloat)distortionExponent;

/**
 Creates a CAShapeLayer visualizing the mesh grid
 */
+ (CAShapeLayer *)debugMeshShapeWithGridSize:(NSInteger)gridSize
                          distortionStrength:(CGFloat)distortionStrength
                                      bounds:(CGRect)bounds
                                cornerRadius:(CGFloat)cornerRadius;

@end

NS_ASSUME_NONNULL_END
