import Combine
import Foundation

struct RideLog: Identifiable {
  let id = UUID()
  let time = Date()
  let message: String
}

@MainActor
final class RideSession: ObservableObject {
  let bluetooth = ClickBluetooth()
  let bridge = TrainerBridge()
  @Published private(set) var active = false
  @Published private(set) var logs: [RideLog] = []
  @Published private(set) var lastInput = "Press a button on your Click"
  @Published private(set) var pressCount = 0
  @Published private(set) var pressedButtons = Set<ClickButton>()
  private var visualButtons: [UUID: Set<ClickButton>] = [:]
  @Published var rightOnly: Bool {
    didSet {
      UserDefaults.standard.set(rightOnly, forKey: "rightOnly")
      releaseAll()
    }
  }
  @Published private(set) var mappings: [String: UInt8]
  private var router = ButtonRouter()
  private var pulses = Set<RideAction>()
  private var sentActions = Set<RideAction>()
  private var subscriptions = Set<AnyCancellable>()

  init() {
    rightOnly = UserDefaults.standard.bool(forKey: "rightOnly")
    mappings = (UserDefaults.standard.dictionary(forKey: "buttonMappings") as? [String: Int] ?? [:])
      .compactMapValues(UInt8.init(exactly:))
    bluetooth.log = { [weak self] in self?.log($0) }
    bridge.log = { [weak self] in self?.log($0) }
    bluetooth.onButtons = { [weak self] id, buttons in self?.handle(id, buttons) }
    bluetooth.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(
      in: &subscriptions)
    bridge.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(
      in: &subscriptions)
    bridge.$trainer.sink { [weak self] _ in
      // Do not replay an already held button into a new training session.
      self?.sentActions.removeAll()
      _ = self?.router.suspendHeldInputs()
      self?.pulses.removeAll()
    }.store(in: &subscriptions)
  }

  func start() {
    active = true
    bridge.start()
    bluetooth.startScan()
    log("Session started")
  }

  func stop() {
    releaseAll()
    bluetooth.stop()
    bridge.stop()
    active = false
    pressedButtons.removeAll()
    visualButtons.removeAll()
    log("Session stopped")
  }

  func action(for button: ClickButton) -> RideAction {
    if rightOnly && button == .b { return .shiftDown }
    return mappings[button.rawValue].flatMap(RideAction.init(rawValue:)) ?? button.defaultAction
  }

  func map(_ button: ClickButton, to action: RideAction) {
    releaseAll()
    mappings[button.rawValue] = action.rawValue
    UserDefaults.standard.set(mappings.mapValues(Int.init), forKey: "buttonMappings")
  }

  func resetMappings() {
    releaseAll()
    mappings = [:]
    UserDefaults.standard.removeObject(forKey: "buttonMappings")
  }

  private func handle(_ id: UUID, _ buttons: Set<ClickButton>) {
    guard active else { return }
    visualButtons[id] = buttons
    pressedButtons = Set(visualButtons.values.flatMap { $0 })
    let mapping = Dictionary(
      uniqueKeysWithValues: ClickButton.allCases.map { ($0, action(for: $0)) })
    let result = router.update(device: id, buttons: buttons) { mapping[$0]! }
    if !result.pressed.isEmpty {
      pressCount += result.pressed.count
      lastInput = result.pressed.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(
        separator: ", ")
      log("Click: \(lastInput)")
    }
    for change in result.changes {
      if change.pressed {
        if bridge.set(change.action, pressed: true) {
          sentActions.insert(change.action)
        } else {
          log("\(change.action.title): MyWhoosh isn't connected or the command isn't supported")
        }
      } else if sentActions.remove(change.action) != nil {
        bridge.set(change.action, pressed: false)
      }
    }
  }

  func test(_ action: RideAction) {
    guard !sentActions.contains(action), !pulses.contains(action), bridge.set(action, pressed: true)
    else { return }
    log("Test: \(action.title)")
    // The release belongs to the same connection; don't send it after reconnection.
    let connectionID = bridge.connectionID
    pulses.insert(action)
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(100))
      guard let self, self.bridge.connectionID == connectionID else { return }
      self.pulses.remove(action)
      guard !self.sentActions.contains(action) else { return }
      self.bridge.set(action, pressed: false)
    }
  }

  private func releaseAll() {
    for action in sentActions { bridge.set(action, pressed: false) }
    sentActions.removeAll()
    _ = router.suspendHeldInputs()
  }

  func log(_ message: String) {
    logs.insert(RideLog(message: message), at: 0)
    if logs.count > 150 { logs.removeLast(logs.count - 150) }
  }
  func clearLogs() { logs.removeAll() }
}
