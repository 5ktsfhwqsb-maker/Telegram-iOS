load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

objc_library(
    name = "LiquidGlassComponentObjC",
    enable_modules = True,
    module_name = "LiquidGlassComponentObjC",
    srcs = [
        "Sources/BackdropMeshHelper.m",
    ],
    hdrs = [
        "Sources/BackdropMeshHelper.h",
    ],
    copts = [
        "-Wno-deprecated-declarations",
    ],
    visibility = [
        "//visibility:public",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
        "QuartzCore",
    ],
)

swift_library(
    name = "LiquidGlassComponent",
    module_name = "LiquidGlassComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":LiquidGlassComponentObjC",
        "//submodules/UIKitRuntimeUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
