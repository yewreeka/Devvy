import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app
    @State private var selection: Section = .tanks

    enum Section: Hashable { case tanks, recipes }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Tanks", systemImage: "timer", value: Section.tanks) {
                TanksView()
            }
            .badge(app.sessions.count)

            Tab("Recipes", systemImage: "book.pages", value: Section.recipes) {
                RecipeListView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
