import Combine
import Foundation
@preconcurrency import Network

@MainActor
final class TrainerBridge: ObservableObject {
  @Published private(set) var status = "Bridge off"
  @Published private(set) var running = false
  @Published private(set) var trainer: TrainerInfo?
  @Published private(set) var port: UInt16?
  var log: ((String) -> Void)?
  private(set) var connectionID: UUID?
  private var listener: NWListener?
  private var client: NWConnection?
  private var stream = TrainerStream()
  private var heartbeat: Timer?
  private let installID: String = {
    if let saved = UserDefaults.standard.string(forKey: "bridgeID") { return saved }
    let value = UUID().uuidString
    UserDefaults.standard.set(value, forKey: "bridgeID")
    return value
  }()

  func start() {
    guard listener == nil else { return }
    do {
      let parameters = NWParameters.tcp
      parameters.includePeerToPeer = true
      let server = try NWListener(using: parameters)
      let records = NWTXTRecord([
        "version": "1", "id": installID, "name": "FreeBikeControl",
        "service-uuids": "d273f680-d548-419d-b9d1-fa0472345229",
        "manufacturer": "FreeBikeControl", "model": "Apple bridge",
      ])
      server.service = NWListener.Service(
        name: "FreeBikeControl", type: "_openbikecontrol._tcp", txtRecord: records)
      listener = server
      status = "Starting…"
      server.stateUpdateHandler = { [weak self, weak server] state in
        MainActor.assumeIsolated {
          guard let self, let server, self.listener === server else { return }
          switch state {
          case .ready:
            self.running = true
            self.port = server.port?.rawValue
            self.status = "Waiting for MyWhoosh"
            self.log?("OpenBikeControl advertised on port \(self.port ?? 0)")
          case .waiting(let error):
            self.status = "Network unavailable: \(error.localizedDescription)"
          case .failed(let error):
            self.stop()
            self.status = "Network error: \(error.localizedDescription)"
            self.log?(self.status)
          default: break
          }
        }
      }
      server.newConnectionHandler = { [weak self] connection in
        MainActor.assumeIsolated { self?.accept(connection) }
      }
      server.start(queue: .main)
    } catch {
      status = error.localizedDescription
      log?(status)
    }
  }

  func stop() {
    heartbeat?.invalidate()
    heartbeat = nil
    client?.cancel()
    client = nil
    connectionID = nil
    listener?.cancel()
    listener = nil
    trainer = nil
    running = false
    port = nil
    stream = TrainerStream()
    status = "Bridge off"
  }

  private func accept(_ connection: NWConnection) {
    // One active riding app; do not let another LAN client silently take over.
    guard client == nil else {
      connection.cancel()
      return
    }
    client = connection
    connectionID = UUID()
    stream = TrainerStream()
    connection.stateUpdateHandler = { [weak self, weak connection] state in
      MainActor.assumeIsolated {
        guard let self, let connection, self.client === connection else { return }
        switch state {
        case .ready:
          self.status = "Connection open, waiting for app information"
          self.send(ControlPacket.status(ready: true))
          self.receive(connection)
          self.heartbeat = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in self?.send(ControlPacket.status(ready: true)) }
          }
        case .failed(let error):
          self.log?("MyWhoosh: \(error.localizedDescription)")
          self.drop(connection)
        case .cancelled: self.drop(connection)
        default: break
        }
      }
    }
    connection.start(queue: .main)
  }

  private func drop(_ connection: NWConnection) {
    guard client === connection else { return }
    client = nil
    connectionID = nil
    trainer = nil
    stream = TrainerStream()
    heartbeat?.invalidate()
    heartbeat = nil
    connection.cancel()
    status = "Waiting for MyWhoosh"
    log?("App disconnected; waiting for a new connection")
  }

  private func receive(_ connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) {
      [weak self, weak connection] data, _, complete, error in
      MainActor.assumeIsolated {
        guard let self, let connection, self.client === connection else { return }
        if let data, !data.isEmpty {
          do {
            for info in try self.stream.append(data) {
              // This bridge is specifically for MyWhoosh.
              guard info.name.lowercased().contains("mywhoosh") else {
                self.log?("Rejected app: \(info.name)")
                self.drop(connection)
                return
              }
              self.trainer = info
              self.status = "\(info.name) \(info.version) connected"
              self.log?(self.status)
            }
          } catch {
            self.log?("Invalid OpenBikeControl packet")
            self.drop(connection)
            return
          }
        }
        if complete || error != nil { self.drop(connection) } else { self.receive(connection) }
      }
    }
  }

  func supports(_ action: RideAction) -> Bool { trainer?.supports(action) == true }

  @discardableResult
  func set(_ action: RideAction, pressed: Bool) -> Bool {
    guard supports(action), client?.state == .ready else { return false }
    send(ControlPacket.button(action, pressed: pressed))
    return true
  }

  private func send(_ data: Data) {
    guard let connection = client else { return }
    connection.send(
      content: data,
      completion: .contentProcessed { [weak self, weak connection] error in
        MainActor.assumeIsolated {
          if let error, let connection {
            self?.log?("Send error: \(error.localizedDescription)")
            self?.drop(connection)
          }
        }
      })
  }
}
