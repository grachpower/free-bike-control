# FreeBikeControl

A native SwiftUI bridge from Zwift Click V2 to MyWhoosh for macOS, iPhone and iPad.

## Roadmap

The [backlog](BACKLOG.md) lists priorities, dependencies, acceptance criteria and the validation matrix for Mac, iPhone and iPad. Pick the next iteration by task ID. The virtual drivetrain editor is available; applying its ratios to MyWhoosh or the trainer remains part of FBC-023, FBC-019 and FBC-025.

## Getting started

To run independently on your Mac, build a Release artifact with `bash scripts/build-macos.sh` from this directory. The ZIP is saved to `artifacts/FreeBikeControl-macOS.zip`. Extract it, move `freeBikeControl.app` to Applications and open it in Finder. Stop the debug instance in Xcode before launching it. The script verifies the local ad-hoc signature and preserves the required sandbox entitlements. This is a build for your own Mac, without Developer ID signing or notarization for public distribution. Xcode selects the architecture for the current Mac.

1. Open `freeBikeControl.xcodeproj`, select **My Mac** or a physical iPhone/iPad, and click Run. For iOS, check your Team under Signing & Capabilities.
2. Click **Start ride** and allow Bluetooth and local network access.
3. Press a button on a controller, then click **Connect** next to the discovered Click. Bluetooth connection and confirmed button input are shown separately. Check that button presses appear in the log.
4. In the current version of MyWhoosh, open the pairing screen, select **OpenBikeControl** and confirm the **FreeBikeControl** connection.
5. Connect your trainer directly to MyWhoosh as the power source / controllable trainer. Enable virtual shifting in the game settings and start a ride.
6. Test the on-screen shifting buttons in FreeBikeControl, then the physical Click buttons.

The bridge and MyWhoosh can run on the same Mac or on separate devices on the same local network. On a single iPhone/iPad, establish connections in FreeBikeControl first, then open MyWhoosh. iOS declares the `bluetooth-central` background mode and Core Bluetooth state restoration; operation during a long ride has not yet been verified on a device. Do not force-quit the bridge.

## Configuring a virtual cassette

Under **Settings → Bike profile**, enter your chainrings (for example, `46, 30`) and the complete cassette tooth sequence in ascending order. Commas, spaces, `;` and `/` are accepted. The number of sprockets determines the rear gear count; you can configure 1–30 rear gears and 1–3 chainrings.

The user's cassette range is confirmed as 11–36, but the intermediate sprockets are still unknown, so the cassette field starts empty. The `11–36` range does not replace the complete sequence. Choose separate or sequential shifting, select a starting gear and click **Save profile**. Expand the table to see ratios and gear steps. In sequential mode, combinations are sorted from easiest to hardest; equal ratios are retained.

**This is currently a saved configuration and preview.** The profile does not yet control MyWhoosh gears or KICKR CORE 2 resistance. Physical Click controllers continue to use their existing command mappings. The next task is to verify a transport for applying gear ratios.

## Click V2

The current digital `0x23` format is supported, using an active-low protobuf bitmap. Service UUIDs include `FC82` and the legacy Zwift custom service. The app subscribes to notifications before the handshake and does not consider a controller ready until a button packet is received. Repeated packets do not repeat commands. Disconnecting releases buttons; held input is not replayed after reconnection.

The left Click V2 may require daily activation through Zwift. Connect both controllers in Zwift and confirm that they work, then close Zwift to release Bluetooth and connect them here. Whether activation persists depends on the firmware and is not guaranteed. If the left controller is unavailable, connect the right one and enable **Right controller only: + shifts up, B shifts down**.

Automatic Zwift activation and a dedicated Click V2 keep-awake mechanism are **not implemented**. If a controller stops sending button input, wake it with a button press and check the log. On some firmware versions, paired controllers may appear as a single Bluetooth connection. Verify input from both controllers rather than counting devices in the list.

## Interface

The interface, hints, messages and permission descriptions are in English.

The **Ride** screen shows connection steps, diagrams of both Click controllers with physical button highlights, MyWhoosh status and supported test commands. Tapping a diagram button opens its mapping. Cards use two columns on Mac and a wide iPad, and one column on narrower screens.

**Settings** contains button mappings and the saved bike profile; **Diagnostics** contains devices and the event log. The next-step hint follows the current connection state. MyWhoosh manages gears by default; the custom profile editor is optional and currently provides a preview.

## Features

- Discovery, manual connection and automatic reconnection of selected controllers.
- Gear shifting and other commands advertised as supported by MyWhoosh.
- Saved button mappings and right-controller mode.
- An OpenBikeControl TCP server with Bonjour, app information and capability checks.
- On-screen test buttons and a bounded diagnostic log.

This is an initial version, not a complete replacement for BikeControl. It does not independently control trainer resistance, record workouts, confirm gear changes in the game or display a made-up gear number. The drivetrain editor is implemented, but applying its ratios to resistance is not. Other controllers, older bitmap formats and the encrypted protocol are not implemented. Real Click V2 hardware, its firmware and MyWhoosh need testing on each target platform. The iOS Simulator is unsuitable for Bluetooth testing.

## Validation

Current deployment targets in the Xcode project are iOS 26.2 and macOS 15.7.

Run from this directory:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /tmp/freebike-core-tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project freeBikeControl.xcodeproj -scheme freeBikeControl -destination 'platform=macOS' -derivedDataPath /tmp/freebike-build CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project freeBikeControl.xcodeproj -scheme freeBikeControl -destination 'generic/platform=iOS' -derivedDataPath /tmp/freebike-ios-build CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library freeBikeControl/ControlProtocol.swift freeBikeControl/TrainerBridge.swift Tests/Integration/BridgeSmoke.swift -o /tmp/freebike-bridge-smoke
/tmp/freebike-bridge-smoke
```

21 unit tests cover button bitmaps, malformed protobuf packets, fragmented and coalesced TCP messages, capabilities, repeated notifications, held buttons during reconnection or remapping, and drivetrain calculations and persistence. A separate integration test runs the production TCP bridge and a local client, verifying exact press/release bytes and cleanup after disconnection. These checks do not confirm compatibility with physical controllers or MyWhoosh.

## Protocol references

The Swift implementation was written for this project. BikeControl is not included as a library; public materials were used to cross-check protocol UUIDs, the handshake and current bit positions.

- [OpenBikeControl specification](https://github.com/OpenBikeControl/openbikecontrol-protocol) — MIT.
- [Click V2 transport reference](https://github.com/OpenBikeControl/bikecontrol/tree/main/lib/bluetooth/devices/zwift).
- [Core Bluetooth background processing](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html).

FreeBikeControl is not affiliated with Zwift, MyWhoosh or the developers of BikeControl.
