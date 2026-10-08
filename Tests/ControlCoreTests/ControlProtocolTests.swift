import XCTest

@testable import ControlCore

final class ControlProtocolTests: XCTestCase {
  // Current V2 wire fixtures, independent of the implementation's masks.
  func testV2ReleasedAndIndividualShiftButtons() throws {
    XCTAssertEqual(try ClickDecoder.buttons(Data([0x23, 0x08, 0xff, 0xff, 0xff, 0xff, 0x0f])), [])
    XCTAssertEqual(
      try ClickDecoder.buttons(Data([0x23, 0x08, 0xff, 0xfd, 0xff, 0xff, 0x0f])), [.minus])
    XCTAssertEqual(
      try ClickDecoder.buttons(Data([0x23, 0x08, 0xff, 0xdf, 0xff, 0xff, 0x0f])), [.plus])
    XCTAssertEqual(
      try ClickDecoder.buttons(Data([0x23, 0x08, 0xff, 0xdd, 0xff, 0xff, 0x0f])), [.minus, .plus])
  }

  func testFaceAndNavigationButtons() throws {
    XCTAssertEqual(
      try ClickDecoder.buttons(Data([0x23, 0x08, 0xde, 0xff, 0xff, 0xff, 0x0f])), [.left, .b])
    XCTAssertEqual(
      try ClickDecoder.buttons(Data([0x23, 0x08, 0xff, 0xfe, 0xff, 0xff, 0x0f])), [.z])
  }

  func testUnknownMessageDoesNotProduceButtons() throws {
    XCTAssertNil(try ClickDecoder.buttons(Data()))
    XCTAssertNil(try ClickDecoder.buttons(Data([0x15])))
    XCTAssertNil(try ClickDecoder.buttons(Data("RideOn".utf8)))
  }

  func testUnknownProtobufFieldsDoNotChangeButtons() throws {
    let packet = Data([0x23, 0x12, 0x02, 0x08, 0x00, 0x08, 0xff, 0xdf, 0xff, 0xff, 0x0f])
    XCTAssertEqual(try ClickDecoder.buttons(packet), [.plus])
  }

  func testMalformedButtonFramesAreRejected() {
    for bytes: [UInt8] in [
      [0x23], [0x23, 0x08, 0x80], [0x23, 0x00],
      [0x23, 0x08, 0xff, 0xff, 0xff, 0xff, 0x1f],
      [0x23, 0x12, 0xff, 0x7f], [0x23, 0x09, 0x00],
      [0x23, 0x08, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x02],
    ] {
      XCTAssertThrowsError(try ClickDecoder.buttons(Data(bytes)), "\(bytes)") { error in
        XCTAssertTrue(error is WireError)
      }
    }
  }

  private let info = Data(
    [0x04, 0x01, 0x08] + Array("mywhoosh".utf8) + [0x03] + Array("5.0".utf8) + [0x02, 0x01, 0x02])

  func testAppInfoSurvivesEveryTCPFragmentBoundary() throws {
    let expected = TrainerInfo(name: "mywhoosh", version: "5.0", supported: [1, 2])
    for split in 0..<info.count {
      var stream = TrainerStream()
      XCTAssertEqual(try stream.append(Data(info.prefix(split))), [])
      XCTAssertEqual(try stream.append(Data(info.dropFirst(split))), [expected])
      XCTAssertTrue(stream.buffer.isEmpty)
    }
  }

  func testCoalescedHapticAndAppInfoMessages() throws {
    var stream = TrainerStream()
    let messages = try stream.append(Data([3, 1, 0, 0]) + info + info)
    XCTAssertEqual(messages.count, 2)
    XCTAssertEqual(messages.map(\.name), ["mywhoosh", "mywhoosh"])
    XCTAssertTrue(stream.buffer.isEmpty)
  }

  func testCapabilitiesAndEmptySupportedList() throws {
    var stream = TrainerStream()
    let trainer = try XCTUnwrap(stream.append(info).first)
    XCTAssertTrue(trainer.supports(.shiftUp))
    XCTAssertTrue(trainer.supports(.shiftDown))
    XCTAssertFalse(trainer.supports(.camera))
    XCTAssertTrue(TrainerInfo(name: "mywhoosh", version: "", supported: []).supports(.camera))
  }

