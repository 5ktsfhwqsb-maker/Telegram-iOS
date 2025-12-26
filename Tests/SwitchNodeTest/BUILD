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

swift_library(
    name = "Lib",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    module_name = "SwitchNodeTest",
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
    ],
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
    <string>Switch Test</string>
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
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
    """
)

ios_application(
    name = "SwitchNodeTest",
    bundle_id = "ph.telegra.SwitchNodeTest",
    families = ["iphone", "ipad"],
    minimum_os_version = "13.0",
    infoplists = [
        ":AppInfoPlist",
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
    name = "SwitchNodeTest_xcodeproj",
    bazel_path = telegram_bazel_path,
    project_name = "SwitchNodeTest",
    tags = ["manual"],
    top_level_targets = top_level_targets(
        labels = [
            ":SwitchNodeTest",
        ],
        target_environments = ["simulator"],
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
