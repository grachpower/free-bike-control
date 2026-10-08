import Foundation

enum RideAction: UInt8, CaseIterable, Identifiable, Codable {
  case shiftUp = 0x01
  case shiftDown = 0x02
  case up = 0x10
  case down = 0x11
  case select = 0x14
  case back = 0x15
  case menu = 0x16
  case steerLeft = 0x18
  case steerRight = 0x19
  case emote = 0x20
  case intensityUp = 0x30
  case intensityDown = 0x31
  case pause = 0x33
  case camera = 0x40
  var id: UInt8 { rawValue }
  var title: String {
    switch self {
    case .shiftUp: "Shift up"
    case .shiftDown: "Shift down"
    case .up: "Up"
    case .down: "Down"
    case .select: "Confirm"
    case .back: "Back"
    case .menu: "Menu"
    case .steerLeft: "Steer left"
    case .steerRight: "Steer right"
    case .emote: "Emote"
    case .intensityUp: "Increase intensity"
    case .intensityDown: "Decrease intensity"
    case .pause: "Pause"
    case .camera: "Camera"
    }
  }
}

enum ClickButton: String, CaseIterable, Identifiable {
  case minus, plus, left, up, right, down, a, b, y, z
  var id: String { rawValue }
  var title: String {
    switch self {
    case .minus: "Left · −"
    case .plus: "Right · +"
    case .left: "Left · ←"
    case .up: "Left · ↑"
    case .right: "Left · →"
    case .down: "Left · ↓"
    default: "Right · \(rawValue.uppercased())"
    }
  }
  // Current Click V2 digital bitmap; active-low. Older Ride bitmaps differ.
  var mask: UInt64 {
    switch self {
    case .left: 1
    case .up: 2
    case .right: 4
    case .down: 8
    case .a: 0x10
    case .b: 0x20
    case .y: 0x40
    case .z: 0x80
    case .minus: 0x100
    case .plus: 0x1000
    }
  }
  var defaultAction: RideAction {
    switch self {
    case .minus: .shiftDown
    case .plus: .shiftUp
    case .left: .steerLeft
    case .right: .steerRight
    case .up: .up
    case .down: .down
    case .a: .select
    case .b: .back
    case .y: .menu
    case .z: .camera
    }
  }
}

enum WireError: Error { case malformed }

/// Minimal protobuf wire reader. Unknown fields are skipped, never interpreted as buttons.
enum ProtobufFields {
  static func varints(_ data: Data) throws -> [Int: UInt64] {
    let bytes = Array(data)
    var cursor = 0
    func read() throws -> UInt64 {
      var value: UInt64 = 0
      for shift in stride(from: 0, through: 63, by: 7) {
        guard cursor < bytes.count else { throw WireError.malformed }
        let byte = bytes[cursor]
        cursor += 1
        if shift == 63 && byte > 1 { throw WireError.malformed }
        value |= UInt64(byte & 0x7f) << shift
        if byte & 0x80 == 0 { return value }
      }
      throw WireError.malformed
    }
    var result: [Int: UInt64] = [:]
    while cursor < bytes.count {
      let key = try read()
      guard key >> 3 > 0, key >> 3 <= UInt64(Int.max) else { throw WireError.malformed }
      switch key & 7 {
      case 0: result[Int(key >> 3)] = try read()
      case 1: cursor += 8
      case 2:
        let length = try read()
        guard length <= UInt64(bytes.count - cursor) else { throw WireError.malformed }
        cursor += Int(length)
      case 5: cursor += 4
      default: throw WireError.malformed
      }
      guard cursor <= bytes.count else { throw WireError.malformed }
    }
    return result
  }
}

enum ClickDecoder {
  static func buttons(_ packet: Data) throws -> Set<ClickButton>? {
    guard packet.first == 0x23 else { return nil }
    let fields = try ProtobufFields.varints(Data(packet.dropFirst()))
    guard let bitmap = fields[1], bitmap <= UInt64(UInt32.max) else { throw WireError.malformed }
    return Set(ClickButton.allCases.filter { bitmap & $0.mask == 0 })
  }
}