  func testBadVersionLengthsAndOversizedStreamsFailClosed() {
    for bytes: [UInt8] in [
      [4, 2, 0], [4, 1, 33], [4, 1, 0, 33], [0xff], [4, 1, 1, 0xff, 0, 0],
      Array(repeating: 4, count: 4097),
    ] {
      var stream = TrainerStream()
      XCTAssertThrowsError(try stream.append(Data(bytes)))
    }
  }

  func testShiftWireMessagesMatchSpecification() {
    XCTAssertEqual(ControlPacket.button(.shiftUp, pressed: true), Data([1, 1, 1]))
    XCTAssertEqual(ControlPacket.button(.shiftUp, pressed: false), Data([1, 1, 0]))
    XCTAssertEqual(ControlPacket.button(.shiftDown, pressed: true), Data([1, 2, 1]))
    XCTAssertEqual(ControlPacket.status(ready: true), Data([2, 255, 1]))
  }
}

final class ButtonRouterTests: XCTestCase {
  func testRepeatedPacketsProduceOnePressAndOneRelease() {
    var router = ButtonRouter()
    let device = UUID()
    let first = router.update(device: device, buttons: [.plus]) { $0.defaultAction }
    XCTAssertEqual(first.pressed, [.plus])
    XCTAssertEqual(first.changes, [ActionChange(action: .shiftUp, pressed: true)])
    XCTAssertEqual(router.update(device: device, buttons: [.plus]) { $0.defaultAction }.changes, [])
    XCTAssertEqual(
      router.update(device: device, buttons: []) { $0.defaultAction }.changes,
      [ActionChange(action: .shiftUp, pressed: false)])
    XCTAssertEqual(router.update(device: device, buttons: []) { $0.defaultAction }.changes, [])
  }

  func testTwoControllersMappedToSameActionDoNotReleaseEachOther() {
    var router = ButtonRouter()
    let left = UUID()
    let right = UUID()
    let mapping: (ClickButton) -> RideAction = { _ in .shiftUp }
    XCTAssertEqual(
      router.update(device: left, buttons: [.minus], mapping: mapping).changes,
      [ActionChange(action: .shiftUp, pressed: true)])
    XCTAssertEqual(router.update(device: right, buttons: [.plus], mapping: mapping).changes, [])
    XCTAssertEqual(router.update(device: left, buttons: [], mapping: mapping).changes, [])
    XCTAssertEqual(
      router.update(device: right, buttons: [], mapping: mapping).changes,
      [ActionChange(action: .shiftUp, pressed: false)])
  }

  func testReconnectDoesNotReplayHeldButton() {
    var router = ButtonRouter()
    let device = UUID()
    _ = router.update(device: device, buttons: [.plus]) { $0.defaultAction }
    XCTAssertEqual(router.suspendHeldInputs(), [ActionChange(action: .shiftUp, pressed: false)])
    XCTAssertEqual(router.update(device: device, buttons: [.plus]) { $0.defaultAction }.changes, [])
    XCTAssertEqual(router.update(device: device, buttons: []) { $0.defaultAction }.changes, [])
    XCTAssertEqual(
      router.update(device: device, buttons: [.plus]) { $0.defaultAction }.changes,
      [ActionChange(action: .shiftUp, pressed: true)])
  }

  func testRemappingHeldButtonRequiresReleaseBeforeNewAction() {
    var router = ButtonRouter()
    let device = UUID()
    _ = router.update(device: device, buttons: [.b]) { _ in .back }
    _ = router.suspendHeldInputs()
    XCTAssertEqual(router.update(device: device, buttons: [.b]) { _ in .shiftDown }.changes, [])
    _ = router.update(device: device, buttons: []) { _ in .shiftDown }
    XCTAssertEqual(
      router.update(device: device, buttons: [.b]) { _ in .shiftDown }.changes,
      [ActionChange(action: .shiftDown, pressed: true)])
  }
}
