import SwiftUI

enum RideTheme {
  static let background = Color(red: 0.045, green: 0.058, blue: 0.075)
  static let surface = Color(red: 0.085, green: 0.105, blue: 0.13)
  static let elevated = Color(red: 0.12, green: 0.145, blue: 0.18)
  static let accent = Color(red: 0.75, green: 0.95, blue: 0.32)
  static let cyan = Color(red: 0.30, green: 0.80, blue: 0.88)
}

struct RideCard<Content: View>: View {
  let title: String
  let icon: String
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Label(title, systemImage: icon).font(.headline).foregroundStyle(.white.opacity(0.9))
      content
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RideTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.06), lineWidth: 1))
  }
}

struct StatusBadge: View {
  let text: String
  var ready = false
  var body: some View {
    HStack(spacing: 7) {
      Circle().fill(ready ? RideTheme.accent : Color.orange).frame(width: 6, height: 6)
      Text(text).font(.caption.weight(.semibold))
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background((ready ? RideTheme.accent : Color.orange).opacity(0.10), in: Capsule())
    .foregroundStyle(ready ? RideTheme.accent : .orange)
  }
}

struct RideButtonStyle: ButtonStyle {
  var prominent = false
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.semibold))
      .padding(.horizontal, 18).padding(.vertical, 13)
      .foregroundStyle(
        prominent && enabled ? RideTheme.background : Color.white.opacity(enabled ? 0.9 : 0.3)
      )
      .background(
        prominent && enabled ? RideTheme.accent : RideTheme.elevated,
        in: RoundedRectangle(cornerRadius: 14)
      )
      .opacity(configuration.isPressed ? 0.75 : 1)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}
