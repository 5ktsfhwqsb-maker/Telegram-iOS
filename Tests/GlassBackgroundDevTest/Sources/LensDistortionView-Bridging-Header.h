//
//  LensDistortionView-Bridging-Header.h
//  GlassBackgroundDevTest
//

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

// Private CABackdropLayer API
@interface CABackdropLayer : CALayer
@property BOOL allowsGroupBlending;
@property BOOL allowsGroupOpacity;
@property BOOL allowsInPlaceFiltering;
@property double scale;
@property (copy) NSString *groupName;
@end

// Vertex structure for CAMeshTransform
typedef struct {
    CGPoint from;    // Source position [0...1]
    CGPoint to;      // Destination position (x, y) [0...1]
    CGFloat z;       // Z depth
} CAMeshVertex;

// Private CAMeshTransform API
@interface CAMeshTransform : NSObject <NSSecureCoding, NSCopying>

+ (instancetype)meshTransformWithVertexCount:(NSUInteger)vertexCount
                                     vertices:(const CAMeshVertex *)vertices
                                    faceCount:(NSUInteger)faceCount
                                        faces:(const unsigned int *)faces
                              depthNormalization:(NSString *)depthNormalization;

@property (readonly) NSUInteger vertexCount;
@property (readonly) NSUInteger faceCount;

@end

// CALayer extension for mesh transform
@interface CALayer (MeshTransform)
@property (nullable, strong) CAMeshTransform *meshTransform;
@end

// Private CAFilter API for blur
@interface CAFilter : NSObject <NSSecureCoding, NSCopying>
+ (instancetype)filterWithType:(NSString *)type;
@property (copy) NSString *name;
@end

@interface CALayer (Filters)
@property (nullable, copy) NSArray<CAFilter *> *filters;
@end
