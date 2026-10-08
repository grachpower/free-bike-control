import Combine
@preconcurrency import CoreBluetooth
import Foundation

struct ClickDevice: Identifiable {
  let id: UUID
  var name: String
  var state: String = "Discovered"
  var battery: Int?
  var firmware = ""
  var inputReceived = false
  var connected = false
}

@MainActor
final class ClickBluetooth: NSObject, ObservableObject, CBCentralManagerDelegate,
  CBPeripheralDelegate
{
  @Published private(set) var status = "Bluetooth not started"
  @Published private(set) var devices: [ClickDevice] = []
  @Published private(set) var scanning = false
  var log: ((String) -> Void)?
  var onButtons: ((UUID, Set<ClickButton>) -> Void)?
  private var central: CBCentralManager?
  private var peripherals: [UUID: CBPeripheral] = [:]
  private var writers: [UUID: CBCharacteristic] = [:]
  private var pendingNotifications: [UUID: Set<CBUUID>] = [:]
  private var wanted = Set<UUID>()
  private var wantsScan = false
  private var handshakeSent = Set<UUID>()
  private static let services = [
    CBUUID(string: "FC82"), CBUUID(string: "00000001-19CA-4651-86E5-FA29DCDD09D1"),
  ]
  private static let asyncUUID = CBUUID(string: "00000002-19CA-4651-86E5-FA29DCDD09D1")
  private static let writeUUID = CBUUID(string: "00000003-19CA-4651-86E5-FA29DCDD09D1")
  private static let syncUUID = CBUUID(string: "00000004-19CA-4651-86E5-FA29DCDD09D1")

  func startScan() {
    wantsScan = true
    if central == nil {
      central = CBCentralManager(
        delegate: self, queue: .main,
        options: [CBCentralManagerOptionRestoreIdentifierKey: "FreeBikeControl.Click"])
    } else if central?.state == .poweredOn {
      scan()
    }
  }

  private func scan() {
    central?.scanForPeripherals(
      withServices: Self.services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    scanning = true
    status = "Scanning for Click V2… Press a button on your controller"
  }

  func stopScan() {
    wantsScan = false
    central?.stopScan()
    scanning = false
  }

  func connect(_ id: UUID) {
    guard let peripheral = peripherals[id], central?.state == .poweredOn else { return }
    wanted.insert(id)
    update(id) { $0.state = "Connecting…" }
    central?.connect(peripheral)
  }

  func disconnect(_ id: UUID) {
    wanted.remove(id)
    if let peripheral = peripherals[id] { central?.cancelPeripheralConnection(peripheral) }
  }

  func stop() {
    stopScan()
    wanted.removeAll()
    for peripheral in peripherals.values where peripheral.state != .disconnected {
      central?.cancelPeripheralConnection(peripheral)
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      status = "Bluetooth is on"
      if wantsScan { scan() }
    case .poweredOff:
      status = "Turn on Bluetooth"
      scanning = false
      resetInputs()
    case .unauthorized:
      status = "Allow Bluetooth access in Privacy settings"
      scanning = false
      resetInputs()
    case .unsupported:
      status = "Bluetooth LE unavailable"
      resetInputs()
    default:
      status = "Bluetooth is starting…"
      resetInputs()
    }
  }

  private func resetInputs() {
    writers.removeAll()
    handshakeSent.removeAll()
    pendingNotifications.removeAll()
    for id in peripherals.keys {
      onButtons?(id, [])
      update(id) {
        $0.connected = false
        $0.inputReceived = false
        $0.state = "Not connected"
      }
    }
  }

  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
    for peripheral in restored {
      register(peripheral)
      wanted.insert(peripheral.identifier)
      peripheral.delegate = self
      if peripheral.state == .connected { prepare(peripheral) } else { central.connect(peripheral) }
    }
  }

  func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    let name =
      advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
    let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    let bytes = manufacturer.map(Array.init) ?? []
    let isClick =
      bytes.count >= 3 && bytes[0] == 0x4a && bytes[1] == 0x09 && [0x0a, 0x0b].contains(bytes[2])
    guard name.localizedCaseInsensitiveContains("click") || isClick else { return }
    register(peripheral, name: name.isEmpty ? "Zwift Click V2" : name)
  }

  private func register(_ peripheral: CBPeripheral, name: String? = nil) {
    peripherals[peripheral.identifier] = peripheral
    if !devices.contains(where: { $0.id == peripheral.identifier }) {
      devices.append(
        ClickDevice(id: peripheral.identifier, name: name ?? peripheral.name ?? "Zwift Click V2"))
      log?("Discovered \(devices.last!.name)")
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    guard wanted.contains(peripheral.identifier) else {
      central.cancelPeripheralConnection(peripheral)
      return
    }
    prepare(peripheral)
  }

  private func prepare(_ peripheral: CBPeripheral) {
    peripheral.delegate = self
    handshakeSent.remove(peripheral.identifier)
    writers.removeValue(forKey: peripheral.identifier)
    update(peripheral.identifier) {
      $0.connected = true
      $0.inputReceived = false
      $0.state = "Discovering services…"
    }
    peripheral.discoverServices(nil)
  }

  func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    update(peripheral.identifier) { $0.state = "Connection failed" }
    log?(error?.localizedDescription ?? "Click isn't responding")
    retry(peripheral)
  }

  func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
  ) {
    let id = peripheral.identifier
    writers.removeValue(forKey: id)
    handshakeSent.remove(id)
    pendingNotifications.removeValue(forKey: id)
    onButtons?(id, [])
    update(id) {
      $0.connected = false
      $0.inputReceived = false
      $0.state = "Disconnected"
    }
    log?("\(peripheral.name ?? "Click") disconnected")
    retry(peripheral)
  }

  private func retry(_ peripheral: CBPeripheral) {
    let id = peripheral.identifier
    guard wanted.contains(id) else { return }
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard let self, self.wanted.contains(id), self.central?.state == .poweredOn,
        peripheral.state == .disconnected
      else { return }
      self.central?.connect(peripheral)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard error == nil else {
      fail(peripheral, error!.localizedDescription)
      return
    }
    let services = peripheral.services ?? []
    guard services.contains(where: { Self.services.contains($0.uuid) }) else {
      fail(
        peripheral,
        "Click service is hidden. Connect the controllers in Zwift, then close Zwift and try again."
      )
      return
    }
    for service in services
    where Self.services.contains(service.uuid)
      || [CBUUID(string: "180F"), CBUUID(string: "180A")].contains(service.uuid)
    {
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
  ) {
    guard error == nil else {
      fail(peripheral, error!.localizedDescription)
      return
    }
    let characteristics = service.characteristics ?? []
    if Self.services.contains(service.uuid) {
      guard let writer = characteristics.first(where: { $0.uuid == Self.writeUUID }),
        characteristics.contains(where: { $0.uuid == Self.asyncUUID }),
        characteristics.contains(where: { $0.uuid == Self.syncUUID })
      else {
        fail(peripheral, "Click characteristics not found")
        return
      }
      writers[peripheral.identifier] = writer
      let notifications = characteristics.filter {
        $0.uuid == Self.asyncUUID || $0.uuid == Self.syncUUID
      }
      pendingNotifications[peripheral.identifier] = Set(notifications.map(\.uuid))
      for characteristic in notifications { peripheral.setNotifyValue(true, for: characteristic) }
    }
    for characteristic in characteristics
    where [CBUUID(string: "2A19"), CBUUID(string: "2A26")].contains(characteristic.uuid) {
      if characteristic.properties.contains(.read) { peripheral.readValue(for: characteristic) }
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard error == nil, characteristic.isNotifying else {
      fail(peripheral, error?.localizedDescription ?? "Notification subscription inactive")
      return
    }
    let id = peripheral.identifier
    pendingNotifications[id]?.remove(characteristic.uuid)
    if pendingNotifications[id]?.isEmpty == true, !handshakeSent.contains(id),
      let writer = writers[id]
    {
      handshakeSent.insert(id)
      write(
        Data("RideOn".utf8) + Data([0x02, 0x03]), peripheral: peripheral, characteristic: writer)
      update(id) { $0.state = "Connected · press a button to test" }
    }
  }

  private func write(_ data: Data, peripheral: CBPeripheral, characteristic: CBCharacteristic) {
    let type: CBCharacteristicWriteType =
      characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
    if type == .withoutResponse && !peripheral.canSendWriteWithoutResponse { return }
    peripheral.writeValue(data, for: characteristic, type: type)
  }

  func peripheral(
    _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    if let error { fail(peripheral, error.localizedDescription) }
  }

  func peripheral(
    _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    guard error == nil, let data = characteristic.value else {
      if let error { log?(error.localizedDescription) }
      return
    }
    let id = peripheral.identifier
    if characteristic.uuid == CBUUID(string: "2A19"), let value = data.first {
      update(id) { $0.battery = value <= 100 ? Int(value) : nil }
      return
    }
    if characteristic.uuid == CBUUID(string: "2A26") {
      update(id) { $0.firmware = String(decoding: data, as: UTF8.self) }
      return
    }
    do {
      if let buttons = try ClickDecoder.buttons(data) {
        update(id) {
          $0.inputReceived = true
          $0.state = "Button input ready"
        }
        onButtons?(id, buttons)
      } else if data.first == 0x19 {
        let fields = try ProtobufFields.varints(Data(data.dropFirst()))
        if let battery = fields[2], battery <= 100 { update(id) { $0.battery = Int(battery) } }
      } else if data.starts(with: [0xff, 0x05]) {
        onButtons?(id, [])
        update(id) {
          $0.inputReceived = false
          $0.state = "Controller locked · activate it in Zwift"
        }
        log?("Click stopped sending button input; Zwift activation required")
      }
    } catch {
      log?(
        "Couldn't decode Click packet: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))"
      )
    }
  }

  private func fail(_ peripheral: CBPeripheral, _ message: String) {
    update(peripheral.identifier) { $0.state = message }
    log?(message)
  }

  private func update(_ id: UUID, _ change: (inout ClickDevice) -> Void) {
    guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
    change(&devices[index])
  }
}
