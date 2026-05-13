import SwiftUI

struct RecipeDetailView: View {
    let recipeId: UUID
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editingRecipe: Recipe?
    @State private var startingTank = false

    private var recipe: Recipe? {
        app.recipes.first { $0.id == recipeId }
    }

    var body: some View {
        Group {
            if let recipe {
                content(recipe)
            } else {
                ContentUnavailableView("Recipe not found", systemImage: "questionmark.folder")
                    .onAppear { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func content(_ recipe: Recipe) -> some View {
        TankPresenter(indicator: TankIndicator(recipe: recipe)) {
            Form {
                if !recipe.notes.isEmpty {
                    Section {
                        Text(recipe.notes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Steps (\(recipe.steps.count))") {
                    ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { idx, step in
                        StepCard(index: idx, step: step)
                    }
                }
                Section {
                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(TimeFormat.compact(recipe.totalDuration))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "square.and.pencil") {
                        editingRecipe = recipe
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        app.deleteRecipe(recipe)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.tap()
                startingTank = true
            } label: {
                Label("Start a Tank", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $startingTank) {
            StartTankSheet(initialRecipeId: recipe.id)
        }
        .sheet(item: $editingRecipe) { editing in
            RecipeEditorView(recipe: editing, isNew: false)
        }
    }

}

private struct StatPillSmall: View {
    let label: String
    let value: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.secondary)
        }
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}
