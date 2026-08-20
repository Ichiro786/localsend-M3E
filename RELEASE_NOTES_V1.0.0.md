# LocalSend M3E v1.0.0

| Release field | Value |
| --- | --- |
| Release version | 1.0.0 |
| Android versionCode | 64 (ABI APK codes: 642 for ARMv7 and 643 for ARM64) |
| Release date | To be set when the signed GitHub Release is published |

LocalSend M3E v1.0.0 is the first public release of the LocalSend M3E fork/revamp. It preserves LocalSend’s networking, discovery, transfer, persistence, settings, permissions, and navigation behavior while introducing the approved Material 3 Expressive presentation system.

## Highlights

- Material 3 Expressive Receive, Send, Settings, and Receive via Link experiences.
- Material You dynamic colors with an OLED-friendly dark visual system.
- Animated expressive background with organic blobs.
- Floating bottom navigation and expressive cards and switches.
- Refined device, selection, action, and transfer presentation across the approved M3E screens.
- Smoother navigation and interactions designed with 120 Hz-capable hardware in mind. No universal 120 FPS guarantee is claimed.

## Performance and reliability

- Consolidated motion tokens for consistent micro, short, standard, entrance, and expressive transitions.
- Replaced the old fixed-rate rotation loop with a vsync-driven animation controller.
- Improved animation lifecycle handling, including slideshow timer cancellation and running-state gating.
- Added coordinated page transitions and aligned initial slide motion with the shared animation settings.
- Kept organic blob clipping reusable and const-friendly where applicable.

## Verified fixes

- Receive via Link overflow.
- Settings control alignment and expressive switch behavior.
- Send-screen action-row spacing above the Nearby Devices surface.
- Settings/send-mode icon optical sizing and action-row geometry.
- Navigation and animation lifecycle issues identified during the M3E redesign.
- Android package identity and release metadata for coexistence and update compatibility.

## Android compatibility and installation

The Android application ID is `com.localsend.m3e`, while the visible application name remains `LocalSend`. This unique package identity allows LocalSend M3E to coexist with the official LocalSend application, which uses a different package identity.

A previous M3E build using versionCode 63 can update normally to v1.0.0 when the APK is signed with the same M3E release key. A change of signing key or application ID is not an in-place update and would require a fresh installation. Existing settings and application data are expected to remain available under a normal signed Android update, subject to device and OS behavior.

## Supported Android architectures

The public Android release contains only the following optimized release APKs:

| Architecture | APK asset |
| --- | --- |
| ARM64 | `LocalSend-1.0.0-arm64-v8a.apk` |
| ARMv7 | `LocalSend-1.0.0-armeabi-v7a.apk` |

No x86 or x86_64 APK is included in the public Android release.

## Attribution and licensing

LocalSend M3E is a fork/revamp of LocalSend. Original LocalSend copyright, licensing, attribution, and third-party dependency obligations remain applicable. The source repository and the tagged source archive provide the corresponding source for this release.

## Known limitations at publication time

The release workflow requires the maintainer’s encrypted Android signing secrets before a production-signed APK can be published. Final installation, upgrade, coexistence, end-to-end transfer, and 120 Hz validation require a physical Android device and are not substituted by CI-only checks.
