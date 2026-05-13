import SwiftUI

struct StartTankSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecipeId: UUID?
    @State private var tankLabel: String = ""
    @State private var tintHex: String = AppState.randomTint()
    @State private var temperatureF: Double = 68
    /// True once the user has manually adjusted the temperature on this sheet.
    /// Until then, we follow the selected recipe's baseTemperatureF so picking
    /// a different recipe re-syncs the picker.
    @State private var temperatureWasEdited = false

    var initialRecipeId: UUID?
    /// Called on the main actor after the session is created, with the new
    /// session's id. Lets callers decide whether to navigate, switch tabs,
    /// etc. Fires before the sheet's `dismiss()` so any pushed navigation is
    /// queued behind the dismissal animation.
    var onStarted: ((UUID) -> Void)?

    init(initialRecipeId: UUID? = nil, onStarted: ((UUID) -> Void)? = nil) {
        self.initialRecipeId = initialRecipeId
        self.onStarted = onStarted
        _selectedRecipeId = State(initialValue: initialRecipeId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    if app.recipes.isEmpty {
                        ContentUnavailableView(
                            "No Recipes",
                            systemImage: "book",
                            description: Text("Import a .rcp file or create one in the Recipes tab.")
                        )
                    } else {
                        Picker("Recipe", selection: $selectedRecipeId) {
                            ForEach(app.recipes) { recipe in
                                Text(recipe.name).tag(Optional(recipe.id))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }

                Section("Label") {
                    TextField("Tank A", text: $tankLabel)
                        .textInputAutocapitalization(.words)
                }

                Section("Color") {
                    HStack(spacing: 14) {
                        ForEach(AppState.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex).gradient)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if hex == tintHex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .scaleEffect(hex == tintHex ? 1.15 : 1)
                                .animation(.devvyBounce, value: tintHex)
                                .onTapGesture {
                                    Haptics.tap()
                                    tintHex = hex
                                }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                if let recipe = selectedRecipe {
                    Section {
                        TemperatureField(temperatureF: Binding(
                            get: { temperatureF },
                            set: { temperatureF = $0; temperatureWasEdited = true }
                        ))
                        if abs(temperatureF - recipe.baseTemperatureF) > 0.05 {
                            let factor = TempCompensation.factor(
                                baseF: recipe.baseTemperatureF,
                                actualF: temperatureF
                            )
                            HStack {
                                Text("Recipe baseline")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(recipe.baseTemperatureF.formatted(.number.precision(.fractionLength(0...1))))°F")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text(factor < 1 ? "Faster by" : "Slower by")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(abs(1 - factor).formatted(.percent.precision(.fractionLength(0...1))))")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(factor < 1 ? .green : .orange)
                            }
                        }
                        if developerBelowMinimum(for: recipe) {
                            Label(
                                "Developer time is under 5 minutes. Ilford doesn't recommend developing this fast — uneven development. Lower the temperature to continue.",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Temperature")
                    }

                    Section("Steps (\(recipe.steps.count))") {
                        ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { idx, step in
                            HStack {
                                Text("\(idx + 1).")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text(step.name)
                                Spacer()
                                Text(TimeFormat.clock(adjustedDuration(for: step, at: idx, recipe: recipe)))
                                    .foregroundStyle(idx == 0 && abs(temperatureF - recipe.baseTemperatureF) > 0.05 ? .primary : .secondary)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                            }
                        }
                        HStack {
                            Text("Total")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(TimeFormat.clock(adjustedTotal(for: recipe)))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                }
            }
            .animation(.devvyFast, value: temperatureF)
            .navigationTitle("Start a Tank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { start() }
                        .disabled(!canStart)
                        .buttonStyle(.glassProminent)
                }
            }
            .onAppear {
                if selectedRecipeId == nil {
                    selectedRecipeId = app.recipes.first?.id
                }
                if tankLabel.isEmpty {
                    tankLabel = AppState.suggestedTankLabel(existing: app.sessions)
                }
                if let r = selectedRecipe, !temperatureWasEdited {
                    temperatureF = r.baseTemperatureF
                }
            }
            .onChange(of: selectedRecipeId) { _, _ in
                if let r = selectedRecipe, !temperatureWasEdited {
                    temperatureF = r.baseTemperatureF
                }
            }
        }
    }

    private var selectedRecipe: Recipe? {
        guard let id = selectedRecipeId else { return nil }
        return app.recipes.first { $0.id == id }
    }

    private var canStart: Bool {
        guard let recipe = selectedRecipe else { return false }
        return !developerBelowMinimum(for: recipe)
    }

    private func developerBelowMinimum(for recipe: Recipe) -> Bool {
        guard let first = recipe.steps.first else { return false }
        return adjustedDuration(for: first, at: 0, recipe: recipe)
            < TempCompensation.minimumRecommendedDeveloperSeconds
    }

    private func adjustedDuration(for step: Step, at index: Int, recipe: Recipe) -> TimeInterval {
        guard index == 0 else { return step.duration }
        return TempCompensation.adjustedDuration(
            step.duration,
            baseF: recipe.baseTemperatureF,
            actualF: temperatureF
        )
    }

    private func adjustedTotal(for recipe: Recipe) -> TimeInterval {
        recipe.steps.enumerated().reduce(0) { sum, pair in
            sum + adjustedDuration(for: pair.element, at: pair.offset, recipe: recipe)
        }
    }

    private func start() {
        guard let recipe = selectedRecipe else { return }
        Haptics.success()
        let label = tankLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = label.isEmpty ? AppState.suggestedTankLabel(existing: app.sessions) : label
        let tint = tintHex
        let temp = temperatureF
        Task {
            let session = await app.startSession(
                for: recipe,
                tankLabel: final,
                tintHex: tint,
                temperatureF: temp
            )
            if let session {
                onStarted?(session.id)
            }
            dismiss()
        }
    }
}
