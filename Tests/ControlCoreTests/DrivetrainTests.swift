import XCTest

@testable import ControlCore

final class DrivetrainTests: XCTestCase {
  func testCountsAndRatiosForCustomCassette() throws {
    let profile = Drivetrain(
      front: [46, 30], rear: [11, 18, 36], mode: .separate, startingGearID: "1:2")
    try profile.validate()
    XCTAssertEqual(profile.gears.count, 6)
    XCTAssertEqual(profile.gears[0].ratio, 46.0 / 11, accuracy: 0.000001)
    XCTAssertEqual(profile.gears[5].ratio, 30.0 / 36, accuracy: 0.000001)
    XCTAssertEqual(profile.gears[5].id, "1:2")
  }

  func testSequentialModeKeepsEqualRatiosAndSorts() throws {
    let profile = Drivetrain(
      front: [40, 20], rear: [10, 20], mode: .sequential, startingGearID: "0:0")
    try profile.validate()
    XCTAssertEqual(profile.gears.map(\.ratio), [1, 2, 2, 4])
    XCTAssertEqual(profile.gears.map(\.id), ["1:1", "0:1", "1:0", "0:0"])
  }

  func testTextParsingAcceptsSeparatorsWithoutInventingTeeth() throws {
    XCTAssertEqual(try Drivetrain.parse("46/30", front: true), [46, 30])
    XCTAssertEqual(try Drivetrain.parse("11, 13; 16 36", front: false), [11, 13, 16, 36])
    for invalid in [
      "", "11–36", "11-36", "11, abc, 36", "11.5, 36", "11, 11, 36", "36, 11", "0, 36", "11, 101",
    ] {
      XCTAssertThrowsError(try Drivetrain.parse(invalid, front: false), invalid)
    }
    for invalid in ["", "46, 46", "9", "101", "10, 20, 30, 40"] {
      XCTAssertThrowsError(try Drivetrain.parse(invalid, front: true), invalid)
    }
  }

  func testStartingGearMustExist() {
    XCTAssertThrowsError(
      try Drivetrain(front: [46], rear: [11, 36], mode: .sequential, startingGearID: "1:0")
        .validate())
  }

  func testSingleAndMaximumCassetteSizes() throws {
    try Drivetrain(front: [10], rear: [5], mode: .separate, startingGearID: "0:0").validate()
    try Drivetrain(front: [100], rear: Array(5..<35), mode: .separate, startingGearID: "0:29")
      .validate()
    XCTAssertThrowsError(
      try Drivetrain(front: [46], rear: Array(5..<36), mode: .separate, startingGearID: "0:0")
        .validate())
  }

  @MainActor
  func testSavedProfileSurvivesReloadAndInvalidEditsDoNotReplaceIt() async throws {
    let name = "FreeBikeControlTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let store = GearingStore(defaults: defaults)
    XCTAssertNil(store.profile)
    let profile = Drivetrain(
      front: [46, 30], rear: [11, 18, 36], mode: .sequential, startingGearID: "1:2")
    try store.save(profile)
    XCTAssertEqual(GearingStore(defaults: defaults).profile, profile)
    var invalid = profile
    invalid.rear = [36, 11]
    XCTAssertThrowsError(try store.save(invalid))
    XCTAssertEqual(store.profile, profile)
    XCTAssertEqual(GearingStore(defaults: defaults).profile, profile)
  }

  @MainActor
  func testCorruptedOrInvalidSavedProfileIsRejected() async throws {
    let name = "FreeBikeControlTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(Data("not json".utf8), forKey: "virtualDrivetrain.v1")
    XCTAssertNil(GearingStore(defaults: defaults).profile)
    XCTAssertNotNil(GearingStore(defaults: defaults).error)
    defaults.set(
      try JSONEncoder().encode(
        Drivetrain(front: [0], rear: [11], mode: .separate, startingGearID: "0:0")),
      forKey: "virtualDrivetrain.v1")
    XCTAssertNil(GearingStore(defaults: defaults).profile)
  }
}
