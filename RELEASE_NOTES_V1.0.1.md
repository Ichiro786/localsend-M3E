# LocalSend M3E v1.0.1

| Release field | Value |
| --- | --- |
| Release version | 1.0.1 |
| Android versionCode | 65 (652 for ARMv7, 653 for ARM64) |
| Release date | To be set when the signed GitHub Release is published |

LocalSend M3E v1.0.1 refines the Material 3 Expressive interface and improves navigation, discovery, and transfer reliability.

## UI/UX improvements

- **Pixel-style frosted navigation:** a floating glass surface blurs the actual page content behind it. Removed the opaque strip that cut off content above the bar.
- **Refined navigation highlight:** an animated selected-tab pill with corner curvature aligned to the outer navbar, consistent icon colors, and labels that adapt to larger text.
- **Redesigned Send picker tiles:** File, Media, Paste, Text, Folder, and App use rounded cards, circular icon backgrounds, gentle press feedback, and an adaptive two- or three-column layout.
- **Improved Nearby Devices controls:** a live device count and a clearer layout for scanning, manual sending, favourites, and send-mode selection.
- **Quick history access:** a history shortcut in the Send-page header.
- **Clearer file-selection controls:** improved spacing and wrapping for selection details, thumbnails, and Add/Edit actions.
- **Elevated Settings presentation:** grouped rounded cards, section descriptions, consistent icon containers, expressive switches, and controls that reposition on narrow screens.
- **Better device-name display:** long names stay on one line with an ellipsis in the summary, while editing keeps the full value available.
- **Rounded popup menus:** consistent surfaces, outlines, and corner styling across scan, send-mode, and other popup menus.
- **Consistent theme colors:** improved icon, tile, selector, and navigation-highlight colors, including a neutral AMOLED palette and visible selector outlines.
- **Restored AMOLED globes:** visible morphing background shapes on the black OLED canvas, with subtler backgrounds on Send and Settings.
- **Improved layout and accessibility:** better long-text and right-to-left layouts, labelled controls and selected-tab semantics, and scroll clearance so bottom content remains reachable.
- **System-aware motion:** transitions, press feedback, and background animation follow the system's motion accessibility preference.

## Navigation

- Fixed the selected navigation indicator becoming stuck or losing synchronization after background/resume and layout changes.
- Prevented duplicate Home screens and conflicting page-controller attachments after Quick Save.
- Android Back from Send or Settings returns to Receive. Back from Receive follows normal system exit behavior.
- Improved animation disposal and prevented stale asynchronous motion updates.

## Sending and receiving

- Completed receives remain visible until explicitly dismissed, including Quick Save, favourite-device Quick Save, and automatic browser-upload acceptance.
- Auto Finish continues to close completed outgoing sends only.
- Consecutive receives retain their own confirmations. Dismissing an older result does not cancel a newer transfer.
- Corrected route handling when sending and receiving overlap, preserving the parent Share via Link screen when a receive confirmation is dismissed.
- Protected cancellation, retries, permission requests, and completion state from obsolete transfer events.
- Fixed concurrent history writes losing entries. Slow or failed history saving no longer blocks receive confirmation.
- Fixed zero-byte progress crashes and receipt cleanup errors.
- Corrected receive destination handling for symlinked save folders.
- Kept the sending list scrollable with Advanced options open and corrected zero-padding when renaming selected files.

## Discovery and compatibility

- Restored HTTPS interoperability with protocol v2 peers that do not present client certificates.
- Stopped multicast response loops and corrected stale discovery configuration.
- Improved transfer connection resilience.
- Fixed a startup crash when the executable path cannot be resolved.

## Android downloads

| Architecture | APK |
| --- | --- |
| ARM64, 64-bit | `LocalSend-1.0.1-arm64-v8a.apk` |
| ARMv7, 32-bit | `LocalSend-1.0.1-armeabi-v7a.apk` |

Both APKs use optimized release builds and the existing M3E signing key. The application ID remains `com.localsend.m3e`.

## Verification

The included changes passed formatting, both Flutter analyzers, 171 app tests, 19 isolate tests, and 141 Rust tests with Clippy. Four existing native integration tests remain skipped. Lifecycle simulation covers repeated background/resume cycles and backgrounding during navigation animation.


Physical Android installation, system permissions, and real LAN transfers depend on device and OS behavior; CI lifecycle simulations do not replace device testing.
