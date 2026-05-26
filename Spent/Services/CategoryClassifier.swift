import Foundation

// Classifies apps as Spent / Invested / Neutral.
// System: preset defaults by Apple category, user can override per app.
struct CategoryClassifier: Codable {

    // User overrides: bundleID → category
    var overrides: [String: AppCategory] = [:]

    private static let key = "spent.categoryOverrides"
    private static let suite = UserDefaults(suiteName: "group.app.spent")

    static func load() -> CategoryClassifier {
        guard let data = suite?.data(forKey: key),
              let classifier = try? JSONDecoder().decode(CategoryClassifier.self, from: data) else {
            return CategoryClassifier()
        }
        return classifier
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.suite?.set(data, forKey: Self.key)
    }

    // Apple's app category strings → default classification
    // Social/Entertainment/Games → Spent; Productivity/Education/Reference → Invested; rest → Neutral
    func classify(bundleID: String, appleCategory: String?) -> AppCategory {
        if let override = overrides[bundleID] { return override }
        return Self.defaultCategory(for: appleCategory)
    }

    static func defaultCategory(for appleCategory: String?) -> AppCategory {
        guard let cat = appleCategory?.lowercased() else { return .neutral }
        if spentCategories.contains(where: { cat.contains($0) }) { return .spent }
        if investedCategories.contains(where: { cat.contains($0) }) { return .invested }
        return .neutral
    }

    mutating func setOverride(bundleID: String, category: AppCategory) {
        overrides[bundleID] = category
        save()
    }

    mutating func clearOverride(bundleID: String) {
        overrides.removeValue(forKey: bundleID)
        save()
    }

    // MARK: - Category Defaults

    private static let spentCategories = [
        "social", "entertainment", "game", "photo", "video",
        "shopping", "food", "sports", "news", "magazine"
    ]

    private static let investedCategories = [
        "productivity", "education", "reference", "book",
        "business", "finance", "health", "fitness",
        "developer", "medical", "navigation", "utilities"
    ]
}
