import SwiftUI

private enum RidePage: String, CaseIterable {
  case ride = "Ride"
  case settings = "Settings"
  case diagnostics = "Diagnostics"
  var icon: String {
    switch self {
    case .ride: "bicycle"
    case .settings: "slider.horizontal.3"
    case .diagnostics: "waveform.path.ecg"
    }
  }
}

struct ContentView: View {
  @EnvironmentObject private var session: RideSession
  @StateObject private var gearing = GearingStore()
  @State private var page: RidePage = .ride
  @State private var selectedButton: ClickButton?
  @State private var showHelp = false

  private var inputReady: Bool {
    session.bluetooth.devices.contains { $0.inputReceived && $0.connected }
  }
  private var rideReady: Bool {
    session.active && inputReady && session.bridge.supports(.shiftUp)
      && session.bridge.supports(.shiftDown)
  }

  var body: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width > 820
      VStack(spacing: 0) {
        topBar(wide: wide)
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            switch page {
            case .ride:
              hero
              if wide {
                HStack(alignment: .top, spacing: 22) {
                  controllers.frame(maxWidth: .infinity)
                  VStack(spacing: 22) {
                    network
                    commands
                  }.frame(maxWidth: .infinity)
                }
              } else {
                controllers
                network
                commands
              }
              activity
            case .settings:
              pageHeading("Make it yours", subtitle: "Buttons, controls and your bike profile")
              mapping
              RideCard(title: "Bike profile", icon: "gearshape.2") {
                Label("Using MyWhoosh gears", systemImage: "info.circle")
                  .font(.callout).foregroundStyle(RideTheme.cyan)
                Text(
                  "The custom profile editor below is a preview. You don't need to set it up for a regular ride."
                )
                .font(.callout).foregroundStyle(.secondary)
                GearingView(store: gearing)
              }
            case .diagnostics:
              pageHeading(
                "Connection details", subtitle: "Device status and events from your current session"
              )
              network
              RideCard(title: "Bluetooth", icon: "antenna.radiowaves.left.and.right") {
                Text(session.bluetooth.status).foregroundStyle(.secondary)
                deviceRows
              }
              logCard
            }
          }.padding(wide ? 32 : 18).frame(maxWidth: 1200).frame(maxWidth: .infinity)
        }
      }
      .background(RideTheme.background)
    }
    .preferredColorScheme(.dark)
    .tint(RideTheme.accent)
    .sheet(item: $selectedButton) { button in mappingSheet(button) }
    .sheet(isPresented: $showHelp) { helpSheet }
    #if os(macOS)
      .frame(minWidth: 600, minHeight: 720)
    #endif
  }

  private func topBar(wide: Bool) -> some View {
    VStack(spacing: 18) {
      HStack {
        HStack(spacing: 10) {
          Image("BrandLogo").resizable().scaledToFit().frame(width: 44, height: 30)
            .accessibilityHidden(true)
          Text("FreeBikeControl").font(.system(size: 19, weight: .bold, design: .rounded))
        }
        Spacer()
        if wide { navigation(compact: false) }
        Button {
          showHelp = true
        } label: {
          Image(systemName: "questionmark.circle").font(.title3).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain).accessibilityLabel("How to connect")
      }
      if !wide { navigation(compact: true) }
    }
    .padding(.horizontal, wide ? 32 : 18).padding(.vertical, 18)
    .background(RideTheme.surface.opacity(0.6))
    .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
  }

  private func navigation(compact: Bool) -> some View {
    HStack(spacing: 4) {
      ForEach(RidePage.allCases, id: \.self) { item in
        Button {
          page = item
        } label: {
          Label(item.rawValue, systemImage: item.icon)
            .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
            .padding(.horizontal, compact ? 8 : 14).padding(.vertical, 10)
            .foregroundStyle(page == item ? RideTheme.accent : .secondary)
            .background(page == item ? RideTheme.accent.opacity(0.10) : .clear, in: Capsule())
        }.buttonStyle(.plain)
      }
    }
  }

  private var hero: some View {
    VStack(alignment: .leading, spacing: 22) {
      ViewThatFits(in: .horizontal) {
        HStack {
          heroEyebrow
          Spacer()
          heroStatus
        }
        VStack(alignment: .leading, spacing: 12) {
          heroEyebrow
          heroStatus
        }
      }
      Text(rideReady ? "Ready to ride." : "Connect. Then ride.")
        .font(.system(size: 34, weight: .bold, design: .rounded)).tracking(-1)
      Text(nextStep).font(.callout).foregroundStyle(.secondary).fixedSize(
        horizontal: false, vertical: true)
      ViewThatFits(in: .horizontal) {
        HStack {
          sessionButton
          Spacer()
          connectionSteps
        }
        VStack(alignment: .leading, spacing: 18) {
          sessionButton
          connectionSteps
        }
      }
    }
    .padding(28).frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [RideTheme.surface, RideTheme.cyan.opacity(0.09)], startPoint: .leading,
        endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28)
    )
    .overlay(RoundedRectangle(cornerRadius: 28).stroke(RideTheme.cyan.opacity(0.14), lineWidth: 1))
  }

  private var heroEyebrow: some View {
    Label("YOUR CONTROLS FOR MYWHOOSH", systemImage: "bolt.fill")
      .font(.caption.weight(.bold)).tracking(1).foregroundStyle(RideTheme.cyan)
  }

  private var heroStatus: some View {
    StatusBadge(
      text: rideReady ? "Ready to ride" : session.active ? "Connecting" : "Not started",
      ready: rideReady)
  }

  private var nextStep: String {
    if !session.active {
      return
        "Start a session, connect your Click controllers and open MyWhoosh. The game manages gears and resistance."
    }
    if let device = session.bluetooth.devices.first(where: { !$0.connected }) {
      return "Found \(device.name). Connect it in the controller card below."
    }
    if !inputReady {
      return
        "Press a button on your Click. Connect the discovered controller and check that button presses are received."
    }
    if session.bridge.trainer == nil {
      return "Open the MyWhoosh pairing screen → OpenBikeControl and select FreeBikeControl."
    }
    if !rideReady {
      return
        "MyWhoosh is connected, but shifting isn't available yet. Check virtual shifting in the game."
    }
    return
      "Button input is working and MyWhoosh is connected. Start a ride and check shifting in the game."
  }

  private var sessionButton: some View {
    Button {
      if session.active { session.stop() } else { session.start() }
    } label: {
      Label(
        session.active ? "End session" : "Start ride",
        systemImage: session.active ? "stop.fill" : "play.fill")
    }
    .buttonStyle(RideButtonStyle(prominent: !session.active))
  }

  private var connectionSteps: some View {
    HStack(spacing: 12) {
      step("Session", ready: session.active)
      Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
      step("Click", ready: inputReady)
      Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
      step("MyWhoosh", ready: session.bridge.trainer != nil)
    }
  }

  private func step(_ title: String, ready: Bool) -> some View {
    Label(title, systemImage: ready ? "checkmark.circle.fill" : "circle")
      .font(.caption.weight(.medium)).foregroundStyle(ready ? RideTheme.accent : .secondary)
  }

  private var controllers: some View {
    RideCard(title: "Your Click V2 controllers", icon: "gamecontroller") {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 28) {
          pad(false)
          pad(true)
        }.frame(maxWidth: .infinity)
        HStack(spacing: 12) {
          pad(false, compact: true)
          pad(true, compact: true)
        }.frame(maxWidth: .infinity)
        VStack(spacing: 22) {
          pad(false, compact: true)
          pad(true, compact: true)
        }.frame(maxWidth: .infinity)
      }
      Text(
        "Tap a button on the diagram to change its action. Physical button presses light up here."
      )
      .font(.caption).foregroundStyle(.secondary)
      deviceRows
      HStack {
        if session.bluetooth.scanning { ProgressView().controlSize(.small) }
        Button(session.bluetooth.scanning ? "Stop scanning" : "Find controllers") {
          if session.bluetooth.scanning {
            session.bluetooth.stopScan()
          } else {
            session.bluetooth.startScan()
          }
        }.buttonStyle(RideButtonStyle()).disabled(!session.active)
      }
    }
  }

  private func pad(_ right: Bool, compact: Bool = false) -> some View {
    ControllerPad(
      right: right, compact: compact, pressed: session.pressedButtons, selected: selectedButton
    ) {
      selectedButton = $0
    }
  }

  @ViewBuilder private var deviceRows: some View {
    if session.bluetooth.devices.isEmpty {
      Label(
        session.active
          ? "Wake your controllers by pressing any button"
          : "Controllers will appear once you start a session",
        systemImage: "dot.radiowaves.left.and.right"
      )
      .font(.callout).foregroundStyle(.secondary)
    }
    ForEach(session.bluetooth.devices) { device in
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: device.inputReceived ? "checkmark.circle.fill" : "gamecontroller")
            .foregroundStyle(device.inputReceived ? RideTheme.accent : .secondary)
          Text(device.name).font(.subheadline.weight(.semibold))
          Spacer()
          if let battery = device.battery {
            Label("\(battery)%", systemImage: "battery.100percent").font(.caption)
          }
        }
        Text(device.state).font(.caption).foregroundStyle(.secondary)
        HStack {
          if !device.firmware.isEmpty {
            Text("Firmware \(device.firmware)").font(.caption2).foregroundStyle(.secondary)
          }
          Spacer()
          Button(device.connected ? "Disconnect" : "Connect") {
            if device.connected {
              session.bluetooth.disconnect(device.id)
            } else {
              session.bluetooth.connect(device.id)
            }
          }.buttonStyle(RideButtonStyle(prominent: !device.connected)).disabled(!session.active)
        }
      }.padding(14).background(
        RideTheme.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    }
  }

  private var network: some View {
    RideCard(title: "MyWhoosh", icon: "network") {
      HStack {
        Text(session.bridge.trainer == nil ? "Waiting for MyWhoosh" : "Game connected").font(
          .title2.bold())
        Spacer()
        Image(systemName: session.bridge.trainer == nil ? "wifi" : "checkmark.circle.fill").font(
          .title
        ).foregroundStyle(session.bridge.trainer == nil ? RideTheme.cyan : RideTheme.accent)
      }
      Text(session.bridge.status).font(.callout).foregroundStyle(.secondary)
      if session.bridge.trainer == nil {
        Text(
          "In MyWhoosh: pairing → OpenBikeControl → FreeBikeControl. Use the same network if running on separate devices."
        ).font(.callout).foregroundStyle(.secondary)
      }
      if session.active && !session.bridge.running {
        Button("Retry connection") { session.bridge.start() }.buttonStyle(RideButtonStyle())
      }
      if page == .diagnostics, let port = session.bridge.port {
        Text("TCP · \(String(port))").font(.caption.monospaced()).foregroundStyle(.secondary)
      }
    }
  }

  private var commands: some View {
    RideCard(title: "Test controls", icon: "hand.tap") {
      Text("MyWhoosh gears").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      HStack(spacing: 12) {
        shift(.shiftDown, symbol: "minus", title: "Easier")
        shift(.shiftUp, symbol: "plus", title: "Harder")
      }
      if session.bridge.trainer == nil {
        Text("Controls become available when MyWhoosh connects.").font(.caption).foregroundStyle(
          .secondary)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
        actionButton(.steerLeft, icon: "arrow.turn.up.left")
        actionButton(.steerRight, icon: "arrow.turn.up.right")
        actionButton(.camera, icon: "camera")
        actionButton(.menu, icon: "line.3.horizontal")
        actionButton(.select, icon: "checkmark")
        actionButton(.back, icon: "arrow.uturn.backward")
      }
      Text("The game displays your gear number. These buttons test sending commands.").font(
        .caption
      )
      .foregroundStyle(.secondary)
    }
  }

  private func shift(_ action: RideAction, symbol: String, title: String) -> some View {
    let enabled = session.bridge.supports(action)
    return Button {
      session.test(action)
    } label: {
      VStack(spacing: 10) {
        Image(systemName: symbol).font(.system(size: 27, weight: .medium))
        Text(title).font(.subheadline.weight(.semibold))
      }.frame(maxWidth: .infinity).padding(.vertical, 22)
        .foregroundStyle(enabled ? RideTheme.background : .white.opacity(0.25))
        .background(
          enabled ? RideTheme.accent : RideTheme.elevated, in: RoundedRectangle(cornerRadius: 18))
    }.buttonStyle(.plain).disabled(!enabled)
  }

  private func actionButton(_ action: RideAction, icon: String) -> some View {
    Button {
      session.test(action)
    } label: {
      VStack(spacing: 7) {
        Image(systemName: icon).font(.body)
        Text(action.title).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.75)
      }.frame(maxWidth: .infinity).frame(height: 38)
    }
    .buttonStyle(RideButtonStyle()).disabled(!session.bridge.supports(action))
  }

  private var activity: some View {
    RideCard(title: "Latest input", icon: "waveform") {
      HStack {
        VStack(alignment: .leading, spacing: 8) {
          Text(session.lastInput).font(.headline)
          Text(session.logs.first?.message ?? "Waiting for the first session event").font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(session.pressCount)").font(.system(size: 30, weight: .bold, design: .rounded))
            .monospacedDigit()
          Text("presses").font(.caption).foregroundStyle(.secondary)
        }
      }
      Button("Open diagnostics") { page = .diagnostics }.buttonStyle(.plain).font(
        .caption.weight(.semibold)
      ).foregroundStyle(RideTheme.cyan)
    }
  }

  private var mapping: some View {
    RideCard(title: "Click button mappings", icon: "gamecontroller") {
      Toggle("Right controller only: + shifts up, B shifts down", isOn: $session.rightOnly)
        .toggleStyle(.switch)
      Text(
        "Both controllers may need activation through Zwift. The right controller can shift in both directions on its own."
      ).font(.callout).foregroundStyle(.secondary)
      ForEach(ClickButton.allCases) { button in
        HStack {
          Text(button.title).font(.subheadline)
          Spacer()
          Picker(
            button.title,
            selection: Binding(
              get: { session.action(for: button) }, set: { session.map(button, to: $0) })
          ) {
            ForEach(RideAction.allCases) { Text(mappingTitle($0)).tag($0) }
          }.labelsHidden().frame(maxWidth: 230).disabled(session.rightOnly && button == .b)
        }
        if button != ClickButton.allCases.last { Divider().opacity(0.4) }
      }
      Button("Reset mappings") { session.resetMappings() }.buttonStyle(RideButtonStyle())
    }
  }

  private var logCard: some View {
    RideCard(title: "Event log", icon: "list.bullet.rectangle") {
      HStack {
        Text("\(session.logs.count) events").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("Clear") { session.clearLogs() }.buttonStyle(RideButtonStyle())
      }
      if session.logs.isEmpty {
        Text("Start a session to see connections and button presses here.").foregroundStyle(
          .secondary)
      }
      ForEach(session.logs) { entry in
        HStack(alignment: .top, spacing: 14) {
          Text(entry.time, style: .time).foregroundStyle(RideTheme.cyan)
          Text(entry.message).frame(maxWidth: .infinity, alignment: .leading).textSelection(
            .enabled)
        }.font(.caption.monospaced()).padding(.vertical, 5)
      }
    }
  }

  private func pageHeading(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
      Text(subtitle).font(.callout).foregroundStyle(.secondary)
    }.padding(.vertical, 6)
  }

  private func mappingTitle(_ action: RideAction) -> String {
    if session.bridge.trainer != nil && !session.bridge.supports(action) {
      return "\(action.title) · unavailable in game"
    }
    return action.title
  }

  private func mappingSheet(_ button: ClickButton) -> some View {
    VStack(alignment: .leading, spacing: 22) {
      Text(button.title).font(.title2.bold())
      Text(
        "Choose an action for the physical button. Tapping the diagram doesn't send a command to the game."
      )
      .foregroundStyle(.secondary)
      Picker(
        "Action",
        selection: Binding(
          get: { session.action(for: button) }, set: { session.map(button, to: $0) })
      ) {
        ForEach(RideAction.allCases) { Text(mappingTitle($0)).tag($0) }
      }.disabled(session.rightOnly && button == .b)
      if session.rightOnly && button == .b {
        Text("B shifts down in right-controller mode. You can change this mode in Settings.").font(
          .caption
        ).foregroundStyle(.secondary)
      }
      Button("Done") { selectedButton = nil }.buttonStyle(RideButtonStyle(prominent: true))
    }.padding(28).frame(minWidth: 300).background(RideTheme.surface)
      .presentationDetents([.medium])
  }

  private var helpSheet: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        pageHeading(
          "Let's get riding", subtitle: "Three steps to control your ride from the handlebars")
        helpStep(
          "01", "Start a session",
          "Allow Bluetooth and local network access. Press any button on each Click, then connect the discovered controllers."
        )
        helpStep(
          "02", "Connect MyWhoosh",
          "On the game's pairing screen, open OpenBikeControl and select FreeBikeControl. Connect your trainer directly to the game."
        )
        helpStep(
          "03", "Check shifting",
          "Enable virtual shifting in MyWhoosh, start a ride and test +/−. Use the same network if running on separate devices."
        )
        Text(
          "Click V2 may need activation through Zwift. Background operation on iPhone/iPad still needs device testing; don't force-quit the bridge."
        ).font(.caption).foregroundStyle(.secondary)
        Button("Got it") { showHelp = false }.buttonStyle(RideButtonStyle(prominent: true))
      }.padding(28)
    }.frame(minWidth: 300).background(RideTheme.surface).presentationDetents([.large])
  }

  private func helpStep(_ number: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text(number).font(.title2.bold()).foregroundStyle(RideTheme.accent)
      VStack(alignment: .leading, spacing: 7) {
        Text(title).font(.headline)
        Text(text).font(.callout).foregroundStyle(.secondary)
      }
    }
  }
}

#Preview { ContentView().environmentObject(RideSession()).frame(width: 1150, height: 950) }
