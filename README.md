# WeChat Input Method Liquid Glass tweak (experimental)

Target extension bundle: `com.tencent.wetype.keyboard`  
Target device: iOS 16.6, arm64/arm64e, rootless Theos package.

## What it does
Hooks UIKit keyboard container views in the target keyboard extension and inserts a non-interactive system-material blur behind their content. It keeps the keyboard's existing keys and controls in front.

## Important limitations
- This is source code, not a compiled or device-tested `.deb`.
- The exact view hierarchy of WeChat Input Method 4.0.0 has not been inspected, so this may need adjustment or may have no visible effect.
- A system blur is only a starting approximation; it does not reproduce a custom reference design, animated highlights, borders, or custom key styling.
- The package is rootless. Confirm your RootHide conversion workflow before installing. Remove it immediately if the keyboard becomes unstable.

## Build with Theos
The build environment needs Theos and an iPhoneOS SDK compatible with the selected target. From this folder run:

```sh
make package
```

The package should appear under `packages/`. If your Theos installation uses a different SDK version, adjust `TARGET` in `Makefile` to the installed SDK.

## Workbuddy / GitHub Actions
Open this folder as a Theos project in Workbuddy. The included workflow is a starter workflow, but GitHub-hosted macOS runners do not guarantee an iPhoneOS SDK is present. If the build reports missing SDKs, add a permitted SDK installation step or build in your configured Theos environment. Do not upload or redistribute an SDK unless you have permission.

## Bundle filter
The tweak filter targets only `com.tencent.wetype.keyboard`; it does not target the WeChat main app.
