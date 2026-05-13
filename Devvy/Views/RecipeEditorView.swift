import SwiftUI

struct RecipeEditorView: View {
    @State var recipe: Recipe
    let isNew: Bool

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $recipe.name)
                    TextField("Notes", text: $recipe.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    TemperatureField(temperatureF: $recipe.baseTemperatureF)
                } header: {
                    Text("Development Temperature")
                } footer: {
                    Text("The temperature these step times are calibrated for. When starting a tank, you can pick a different temperature and the developer step is adjusted automatically.")
                }

                Section {
                    ForEach($recipe.steps) { $step in
                        StepEditorRow(step: $step)
                    }
                    .onDelete { idx in
                        recipe.steps.remove(atOffsets: idx)
                    }
                    .onMove { src, dst in
                        recipe.steps.move(fromOffsets: src, toOffset: dst)
                    }

                    Button {
                        recipe.steps.append(Step(
                            order: recipe.steps.count,
                            name: "New Step",
                            duration: 60
                        ))
                    } label: {
                        Label("Add Step", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text("Steps")
                        Spacer()
                        Text(TimeFormat.compact(recipe.totalDuration))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isNew ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var r = recipe
                        // Renumber orders.
                        r.steps = r.steps.enumerated().map { idx, s in
                            var s = s; s.order = idx; return s
                        }
                        r.updatedAt = .now
                        app.saveRecipe(r)
                        Haptics.success()
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(recipe.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

private struct StepEditorRow: View {
    @Binding var step: Step

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Name", text: $step.name)
                .font(.body.weight(.semibold))

            DurationStepperField(
                label: "Duration",
                seconds: Binding(
                    get: { Int(step.duration) },
                    set: { step.duration = TimeInterval($0) }
                )
            )
            DurationStepperField(
                label: "Agitate at start",
                seconds: $step.initialAgitation,
                allowZero: true,
                offLabel: "Off"
            )
            DurationStepperField(
                label: "Agitate every",
                seconds: $step.agitationInterval,
                allowZero: true,
                offLabel: "Off"
            )
            DurationStepperField(
                label: "Agitate for",
                seconds: $step.agitationDuration,
                allowZero: true,
                offLabel: "Off"
            )

            TextField("Notes (optional)", text: $step.notes, axis: .vertical)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1...3)
        }
        .padding(.vertical, 6)
    }
}

/// Stepper-driven temperature picker. Fahrenheit primary, Celsius shown as a
/// subtitle. Range 50–90°F covers all practical darkroom development.
struct TemperatureField: View {
    @Binding var temperatureF: Double

    private var celsius: Double { TempCompensation.celsius(fromFahrenheit: temperatureF) }

    private var fBinding: Binding<Double> {
        Binding(
            get: { temperatureF },
            set: { temperatureF = min(90, max(50, $0)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Temperature")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(temperatureF.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText(value: temperatureF))
                    Text("°F")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("\(celsius.formatted(.number.precision(.fractionLength(0...1))))°C")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: celsius))
                Spacer()
                Stepper(value: fBinding, in: 50...90, step: 1) { EmptyView() }
                    .labelsHidden()
            }
        }
        .padding(.vertical, 4)
        .animation(.devvyFast, value: temperatureF)
    }
}

/// Lets the user pick a duration via a unit toggle (Min / Sec) and a single
/// Stepper that increments in the chosen unit. Press-and-hold on `+`/`−`
/// repeats, so dialing in 12 minutes is a couple seconds of holding the up
/// arrow.
private struct DurationStepperField: View {
    let label: String
    @Binding var seconds: Int
    var allowZero: Bool = false
    var offLabel: String = "0:00"

    enum Unit: String, Hashable, CaseIterable {
        case minutes = "Min"
        case seconds = "Sec"
    }

    @State private var unit: Unit = .minutes

    private var minimum: Int { allowZero ? 0 : 1 }

    private var stepperBinding: Binding<Int> {
        Binding(
            get: { seconds },
            set: { newValue in
                seconds = max(minimum, newValue)
            }
        )
    }

    private var stepAmount: Int {
        switch unit {
        case .minutes: 60
        case .seconds: 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(seconds == 0 && allowZero ? offLabel : TimeFormat.clock(TimeInterval(seconds)))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(seconds == 0 && allowZero ? .secondary : .primary)
                    .contentTransition(.numericText(value: Double(seconds)))
            }

            HStack(spacing: 12) {
                Picker("Step by", selection: $unit) {
                    ForEach(Unit.allCases, id: \.self) { u in
                        Text(u.rawValue).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 130)

                Stepper(
                    value: stepperBinding,
                    in: minimum...(60 * 90),
                    step: stepAmount
                ) {
                    EmptyView()
                }
                .labelsHidden()

                Spacer(minLength: 0)
            }
        }
        .animation(.devvyFast, value: seconds)
    }
}
