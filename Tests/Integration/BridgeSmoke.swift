import Foundation
import Network

// Standalone integration check using the production TCP server and a local client.
@main
struct BridgeSmoke {
  @MainActor
  static func main() async throws {
    let bridge = TrainerBridge()
    bridge.start()
    defer { bridge.stop() }
    for _ in 0..<500 {
      if bridge.running { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    guard let port = bridge.port else { fatalError("Listener did not start: \(bridge.status)") }
    let connection = NWConnection(
      host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    connection.start(queue: .main)
    defer { connection.cancel() }
    for _ in 0..<500 {
      if connection.state == .ready { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    guard connection.state == .ready else { fatalError("Client not connected") }
    let info = Data([4, 1, 8] + Array("mywhoosh".utf8) + [3] + Array("5.0".utf8) + [2, 1, 2])
    connection.send(content: Data(info.prefix(5)), completion: .idempotent)
    try await Task.sleep(for: .milliseconds(25))
    precondition(bridge.trainer == nil, "Partial frame interpreted as complete")
    connection.send(content: Data(info.dropFirst(5)), completion: .idempotent)
    for _ in 0..<500 {
      if bridge.trainer != nil { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    precondition(bridge.trainer?.name == "mywhoosh")
    precondition(!bridge.set(.camera, pressed: true), "Unsupported action must not be sent")
    precondition(bridge.set(.shiftUp, pressed: true))
    precondition(bridge.set(.shiftUp, pressed: false))
    var received = Data()
    let timeout = Task { @MainActor in
      try await Task.sleep(for: .seconds(5))
      connection.cancel()
    }
    defer { timeout.cancel() }
    while received.count < 9 {
      let chunk: Data = try await withCheckedThrowingContinuation { continuation in
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) {
          data, _, complete, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let data, !data.isEmpty {
            continuation.resume(returning: data)
          } else {
            continuation.resume(throwing: CocoaError(.fileReadUnknown))
          }
        }
      }
      received.append(chunk)
    }
    precondition(
      received == Data([2, 255, 1, 1, 1, 1, 1, 1, 0]),
      "Unexpected wire bytes: \(received as NSData)")
    connection.cancel()
    for _ in 0..<500 {
      if bridge.trainer == nil { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    precondition(bridge.trainer == nil, "Stale trainer after disconnect")
    precondition(bridge.running, "Listener must remain available for reconnection")
    print(
      "PASS: production TCP bridge, fragmented app info, capabilities, exact press/release bytes and disconnect cleanup"
    )
  }
}
