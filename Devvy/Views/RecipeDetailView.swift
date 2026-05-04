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
        ScrollView {
            VStack(spacing: 20) {
                header(recipe)
                stepsSection(recipe)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private func header(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                StatPillSmall(label: "Steps", value: "\(recipe.steps.count)", systemImage: "list.number")
                StatPillSmall(label: "Total", value: TimeFormat.compact(recipe.totalDuration), systemImage: "clock")
            }
            if !recipe.notes.isEmpty {
                Text(recipe.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.background.secondary)
                    }
                    .glassEffect(in: .rect(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepsSection(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Steps")
                .font(.headline)
                .padding(.horizontal, 4)
            VStack(spacing: 8) {
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { idx, step in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(.tint.opacity(0.18))
                                .frame(width: 32, height: 32)
                            Text("\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.name).font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                if step.initialAgitation > 0 {
                                    Label("Agitate \(step.initialAgitation)s at start", systemImage: "play.circle")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if step.agitationInterval > 0, step.agitationDuration > 0 {
                                    Label("\(step.agitationDuration)s every \(step.agitationInterval)s", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Text(TimeFormat.clock(step.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.background.secondary)
                    }
                    .glassEffect(in: .rect(cornerRadius: 14))
                }
            }
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.secondary)
        }
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}
