import SwiftUI

struct ControllerPad: View {
  let right: Bool
  var compact = false
  let pressed: Set<ClickButton>
  let selected: ClickButton?
  let choose: (ClickButton) -> Void

  private func key(_ button: ClickButton, label: String) -> some View {
    let active = pressed.contains(button)
    return Button {
      choose(button)
    } label: {
      Text(label).font(.system(size: 18, weight: .bold, design: .rounded))
        .frame(width: 46, height: 46)
        .foregroundStyle(active ? RideTheme.background : .white.opacity(0.85))
        .background(active ? RideTheme.accent : RideTheme.elevated, in: Circle())
        .overlay(
          Circle().stroke(
            selected == button ? RideTheme.cyan : .white.opacity(0.10),
            lineWidth: selected == button ? 2 : 1)
        )
        .shadow(color: active ? RideTheme.accent.opacity(0.3) : .clear, radius: 12)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(button.title)
    .accessibilityHint("Change button action")
  }

  var body: some View {
    VStack(spacing: 16) {
      Text(right ? "RIGHT" : "LEFT")
        .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(
          .secondary)
      ZStack {
        RoundedRectangle(cornerRadius: 55)
          .fill(
            LinearGradient(
              colors: [.white.opacity(0.06), .black.opacity(0.12)], startPoint: .topLeading,
              endPoint: .bottomTrailing)
          )
          .overlay(RoundedRectangle(cornerRadius: 55).stroke(.white.opacity(0.09), lineWidth: 1))
        VStack(spacing: 4) {
          key(right ? .y : .up, label: right ? "Y" : "↑")
          HStack(spacing: compact ? 22 : 40) {
            key(right ? .z : .left, label: right ? "Z" : "←")
            key(right ? .a : .right, label: right ? "A" : "→")
          }
          key(right ? .b : .down, label: right ? "B" : "↓")
          Button {
            choose(right ? .plus : .minus)
          } label: {
            Text(right ? "+" : "−").font(.system(size: 28, weight: .medium))
              .frame(width: 92, height: 42)
              .foregroundStyle(
                pressed.contains(right ? .plus : .minus) ? RideTheme.background : RideTheme.accent
              )
              .background(
                pressed.contains(right ? .plus : .minus)
                  ? RideTheme.accent : RideTheme.accent.opacity(0.10), in: Capsule())
          }.buttonStyle(.plain).padding(.top, 8)
            .accessibilityLabel(
              right
                ? "Right controller, plus. Change mapping"
                : "Left controller, minus. Change mapping")
        }
      }.frame(width: compact ? 126 : 170, height: 230)
    }
  }
}
