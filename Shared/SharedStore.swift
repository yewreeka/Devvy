import Foundation

public enum SharedConstants {
    public static let appGroup = "group.com.jarod.devvy"
    public static let recipesKey = "devvy.recipes.v1"
    public static let sessionsKey = "devvy.sessions.v1"
    public static let didSeedKey = "devvy.didSeedRecipes.v1"
    public static let stateChangedNotification = Notification.Name("com.jarod.devvy.stateChanged")
}

/// App-Group-backed storage for recipes and active timer sessions.
/// Used by both the app and the Live Activity widget extension.
public final class SharedStore: @unchecked Sendable {
    public static let shared = SharedStore()

    private let defaults: UserDefaults
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        // Fall back to standard defaults if the App Group isn't entitled (e.g. Previews).
        self.defaults = UserDefaults(suiteName: SharedConstants.appGroup) ?? .standard
    }

    // MARK: - Recipes

    public func loadRecipes() -> [Recipe] {
        guard let data = defaults.data(forKey: SharedConstants.recipesKey) else { return [] }
        return (try? decoder.decode([Recipe].self, from: data)) ?? []
    }

    public func saveRecipes(_ recipes: [Recipe]) {
        let data = try? encoder.encode(recipes)
        defaults.set(data, forKey: SharedConstants.recipesKey)
        broadcast()
    }

    public func upsertRecipe(_ recipe: Recipe) {
        var all = loadRecipes()
        if let idx = all.firstIndex(where: { $0.id == recipe.id }) {
            var updated = recipe
            updated.updatedAt = .now
            all[idx] = updated
        } else {
            all.append(recipe)
        }
        saveRecipes(all)
    }

    public func deleteRecipe(id: UUID) {
        var all = loadRecipes()
        all.removeAll { $0.id == id }
        saveRecipes(all)
    }

    // MARK: - Sessions

    public func loadSessions() -> [TimerSession] {
        guard let data = defaults.data(forKey: SharedConstants.sessionsKey) else { return [] }
        return (try? decoder.decode([TimerSession].self, from: data)) ?? []
    }

    public func saveSessions(_ sessions: [TimerSession]) {
        let data = try? encoder.encode(sessions)
        defaults.set(data, forKey: SharedConstants.sessionsKey)
        broadcast()
    }

    public func upsertSession(_ session: TimerSession) {
        var all = loadSessions()
        if let idx = all.firstIndex(where: { $0.id == session.id }) {
            all[idx] = session
        } else {
            all.append(session)
        }
        saveSessions(all)
    }

    public func deleteSession(id: UUID) {
        var all = loadSessions()
        all.removeAll { $0.id == id }
        saveSessions(all)
    }

    public func session(id: UUID) -> TimerSession? {
        loadSessions().first { $0.id == id }
    }

    // MARK: - Seeding

    public var didSeedRecipes: Bool {
        get { defaults.bool(forKey: SharedConstants.didSeedKey) }
        set { defaults.set(newValue, forKey: SharedConstants.didSeedKey) }
    }

    private func broadcast() {
        NotificationCenter.default.post(name: SharedConstants.stateChangedNotification, object: nil)
    }
}
