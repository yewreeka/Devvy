import SwiftUI
import UniformTypeIdentifiers

struct RecipeListView: View {
    @Environment(AppState.self) private var app
    @State private var showingImporter = false
    @State private var newRecipe: Recipe?
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Group {
                if app.recipes.isEmpty {
                    ContentUnavailableView {
                        Label("No Recipes", systemImage: "book.pages")
                    } description: {
                        Text("Import a .rcp file from the Develop app, or create a new recipe.")
                    } actions: {
                        HStack {
                            Button { showingImporter = true } label: {
                                Label("Import .rcp", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.glass)

                            Button { newRecipe = Recipe(name: "New Recipe") } label: {
                                Label("New", systemImage: "plus")
                            }
                            .buttonStyle(.glassProminent)
                        }
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Recipe", systemImage: "plus") {
                            newRecipe = Recipe(name: "New Recipe")
                        }
                        Button("Import .rcp…", systemImage: "square.and.arrow.down") {
                            showingImporter = true
                        }
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
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: Self.recipeContentTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .sheet(item: $newRecipe) { recipe in
                RecipeEditorView(recipe: recipe, isNew: true)
            }
            .alert("Import failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(app.recipes) { recipe in
                NavigationLink(value: recipe.id) {
                    RecipeRow(recipe: recipe)
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

    static var recipeContentTypes: [UTType] {
        var types = [UTType.json]
        if let custom = UTType("com.jarod.devvy.recipe") { types.insert(custom, at: 0) }
        return types
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    _ = try app.importRecipe(from: data)
                    Haptics.success()
                } catch {
                    importError = error.localizedDescription
                    Haptics.warning()
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
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
