# FreeBikeControl backlog

The goal is to reliably control MyWhoosh gears and supported functions using two Zwift Click V2 controllers on Mac, iPhone and iPad, with the option to configure a virtual drivetrain for the user's bike, including GRX 400. The initial version builds, but compatibility with real controllers, MyWhoosh and sustained iOS operation is not yet confirmed. The next milestone is one complete ride with shifting in both directions, followed by validation of every target scenario.

Updated: October 8, 2026.

## Implemented so far

This is the starting point for further development, not a list of hardware-verified features.

- A SwiftUI app for macOS and iOS/iPadOS.
- Click V2 discovery, manual connection, subscriptions and handshake; reconnection attempts after a disconnect.
- Decoding of the current digital button bitmap, repeated packet handling and button releases.
- An OpenBikeControl TCP bridge with Bonjour, MyWhoosh app information parsing and supported command detection.
- On-screen test buttons, physical button mappings, saved settings and right-controller “+ / B” mode.
- An event log, Bluetooth/local network permissions and iOS Bluetooth background configuration.
- A ride dashboard with controller diagrams and input highlights, connection hints, separate settings and diagnostics, and adaptation to window width.
- Mac and iOS builds, 21 unit tests and the local TCP bridge integration test have passed.

Automatic Click V2 activation, controller keep-awake, applying configured ratios to resistance and independent trainer resistance control are not yet implemented. The virtual cassette and chainring editor, ratio calculations, modes and profile persistence are implemented.

## Priorities and task tracking

| Priority | Meaning |
| --- | --- |
| P0 | Required to confirm that the core setup works on hardware |
| P1 | Required for reliable everyday riding |
| P2 | Usability and additional features after stabilization |
| P3 | An optional extension to select separately |

Tasks below are **Open** unless a different status is stated. Update them to **In progress**, **Blocked** with a specific reason, or **Done** as work proceeds. A research task may finish by documenting a limitation and a working alternative; that does not automatically close dependent implementation tasks.

Close a task after meeting its acceptance criteria, adding the necessary checks and recording the outcome beside it. For hardware validation, record the date, platform and OS version, MyWhoosh version, Click firmware, trainer model, scenario and result. A successful build is not evidence of hardware compatibility.

## Stage 1: A real ride

### FBC-001 P0 Document hardware and scenarios

**Work:** Record both Click models and firmware, the trainer model and firmware, whether the trainer has a Cog or cassette, chainring tooth counts and the complete cassette sequence to emulate, devices, OS versions and MyWhoosh version. Check whether the controllers appear as two BLE devices or one connection.

**Acceptance:** The equipment record is complete and the first ride scenario is selected. Each row in the matrix below identifies a specific device combination or states that no device is available for testing yet.

### FBC-002 P0 Verify input from both Click V2 controllers

**Work:** Test discovery, subscriptions, handshake, every physical button and button releases. Compare received packets with the decoder; account for paired mode, controller sides and firmware differences. Add raw packet capture for diagnostics if needed.

**Acceptance:** Every button is identified correctly; holding a button does not produce extra shifts, releasing it clears the command, and a malformed packet does not trigger an action. Add tests using real packets for discovered variants.

**Dependencies:** FBC-001.

### FBC-003 P0 Verify shifting in MyWhoosh

**Work:** Test FreeBikeControl discovery in MyWhoosh, the supported command announcement, on-screen test buttons and physical Click input during a ride. Check virtual shifting setup and trainer response in free riding; document ERG workout behavior separately.

**Acceptance:** In the first selected scenario, 20 consecutive presses in each direction produce the expected gear changes without missed or duplicate shifts; resistance changes follow MyWhoosh behavior. The log distinguishes received input, a sent command and an error. Sending a command is not presented as game confirmation.

**Dependencies:** FBC-001, FBC-002.

### FBC-004 P0 Verify background operation on iPhone and iPad

**Work:** Test the bridge on the same device as MyWhoosh and on a separate iPhone/iPad. Test switching apps, locking the bridge device's screen, receiving BLE events and sending TCP commands in the background. If the current mode is insufficient, investigate Apple-supported ways to continue the session.

**Acceptance:** Each claimed mobile scenario lasts 60 minutes, with shifting at the beginning, middle and end. Document limitations; the app and instructions recommend a verified launch workflow. Operation after a user force-quits the app is not promised.

**Dependencies:** FBC-003.

### FBC-005 P0 Verify Click V2 sleep and activation

**Work:** Measure behavior without button presses after 1, 5 and 15 minutes, after turning controllers off and on, and the next day. Test both controllers after connecting through Zwift and the right controller on its own. Investigate a verified keep-awake method if controllers fall asleep.

