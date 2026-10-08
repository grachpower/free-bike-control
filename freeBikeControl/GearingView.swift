import SwiftUI

struct GearingView: View {
  @ObservedObject var store: GearingStore
  @State private var frontText: String
  @State private var rearText: String
  @State private var mode: ShiftingMode
  @State private var startingID: String
  @State private var feedback: String?

  init(store: GearingStore) {
    self.store = store
    _frontText = State(
      initialValue: store.profile?.front.map(String.init).joined(separator: ", ") ?? "46, 30")
    // The user's cassette range is known; intermediate teeth are not. Do not invent them.
    _rearText = State(
      initialValue: store.profile?.rear.map(String.init).joined(separator: ", ") ?? "")
    _mode = State(initialValue: store.profile?.mode ?? .separate)
    _startingID = State(initialValue: store.profile?.startingGearID ?? "0:0")
  }

  private var draft: Result<Drivetrain, Error> {
    Result {
      let front = try Drivetrain.parse(frontText, front: true)
      let rear = try Drivetrain.parse(rearText, front: false)
      return Drivetrain(front: front, rear: rear, mode: mode, startingGearID: startingID)
    }
  }

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 14) {
        Text("Set up your bike").font(.headline)
        Text(
          "Profile preview only. Gear ratios aren't sent to MyWhoosh and don't change CORE 2 resistance yet."
        )
        .font(.callout).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 6) {
          Text("Chainrings · tooth counts").font(.caption)
          TextField("46, 30", text: $frontText).textFieldStyle(.roundedBorder)
        }
        VStack(alignment: .leading, spacing: 6) {
          Text("Virtual cassette · teeth on each sprocket").font(.caption)
          TextField("Full sprocket list from 11 to 36", text: $rearText).textFieldStyle(
            .roundedBorder)
          Text(
            "Enter every sprocket, separated by commas or spaces, from smallest to largest. The number of values determines the rear gear count. The 11–36 range alone doesn't specify the intermediate gears."
          )
          .font(.caption).foregroundStyle(.secondary)
        }
        Picker("Shifting mode", selection: $mode) {
          ForEach(ShiftingMode.allCases) { Text($0.title).tag($0) }
        }
        if case .success(let profile) = draft {
          Text(
            "\(profile.front.count) × \(profile.rear.count) · \(profile.gears.count) combinations"
          )
          .font(.headline).monospacedDigit()
          Text(
            mode == .sequential
              ? "Sorted by ratio from easiest to hardest. Equal ratios are kept as separate combinations."
              : "Separate front and rear shifting. The table is grouped by chainring, with gear steps shown within each group."
          )
          .font(.caption).foregroundStyle(.secondary)
          Picker(
            "Starting gear",
            selection: Binding(
              get: { profile.gears.contains(where: { $0.id == startingID }) ? startingID : "0:0" },
              set: {
                startingID = $0
                feedback = nil
              }
            )
          ) {
            ForEach(profile.gears) { gear in Text("\(gear.front) / \(gear.rear)").tag(gear.id) }
          }
          DisclosureGroup("Gear ratios and steps") {
            VStack(spacing: 8) {
              ForEach(Array(profile.gears.enumerated()), id: \.element.id) { index, gear in
                HStack {
                  Text("\(index + 1). \(gear.front) / \(gear.rear)")
                  Spacer()
                  Text(gear.ratio, format: .number.precision(.fractionLength(3)))
                  if index > 0
                    && (mode == .sequential
                      || profile.gears[index - 1].frontIndex == gear.frontIndex)
                  {
                    let previous = profile.gears[index - 1].ratio
                    Text(
                      "\((gear.ratio / previous - 1) * 100, format: .number.precision(.fractionLength(1)))%"
                    )
                  }
                }.font(.caption.monospacedDigit())
              }
            }.padding(.top, 8)
          }
          Button("Save profile") { save(profile) }.buttonStyle(.borderedProminent)
          if store.profile != profile {
            Text("You have unsaved changes").font(.caption).foregroundStyle(.secondary)
          }
        } else if case .failure(let error) = draft {
          Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
        }
        if let feedback { Text(feedback).font(.caption).foregroundStyle(.secondary) }
        if let error = store.error { Text(error).font(.caption).foregroundStyle(.orange) }
      }.frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: frontText) { _, _ in feedback = nil }
        .onChange(of: rearText) { _, _ in feedback = nil }
        .onChange(of: mode) { _, _ in feedback = nil }
    } label: {
      Label("Virtual drivetrain", systemImage: "gearshape.2")
    }
  }

  private func save(_ profile: Drivetrain) {
    var valid = profile
    if !profile.gears.contains(where: { $0.id == startingID }) { valid.startingGearID = "0:0" }
    do {
      try store.save(valid)
      startingID = valid.startingGearID
      feedback = "Profile saved on this device."
    } catch { feedback = error.localizedDescription }
  }
}
