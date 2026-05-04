import Foundation

enum SeedRecipes {
    /// Imports the bundled sample .rcp on first launch so the app isn't empty.
    static func runIfNeeded() {
        let store = SharedStore.shared
        guard !store.didSeedRecipes else { return }
        defer { store.didSeedRecipes = true }

        let names = ["XTOL_1_1_250"]
        var recipes = store.loadRecipes()
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "rcp"),
                  let data = try? Data(contentsOf: url),
                  let recipe = try? Recipe.decodeRCP(from: data),
                  !recipes.contains(where: { $0.name == recipe.name })
            else { continue }
            recipes.append(recipe)
        }
        store.saveRecipes(recipes)
    }
}