**Acceptance:** Record the conditions under which button input is available; sleep must not be hidden behind a ready status. Provide a verified way to resume riding and an accurate activation guide. If keep-awake is needed, verify it on the user's hardware and ensure that it does not create button input or repeat initialization while a button is held.

**Dependencies:** FBC-002. Include idle testing in FBC-004.

## Hardware validation matrix

This table is a validation plan. Every result is currently **Not tested**.

| FreeBikeControl bridge | MyWhoosh | What to verify | Result |
| --- | --- | --- | --- |
| Mac | Same Mac | Discovery, input, resistance and a long ride | Not tested |
| iPhone | Mac | Local network, BLE and phone background operation | Not tested |
| Mac | iPad | Discovery on iPad and control from Mac | Not tested |
| iPhone | iPad | Communication between mobile devices and phone background operation | Not tested |
| iPhone | Same iPhone | BLE and TCP while MyWhoosh is in the foreground | Not tested |
| iPad | Same iPad | BLE and TCP while MyWhoosh is in the foreground | Not tested |

Test both controllers and right-controller mode for each available row. Unavailable equipment does not count as a pass. Start with Mac → same Mac, then iPhone → Mac, then the remaining available devices.

## Stage 2: Reliable everyday operation

### FBC-006 P1 Define connection states and errors

**Work:** Introduce explicit states for scanning, connecting, subscribing, handshake, input receipt, locking, recovery and stopping. Add timeouts for incomplete stages; show the cause and a concrete recovery action.

**Acceptance:** Permission denial, a hidden service, no response and a write error do not leave the app connecting indefinitely. Stopping cancels pending actions; a late callback cannot resume the session. State transitions are covered by checks.

### FBC-007 P1 Restore Bluetooth without manual reconfiguration

**Work:** Save selected controllers and connection mode, restore them in a new session and retry connections with bounded backoff. Test Bluetooth being turned off, a controller's battery draining or sleep, and temporarily moving out of range.

**Acceptance:** When a device returns, its connection recovers without remapping buttons. Explicit disconnection or stopping cancels retries. There are no parallel attempts or continuous connection loops with a locked controller.

**Dependencies:** FBC-005, FBC-006.

### FBC-008 P1 Recover network and MyWhoosh connections

**Work:** Test Wi-Fi loss, network changes, restarting MyWhoosh, revoking local network permission and a second TCP client. Add a timeout for clients that connect without sending app information; check Bonjour advertising and behavior after an advertising failure.

**Acceptance:** The bridge resumes advertising and accepts a new connection; a stalled client cannot occupy it indefinitely. Old commands are not sent after recovery. The log shows the reason for the disconnect and the next step.

**Dependencies:** FBC-003, FBC-006.

### FBC-009 P1 Stop and restore the complete session

**Work:** Coordinate the Bluetooth, TCP, heartbeat and button router lifecycles. Test Core Bluetooth restoration after restarting, closing the Mac window, Mac sleep/wake and receiving updated MyWhoosh capabilities during an active session.

**Acceptance:** Stopping releases commands and stops resources. Recovery does not leave BLE running without the network bridge or replay held input. An on-screen test button and a physical button mapped to the same action do not leave the command pressed.

**Dependencies:** FBC-006, FBC-007, FBC-008.

### FBC-010 P1 Measure latency and missed input

**Work:** Record BLE packet receipt and command send times; measure game response during a real ride. Test rapid single presses, simultaneous buttons and gear limits. Determine whether a held button needs repeat commands before adding them.

**Acceptance:** Save results for a sequence of 100 presses and the latency distribution, including the measurement method. No missed input, duplicates or stuck states are detected. Agree on a latency target based on the measurements.

**Dependencies:** FBC-003, FBC-009.

### FBC-011 P1 Export diagnostics

**Work:** Add export of a bounded log with app, OS and firmware versions, connection stages and event timestamps. Provide an optional diagnostic mode for raw packets and sanitize exported identifiers.

**Acceptance:** The report can be saved or shared through the system Share Sheet. It helps diagnose connection issues and contains no unexpected personal data. Diagnostic mode is off by default.

### FBC-012 P1 Establish reproducible builds and regression checks

**Work:** Create one reproducible workflow for unit tests, TCP integration and Mac/iOS builds. Extend lifecycle and dependency checks as FBC-006–009 introduce them. Move these checks to CI when CI is added.

**Acceptance:** One command returns a nonzero exit code for any failure and passes on a clean checkout with Xcode. Keep a short hardware regression guide; tests with real MyWhoosh are not replaced by a mock client.

### FBC-013 P1 Prepare device installation

**Work:** Select minimum OS versions, verify signing and entitlements, build a signed Mac version and install the iOS version on physical iPhone/iPad devices. Prepare an icon, app version and installation guide; choose a way to deliver the next build.

**Acceptance:** The app launches on target devices independently of a manual Xcode run, permissions are requested correctly and the update procedure is documented. Create a separate publication task if TestFlight or the App Store is selected.

