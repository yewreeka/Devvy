import SwiftUI

struct RecipeListView: View {
    @Environment(AppState.self) private var app
    @State private var newRecipe: Recipe?

    var body: some View {
        NavigationStack {
            Group {
                if app.recipes.isEmpty {
                    ContentUnavailableView {
                        Label("No Recipes", systemImage: "book.pages")
                    } description: {
                        Text("Create a new recipe to get started.")
                    } actions: {
                        Button {
                            newRecipe = Recipe(name: "New Recipe")
                        } label: {
                            Label("New Recipe", systemImage: "plus")
                        }
                        .buttonStyle(.glassProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Your recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newRecipe = Recipe(name: "New Recipe")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .navigationDestination(for: Recipe.ID.self) { id in
                if let recipe = app.recipes.first(where: { $0.id == id }) {
                    RecipeDetailView(recipeId: recipe.id)
                }
            }
            .sheet(item: $newRecipe) { recipe in
                RecipeEditorView(recipe: recipe, isNew: true)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(app.recipes) { recipe in
                NavigationLink(value: recipe.id) {
                    RecipeRow(recipe: recipe)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Haptics.tap()
                        app.duplicateRecipe(recipe)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        Haptics.tap()
                        app.duplicateRecipe(recipe)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        Haptics.warning()
                        app.deleteRecipe(recipe)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                Haptics.tap()
                for i in indexSet {
                    let r = app.recipes[i]
                    app.deleteRecipe(r)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.devvyFast, value: app.recipes.map(\.id))
    }

}

private struct RecipeRow: View {
    let recipe: Recipe
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.tint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "drop.halffull")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(recipe.steps.count) steps · \(TimeFormat.compact(recipe.totalDuration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
