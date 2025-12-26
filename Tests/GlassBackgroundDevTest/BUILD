load("@build_bazel_rules_apple//apple:ios.bzl",
    "ios_application",
)

load("@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

load(
    "@rules_xcodeproj//xcodeproj:defs.bzl",
    "top_level_target",
    "top_level_targets",
    "xcodeproj",
    "xcode_provisioning_profile",
)

load("@build_bazel_rules_apple//apple:apple.bzl", "local_provisioning_profile")

load(
    "@build_configuration//:variables.bzl",
    "telegram_bazel_path",
)

filegroup(
    name = "AppResources",
    srcs = glob([
        "Resources/**/*",
    ], exclude = ["Resources/**/.*"], allow_empty = True),
)

objc_library(
    name = "BackdropMeshObjC",
    srcs = [
        "Sources/BackdropMeshHelper.m",
    ],
    hdrs = [
        "Sources/BackdropMeshHelper.h",
    ],
    includes = ["Sources"],
    module_map = "Sources/module.modulemap",
    enable_modules = True,
    sdk_frameworks = [
        "QuartzCore",
        "UIKit",
    ],
)

swift_library(
    name = "Lib",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    data = [
        ":AppResources",
    ],
    module_name = "GlassBackgroundDevTest",
    deps = [
        ":BackdropMeshObjC",
        "//submodules/Display",
    ],
)

plist_fragment(
    name = "BuildNumberInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleVersion</key>
    <string>1</string>
    """
)

plist_fragment(
    name = "VersionInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    """
)

plist_fragment(
    name = "AppNameInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleDisplayName</key>
    <string>Glass Dev</string>
    """
)

plist_fragment(
    name = "AppInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleAllowMixedLocalizations</key>
    <true/>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Glass Dev</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UIFileSharingEnabled</key>
    <false/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UIStatusBarStyle</key>
    <string>UIStatusBarStyleDefault</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
    <key>UIViewEdgeAntialiasing</key>
    <false/>
    <key>UIViewGroupOpacity</key>
    <false/>
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>
    """
)

ios_application(
    name = "GlassBackgroundDevTest",
    bundle_id = "ph.telegra.Telegraph",
    families = ["iphone", "ipad"],
    minimum_os_version = "13.0",
    # provisioning_profile = "@build_configuration//provisioning:Telegram.mobileprovision",  # Commented out - let Xcode manage signing
    infoplists = [
        ":AppInfoPlist",
        ":BuildNumberInfoPlist",
        ":VersionInfoPlist",
    ],
    resources = [
        "//Tests/Common:LaunchScreen",
    ],
    frameworks = [
    ],
    deps = [
        "//Tests/Common:Main",
        ":Lib",
    ],
    visibility = ["//visibility:public"],
)

xcodeproj(
    name = "GlassBackgroundDevTest_xcodeproj",
    bazel_path = telegram_bazel_path,
    project_name = "GlassBackgroundDevTest",
    tags = ["manual"],
    top_level_targets = top_level_targets(
        labels = [
            ":GlassBackgroundDevTest",
        ],
        target_environments = ["simulator"],  # Only simulator for now (device needs valid provisioning)
    ),
    xcode_configurations = {
        "Debug": {
            "//command_line_option:compilation_mode": "dbg",
        },
        "Release": {
            "//command_line_option:compilation_mode": "opt",
        },
    },
    default_xcode_configuration = "Debug"
)