**Dependencies:** FBC-004, FBC-012.

## Stage 3: Usability and additional commands

### FBC-014 P2 Guide the user through initial pairing

**Status:** In progress. Dynamic next-step hints, three connection indicators and help are implemented. Their clarity needs testing during a real first connection and mobile scenarios.

**Work:** Provide step-by-step setup for the hardware and both-controller/right-controller modes, permission checks, button input testing and MyWhoosh pairing. Distinguish a discovered device, an established connection and confirmed input; show controller sides when identified.

**Acceptance:** A new user completes setup without reading code and receives an actionable next step when Click is locked or MyWhoosh is missing.

**Dependencies:** FBC-005, FBC-006, FBC-008.

### FBC-015 P2 Provide a convenient button mapping editor

**Status:** In progress. Implemented diagrams of both Click controllers, physical input highlights, mapping edits by tapping a diagram, unsupported command labels and explicit B behavior in right-controller mode. Persistence and reset already work; testing with both controllers is still required.

**Work:** Show both controllers, highlight received input, allow mapping edits by tapping a button and provide both-controller/right-controller profiles. Mark commands unsupported by the connected MyWhoosh version.

**Acceptance:** Settings persist; right-controller mode does not hide B's behavior, and changing profiles while a button is held does not produce an unexpected command. Reset is available.

### FBC-016 P2 Verify additional MyWhoosh commands

**Work:** Test steering, menu, confirm/back, camera, workout intensity and pause. Distinguish commands advertised by the app from those that actually work in each ride mode.

**Acceptance:** Maintain a command matrix by MyWhoosh version and mode; verify every offered feature with a physical button. Explain unsupported commands in the mapping editor.

**Dependencies:** FBC-003, FBC-015.

### FBC-017 P2 Add feedback and a ride mode

**Work:** Add optional sound/vibration on the bridge device, a compact status screen, large controls and VoiceOver support. Consider a Mac menu bar item and an iOS Live Activity after checking platform capabilities.

**Acceptance:** Feedback indicates a sent command, not an unconfirmed gear change. Do not show gear numbers or limits without game data. Features can be disabled and do not interfere with MyWhoosh.

### FBC-018 P2 Simplify activation of both Click V2 controllers

**Work:** Investigate a reproducible Zwift workflow, firmware limitations and persistence of activation. Assess automation; retain a clear manual workflow until feasibility is confirmed.

**Acceptance:** Record research findings, available steps and limitations. If automation is feasible, create a separate task with protocol evidence and hardware acceptance criteria. Research alone does not complete the implementation task.

**Dependencies:** FBC-005.

## A configurable drivetrain for the user's bike

The user's request is to change gear counts and ratios so training feels like riding their own GRX 400 bike. After clarification, built-in MyWhoosh gears take priority; applying a custom profile is deferred. The configuration editor is implemented, but applying the profile to actual shifting and resistance is not.

For the GRX 2×10 configuration with FC-RX600-10, Shimano lists 46/30 chainrings. This is a possible starting profile, not confirmation of the user's bike specification. Actual chainrings and the complete cassette sequence are needed; the 11–36 range alone does not identify every gear. [Shimano specification](https://bike.shimano.com/en-UK/products/components/pdp.P-FC-RX600-10.html).

User equipment: **46/30 chainrings confirmed**; **11–36 bike cassette confirmed**, with its exact model and full tooth sequence still to be clarified. **Wahoo KICKR CORE 2 confirmed**; its firmware version and installed Cog or cassette still need clarification. Use 11–36 for the user's profile; do not guess intermediate sprockets.

Gear ratio is calculated as chainring teeth / rear sprocket teeth. A 2×10 setup has 20 position combinations, but ratios may coincide or be close. Separate front and rear shifting preserves these combinations; sequential mode must explicitly define their order and transitions between chainrings.

### FBC-023 P1 Choose a way to apply custom gear ratios

**Work:** Check the current MyWhoosh settings and interfaces for gear counts, chainring and cassette teeth, or arbitrary ratios. OpenBikeControl describes relative shifting and selection of a gear/chainring/sprocket position, but these commands alone do not transmit a tooth-count table. Check the game's actual capabilities and ways to synchronize the selected position.

**Acceptance:** Select and document a verified path: configuration inside the game, an available configuration interface, or trainer control through FBC-019. Describe each path's limitations. Selecting a gear number must not be presented as applying an arbitrary ratio, and locally limiting the gear count must not be presented as changing MyWhoosh's drivetrain.

**Dependencies:** FBC-001, FBC-003. Research can begin before mobile background operation is stabilized.

