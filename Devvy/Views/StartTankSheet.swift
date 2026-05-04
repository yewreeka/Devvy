import SwiftUI

struct StartTankSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecipeId: UUID?
    @State private var tankLabel: String = ""
    @State private var tintHex: String = AppState.randomTint()

    var initialRecipeId: UUID?

    init(initialRecipeId: UUID? = nil) {
        self.initialRecipeId = initialRecipeId
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
                    Section("Steps (\(recipe.steps.count))") {
                        ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { idx, step in
                            HStack {
                                Text("\(idx + 1).")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text(step.name)
                                Spacer()
                                Text(TimeFormat.clock(step.duration))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        HStack {
                            Text("Total")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(TimeFormat.clock(recipe.totalDuration))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Start a Tank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { start() }
                        .disabled(selectedRecipeId == nil)
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
            }
        }
    }

    private var selectedRecipe: Recipe? {
        guard let id = selectedRecipeId else { return nil }
        return app.recipes.first { $0.id == id }
    }

    private func start() {
        guard let recipe = selectedRecipe else { return }
        Haptics.success()
        let label = tankLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = label.isEmpty ? AppState.suggestedTankLabel(existing: app.sessions) : label
        let tint = tintHex
        Task {
            await app.startSession(for: recipe, tankLabel: final, tintHex: tint)
        }
        dismiss()
    }
}