struct TrainerInfo: Equatable {
  let name: String
  let version: String
  let supported: Set<UInt8>
  func supports(_ action: RideAction) -> Bool {
    supported.isEmpty || supported.contains(action.rawValue)
  }
}

/// TCP can split or combine messages; keep a bounded buffer and consume complete frames.
struct TrainerStream {
  private(set) var buffer = [UInt8]()
  mutating func append(_ data: Data) throws -> [TrainerInfo] {
    buffer.append(contentsOf: data)
    guard buffer.count <= 4096 else { throw WireError.malformed }
    var infos: [TrainerInfo] = []
    while let type = buffer.first {
      if type == 0x03 {
        guard buffer.count >= 4 else { break }
        buffer.removeFirst(4)  // Haptics unsupported by Click V2.
        continue
      }
      guard type == 0x04 else { throw WireError.malformed }
      guard buffer.count >= 3 else { break }
      guard buffer[1] == 1, buffer[2] <= 32 else { throw WireError.malformed }
      let nameEnd = 3 + Int(buffer[2])
      guard buffer.count > nameEnd else { break }
      guard buffer[nameEnd] <= 32 else { throw WireError.malformed }
      let versionEnd = nameEnd + 1 + Int(buffer[nameEnd])
      guard buffer.count > versionEnd else { break }
      let end = versionEnd + 1 + Int(buffer[versionEnd])
      guard buffer.count >= end else { break }
      guard let name = String(bytes: buffer[3..<nameEnd], encoding: .utf8),
        let version = String(bytes: buffer[(nameEnd + 1)..<versionEnd], encoding: .utf8)
      else { throw WireError.malformed }
      infos.append(
        TrainerInfo(name: name, version: version, supported: Set(buffer[(versionEnd + 1)..<end])))
      buffer.removeFirst(end)
    }
    return infos
  }
}

enum ControlPacket {
  static func button(_ action: RideAction, pressed: Bool) -> Data {
    Data([0x01, action.rawValue, pressed ? 1 : 0])
  }
  static func status(ready: Bool) -> Data { Data([0x02, 0xff, ready ? 1 : 0]) }
}

struct ActionChange: Equatable {
  let action: RideAction
  let pressed: Bool
}

/// Merges two controllers and suppresses held inputs across reconnects/remapping.
struct ButtonRouter {
  private var devices: [UUID: Set<ClickButton>] = [:]
  private var suppressed: [UUID: Set<ClickButton>] = [:]
  private var actions = Set<RideAction>()

  mutating func update(
    device: UUID, buttons: Set<ClickButton>, mapping: (ClickButton) -> RideAction
  ) -> (pressed: Set<ClickButton>, changes: [ActionChange]) {
    let previous = devices[device] ?? []
    devices[device] = buttons
    suppressed[device] = (suppressed[device] ?? []).intersection(buttons)
    let desired = Set(
      devices.flatMap { id, buttons in
        buttons.subtracting(suppressed[id] ?? []).map(mapping)
      })
    let releases = actions.subtracting(desired).sorted { $0.rawValue < $1.rawValue }.map {
      ActionChange(action: $0, pressed: false)
    }
    let presses = desired.subtracting(actions).sorted { $0.rawValue < $1.rawValue }.map {
      ActionChange(action: $0, pressed: true)
    }
    actions = desired
    return (buttons.subtracting(previous), releases + presses)
  }

  mutating func suspendHeldInputs() -> [ActionChange] {
    let releases = actions.sorted { $0.rawValue < $1.rawValue }.map {
      ActionChange(action: $0, pressed: false)
    }
    actions.removeAll()
    suppressed = devices
    return releases
  }
}