**Source:** [OpenBikeControl Gear Shifting](https://github.com/OpenBikeControl/openbikecontrol-protocol/blob/main/PROTOCOL.md).

### FBC-024 P1 Add editable drivetrain profiles

**Status:** In progress. Implemented editable chainring/sprocket teeth, gear counts derived from the sequence length, ratio and step calculations, persistence and restoration of one profile, a starting gear, separate mode and sequential ordering by ratio. Added 7 model and persistence tests; both builds passed. The editor is clearly marked as a preview. The user's full cassette sequence still needs confirmation; arbitrary sequential ordering and multiple named profiles are not implemented. Applying the profile to the trainer remains part of FBC-023/FBC-019/FBC-025.

**Work:** Build a model and editor for chainring/sprocket counts, each tooth count, the ratio table and a custom sequential order. Add a saved bike profile, starting gear and separate front/rear and sequential shifting modes. Prepare an editable GRX 2×10 profile; fill in the exact cassette using the user's equipment.

**Acceptance:** Gear counts match the entered chainrings/sprockets, ratios are calculated accurately, invalid tooth counts are rejected, and settings persist and restore. Show the chainring/sprocket combination, ratio and step between gears. Add tests for calculations, boundaries and equal ratios. If the profile does not yet affect the game/trainer, the interface clearly labels it as configuration/preview.

**Dependencies:** FBC-001. The model can be implemented alongside FBC-023 research; connection to real resistance depends on the research outcome.

### FBC-019 P1 Apply the profile to the trainer if necessary

**Work:** If FBC-023 finds no suitable MyWhoosh interface, investigate and implement a control bridge for the user's Wahoo KICKR CORE 2. Verify available transports and commands on its firmware; Zwift virtual shifting support is not evidence that custom ratios can be applied in MyWhoosh. Account for the trainer protocol, mechanical gearing or Cog, power, cadence, game-provided gradient and connection ownership. Determine how MyWhoosh sends mode and gradient to the bridge and how the bridge sends control and telemetry; prevent simultaneous conflicting commands from the game and app.

**Acceptance:** The profile actually changes resistance on the selected trainer under the same conditions, accounts for gradient and ERG mode, and does not falsify measured power to change virtual speed. Define resistance limits and connection-loss behavior; a ride verifies correct transitions. If profile control is available through MyWhoosh, mark this task “Not required” with the reason instead of implementing an unnecessary transport.

**Dependencies:** FBC-001, FBC-023, FBC-024. This former optional extension was raised from P3 to P1 at the user's request.

### FBC-025 P1 Connect Click input to the profile and verify gear feel

**Work:** Map +/− to the selected shifting mode and separate chainring buttons for 2×10 mode. Test session start, limits, restarting, connection loss and profile changes. Distinguish a locally selected gear from one confirmed by the game/trainer when feedback is unavailable.

**Acceptance:** Changing the gear count limits actual shifts; each gear's ratio is applied through the selected transport and verified on the user's trainer. In 2×10 mode, front and rear gears shift independently; sequential mode follows the configured order. There are no bypassed limits, unexpected changes after reconnection or resistance changes caused merely by opening the editor. The user confirms that gear steps match their bike within the trainer's capabilities; reproducing every sensation of outdoor riding is not promised.

**Dependencies:** FBC-002, FBC-023, FBC-024 and the selected transport; FBC-019 if a trainer bridge is required.

## Optional extensions

These tasks are outside the first stable version. Select them after stages 1 and 2.

| ID | Priority | Area | Selection and acceptance criteria |
| --- | --- | --- | --- |
| FBC-020 | P3 | Other firmware and controllers | Select a specific device or firmware variant. Add a separate decoder/handshake, real packet tests and hardware validation; do not broaden detection by guessing. |
| FBC-021 | P3 | Other cycling apps | Select an app, transport and commands. Completion requires a separate verified feature matrix and a ride with that app. |
| FBC-022 | P3 | Workout recording and Apple Health | Select a power/cadence/heart-rate source and determine whether recording is needed. Completion requires a verified recording with correct units, permissions and no duplicates. |

## Next steps

1. FBC-001 — record the user's hardware.
2. FBC-002 and FBC-003 — receive input and verify actual MyWhoosh shifting on Mac.
3. FBC-005 — test controller idle behavior and daily activation.
4. FBC-004 — complete mobile scenarios and a long ride.
5. FBC-006–009 — fix discovered recovery and lifecycle issues.
6. FBC-010–013 — establish measurements, diagnostics, checks and installation.
7. Custom ratios (FBC-023, FBC-024, FBC-019, FBC-025) are deferred: the user prefers MyWhoosh's built-in drivetrain if it meets their needs. Keep the editor; return to applying profiles only if needed after hardware testing of MyShift.
8. FBC-014–018 — improve setup and additional features through selected tasks.

For the next iteration, specify a task ID, for example, “take FBC-002.” After completing work, update this file and the corresponding limitations in README.
