import Combine
import Foundation

@MainActor
final class GearingStore: ObservableObject {
  @Published private(set) var profile: Drivetrain?
  @Published private(set) var error: String?
  private let defaults: UserDefaults
  private let key = "virtualDrivetrain.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    guard let data = defaults.data(forKey: key) else { return }
    do {
      let saved = try JSONDecoder().decode(Drivetrain.self, from: data)
      try saved.validate()
      profile = saved
    } catch { self.error = "The saved profile is invalid. Set up your cassette again." }
  }

  func save(_ draft: Drivetrain) throws {
    try draft.validate()
    let data = try JSONEncoder().encode(draft)
    defaults.set(data, forKey: key)
    profile = draft
    error = nil
  }
}
