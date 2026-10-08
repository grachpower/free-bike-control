import Foundation

enum ShiftingMode: String, Codable, CaseIterable, Identifiable {
  case separate, sequential
  var id: String { rawValue }
  var title: String { self == .separate ? "Front / rear" : "Sequential" }
}

struct VirtualGear: Equatable, Identifiable {
  let frontIndex: Int
  let rearIndex: Int
  let front: Int
  let rear: Int
  var id: String { "\(frontIndex):\(rearIndex)" }
  var ratio: Double { Double(front) / Double(rear) }
}

enum DrivetrainError: Error, LocalizedError {
  case invalidFront, invalidRear, invalidPosition
  var errorDescription: String? {
    switch self {
    case .invalidFront: "Enter 1–3 different chainrings using whole tooth counts from 10 to 100."
    case .invalidRear:
      "Enter 1–30 cassette sprockets in ascending order, with whole tooth counts from 5 to 100."
    case .invalidPosition: "Choose a starting gear from your configured drivetrain."
    }
  }
}

struct Drivetrain: Codable, Equatable {
  var front: [Int]
  var rear: [Int]
  var mode: ShiftingMode
  var startingGearID: String

  func validate() throws {
    guard (1...3).contains(front.count), Set(front).count == front.count,
      front.allSatisfy({ (10...100).contains($0) })
    else { throw DrivetrainError.invalidFront }
    guard (1...30).contains(rear.count), rear.allSatisfy({ (5...100).contains($0) }),
      zip(rear, rear.dropFirst()).allSatisfy({ $0 < $1 })
    else { throw DrivetrainError.invalidRear }
    guard gears.contains(where: { $0.id == startingGearID }) else {
      throw DrivetrainError.invalidPosition
    }
  }

  var gears: [VirtualGear] {
    let combinations = front.enumerated().flatMap { f, teeth in
      rear.enumerated().map { r, cog in
        VirtualGear(frontIndex: f, rearIndex: r, front: teeth, rear: cog)
      }
    }
    if mode == .separate { return combinations }
    // Keep equal ratios as separate physical combinations, with a stable order.
    return combinations.sorted {
      if $0.ratio != $1.ratio { return $0.ratio < $1.ratio }
      if $0.frontIndex != $1.frontIndex { return $0.frontIndex < $1.frontIndex }
      return $0.rearIndex < $1.rearIndex
    }
  }

  static func parse(_ text: String, front: Bool) throws -> [Int] {
    let tokens = text.split(whereSeparator: {
      $0.isWhitespace || $0 == "," || $0 == ";" || $0 == "/"
    })
    let values = tokens.compactMap { Int($0) }
    guard !tokens.isEmpty, values.count == tokens.count else {
      throw front ? DrivetrainError.invalidFront : DrivetrainError.invalidRear
    }
    let draft = Drivetrain(
      front: front ? values : [46, 30], rear: front ? [11] : values,
      mode: .separate, startingGearID: "0:0")
    try draft.validate()
    return values
  }
}
