import Foundation
import SwiftUI
import Combine

public struct DeletedDishItem: Identifiable, Hashable, Codable {
    public let id: String
    public let dish: Dish
    public let originalCategoryId: String
    public let originalCategoryName: String
    public let deletedAt: Date
    
    public init(id: String = UUID().uuidString, dish: Dish, originalCategoryId: String, originalCategoryName: String, deletedAt: Date = Date()) {
        self.id = id
        self.dish = dish
        self.originalCategoryId = originalCategoryId
        self.originalCategoryName = originalCategoryName
        self.deletedAt = deletedAt
    }
}

public struct DeletedCategoryItem: Identifiable, Hashable, Codable {
    public let id: String
    public let category: DishCategory
    public let deletedAt: Date
    
    public init(id: String = UUID().uuidString, category: DishCategory, deletedAt: Date = Date()) {
        self.id = id
        self.category = category
        self.deletedAt = deletedAt
    }
}

public enum UndoAction {
    case category(DishCategory, originalIndex: Int)
    case dish(Dish, categoryId: String, originalIndex: Int)
}

@MainActor
public class RecipeDataManager: ObservableObject {
    public static let shared = RecipeDataManager()
    
    @Published public var categories: [DishCategory] = []
    @Published public var deletedCategories: [DeletedCategoryItem] = []
    @Published public var deletedDishes: [DeletedDishItem] = []
    
    // Unified Edit Mode (一级二级菜单状态统一)
    @Published public var isEditing: Bool = false
    
    public var isEditingCategories: Bool {
        get { isEditing }
        set { isEditing = newValue }
    }
    public var isEditingDishes: Bool {
        get { isEditing }
        set { isEditing = newValue }
    }
    
    public func enterEditMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            self.isEditing = true
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    public func exitEditMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.isEditing = false
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // Toast Notification & Undo
    @Published public var toastMessage: String? = nil
    @Published public var lastUndoAction: UndoAction? = nil
    private var toastWorkItem: DispatchWorkItem? = nil
    
    // User Profile Avatar (黑白色简约默认风格)
    @Published public var customAvatarData: Data? = nil
    @Published public var selectedAvatarPreset: String = "person.fill"
    
    // User Profile Information (图一样式)
    @Published public var userNickname: String = "船长"
    @Published public var userBio: String = ""
    @Published public var userIdNumber: String = "7779559087"
    @Published public var isVIP: Bool = false
    @Published public var vipPlanName: String = ""
    
    private let avatarDataKey = "mealcoll_custom_avatar_data"
    private let avatarPresetKey = "mealcoll_avatar_preset"
    private let userNicknameKey = "mealcoll_user_nickname"
    private let userBioKey = "mealcoll_user_bio"
    private let userIdNumberKey = "mealcoll_user_id_number"
    private let isVIPKey = "mealcoll_is_vip"
    private let vipPlanNameKey = "mealcoll_vip_plan_name"
    
    private let categoriesFileName = "mealcoll_categories.json"
    private let trashFileName = "mealcoll_trash.json"
    
    public init() {
        loadData()
    }
    
    // MARK: - Persistence
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var categoriesFileURL: URL {
        documentsURL.appendingPathComponent(categoriesFileName)
    }
    
    private var trashFileURL: URL {
        documentsURL.appendingPathComponent(trashFileName)
    }
    
    public func loadData() {
        // Load Categories
        if FileManager.default.fileExists(atPath: categoriesFileURL.path) {
            do {
                let data = try Data(contentsOf: categoriesFileURL)
                let decoded = try JSONDecoder().decode([DishCategory].self, from: data)
                if !decoded.isEmpty {
                    self.categories = decoded
                    // Upgrade rice category if it has fewer than 20 dishes
                    if let riceIdx = self.categories.firstIndex(where: { $0.id == "rice" }),
                       let sampleRice = DishCategory.sampleCategories.first(where: { $0.id == "rice" }),
                       self.categories[riceIdx].dishes.count < 20 {
                        self.categories[riceIdx] = sampleRice
                        saveCategories()
                    }
                } else {
                    self.categories = DishCategory.sampleCategories
                }
            } catch {
                print("Failed to decode categories, using sample: \(error)")
                self.categories = DishCategory.sampleCategories
            }
        } else {
            self.categories = DishCategory.sampleCategories
            saveCategories()
        }
        
        // Load Trash
        if FileManager.default.fileExists(atPath: trashFileURL.path) {
            do {
                let data = try Data(contentsOf: trashFileURL)
                let decoded = try JSONDecoder().decode(TrashContainer.self, from: data)
                self.deletedCategories = decoded.categories
                self.deletedDishes = decoded.dishes
            } catch {
                print("Failed to decode trash: \(error)")
                self.deletedCategories = []
                self.deletedDishes = []
            }
        }
        
        // Load Avatar
        if let savedData = UserDefaults.standard.data(forKey: avatarDataKey) {
            self.customAvatarData = savedData
        }
        if let savedPreset = UserDefaults.standard.string(forKey: avatarPresetKey) {
            self.selectedAvatarPreset = savedPreset
        }
        
        // Load User Info
        if let savedNickname = UserDefaults.standard.string(forKey: userNicknameKey), !savedNickname.isEmpty {
            self.userNickname = savedNickname
        }
        if let savedBio = UserDefaults.standard.string(forKey: userBioKey) {
            self.userBio = savedBio
        }
        if let savedId = UserDefaults.standard.string(forKey: userIdNumberKey), !savedId.isEmpty {
            self.userIdNumber = savedId
        }
        self.isVIP = UserDefaults.standard.bool(forKey: isVIPKey)
        if let savedPlan = UserDefaults.standard.string(forKey: vipPlanNameKey) {
            self.vipPlanName = savedPlan
        }
    }
    
    // MARK: - VIP Membership Management
    public func activateVIP(planName: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            self.isVIP = true
            self.vipPlanName = planName
        }
        UserDefaults.standard.set(true, forKey: isVIPKey)
        UserDefaults.standard.set(planName, forKey: vipPlanNameKey)
        showToast("已开通私厨 VIP（\(planName)）")
    }
    
    // MARK: - User Profile Management
    public func updateProfile(nickname: String, bio: String) {
        self.userNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "船长" : nickname
        self.userBio = bio
        UserDefaults.standard.set(self.userNickname, forKey: userNicknameKey)
        UserDefaults.standard.set(self.userBio, forKey: userBioKey)
        showToast("已保存个人资料")
    }
    
    // MARK: - Avatar Management
    public func setCustomAvatar(data: Data?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.customAvatarData = data
        }
        if let data = data {
            UserDefaults.standard.set(data, forKey: avatarDataKey)
        } else {
            UserDefaults.standard.removeObject(forKey: avatarDataKey)
        }
        showToast("已更新头像")
    }
    
    public func setAvatarPreset(_ preset: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.selectedAvatarPreset = preset
            self.customAvatarData = nil
        }
        UserDefaults.standard.removeObject(forKey: avatarDataKey)
        UserDefaults.standard.set(preset, forKey: avatarPresetKey)
        showToast("已更换默认头像")
    }
    
    public func saveCategories() {
        do {
            let data = try JSONEncoder().encode(categories)
            try data.write(to: categoriesFileURL, options: .atomic)
        } catch {
            print("Failed to save categories: \(error)")
        }
    }
    
    public func saveTrash() {
        do {
            let container = TrashContainer(categories: deletedCategories, dishes: deletedDishes)
            let data = try JSONEncoder().encode(container)
            try data.write(to: trashFileURL, options: .atomic)
        } catch {
            print("Failed to save trash: \(error)")
        }
    }
    
    // MARK: - Reordering
    public func moveCategory(from sourceIndex: Int, to destinationIndex: Int, autoSave: Bool = true) {
        guard sourceIndex != destinationIndex,
              categories.indices.contains(sourceIndex),
              categories.indices.contains(destinationIndex) else { return }
        
        let item = categories.remove(at: sourceIndex)
        categories.insert(item, at: destinationIndex)
        
        if autoSave {
            saveCategories()
        }
    }
    
    public func moveDish(in categoryId: String, from sourceIndex: Int, to destinationIndex: Int, autoSave: Bool = true) {
        guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        var cat = categories[catIndex]
        guard sourceIndex != destinationIndex,
              cat.dishes.indices.contains(sourceIndex),
              cat.dishes.indices.contains(destinationIndex) else { return }
        
        var dishes = cat.dishes
        let dish = dishes.remove(at: sourceIndex)
        dishes.insert(dish, at: destinationIndex)
        
        categories[catIndex] = DishCategory(
            id: cat.id,
            name: cat.name,
            englishName: cat.englishName,
            subtitle: cat.subtitle,
            updatedTimeAgo: cat.updatedTimeAgo,
            iconName: cat.iconName,
            dishes: dishes
        )
        
        if autoSave {
            saveCategories()
        }
    }
    
    // MARK: - Add Category
    public func addCategory(name: String, subtitle: String, iconName: String = "fork.knife") {
        let newCat = DishCategory(
            id: UUID().uuidString,
            name: name,
            englishName: "Custom Collection",
            subtitle: subtitle.isEmpty ? "私享定制分类" : subtitle,
            updatedTimeAgo: "刚刚",
            iconName: iconName,
            dishes: []
        )
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            categories.append(newCat)
        }
        saveCategories()
        showToast("已创建新分类「\(name)」")
    }
    
    // MARK: - Add Dish
    public func addDish(_ dish: Dish, toCategoryId categoryId: String) {
        if let catIndex = categories.firstIndex(where: { $0.id == categoryId }) {
            let cat = categories[catIndex]
            var dishes = cat.dishes
            dishes.insert(dish, at: 0)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                categories[catIndex] = DishCategory(
                    id: cat.id,
                    name: cat.name,
                    englishName: cat.englishName,
                    subtitle: cat.subtitle,
                    updatedTimeAgo: "刚刚",
                    iconName: cat.iconName,
                    dishes: dishes
                )
            }
            saveCategories()
            showToast("已成功导入「\(dish.name)」")
        } else if !categories.isEmpty {
            let cat = categories[0]
            var dishes = cat.dishes
            dishes.insert(dish, at: 0)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                categories[0] = DishCategory(
                    id: cat.id,
                    name: cat.name,
                    englishName: cat.englishName,
                    subtitle: cat.subtitle,
                    updatedTimeAgo: "刚刚",
                    iconName: cat.iconName,
                    dishes: dishes
                )
            }
            saveCategories()
            showToast("已成功导入「\(dish.name)」")
        }
    }
    
    // MARK: - Delete & Trash
    public func deleteCategory(id: String) {
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        let removed = categories.remove(at: index)
        let trashItem = DeletedCategoryItem(category: removed)
        deletedCategories.insert(trashItem, at: 0)
        
        lastUndoAction = .category(removed, originalIndex: index)
        saveCategories()
        saveTrash()
        
        showToast("已将「\(removed.name)」移入回收站", allowUndo: true)
    }
    
    public func deleteDish(dishId: String, in categoryId: String) {
        guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        let cat = categories[catIndex]
        guard let dishIndex = cat.dishes.firstIndex(where: { $0.id == dishId }) else { return }
        
        var dishes = cat.dishes
        let removedDish = dishes.remove(at: dishIndex)
        
        categories[catIndex] = DishCategory(
            id: cat.id,
            name: cat.name,
            englishName: cat.englishName,
            subtitle: cat.subtitle,
            updatedTimeAgo: cat.updatedTimeAgo,
            iconName: cat.iconName,
            dishes: dishes
        )
        
        let trashDish = DeletedDishItem(
            dish: removedDish,
            originalCategoryId: categoryId,
            originalCategoryName: cat.name
        )
        deletedDishes.insert(trashDish, at: 0)
        
        lastUndoAction = .dish(removedDish, categoryId: categoryId, originalIndex: dishIndex)
        saveCategories()
        saveTrash()
        
        showToast("已将「\(removedDish.name)」移入回收站", allowUndo: true)
    }
    
    // MARK: - Undo
    public func undoLastDeleted() {
        guard let action = lastUndoAction else { return }
        lastUndoAction = nil
        toastWorkItem?.cancel()
        toastMessage = nil
        
        switch action {
        case .category(let cat, let index):
            // Remove from trash
            deletedCategories.removeAll(where: { $0.category.id == cat.id })
            let safeIndex = min(index, categories.count)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                categories.insert(cat, at: safeIndex)
            }
            saveCategories()
            saveTrash()
            showToast("已恢复分类「\(cat.name)」", allowUndo: false)
            
        case .dish(let dish, let catId, let index):
            deletedDishes.removeAll(where: { $0.dish.id == dish.id })
            if let catIndex = categories.firstIndex(where: { $0.id == catId }) {
                let cat = categories[catIndex]
                var dishes = cat.dishes
                let safeIndex = min(index, dishes.count)
                dishes.insert(dish, at: safeIndex)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    categories[catIndex] = DishCategory(
                        id: cat.id,
                        name: cat.name,
                        englishName: cat.englishName,
                        subtitle: cat.subtitle,
                        updatedTimeAgo: cat.updatedTimeAgo,
                        iconName: cat.iconName,
                        dishes: dishes
                    )
                }
            } else {
                // If original category was deleted, restore into first category or create one
                if let firstCat = categories.first {
                    var dishes = firstCat.dishes
                    dishes.append(dish)
                    categories[0] = DishCategory(
                        id: firstCat.id,
                        name: firstCat.name,
                        englishName: firstCat.englishName,
                        subtitle: firstCat.subtitle,
                        updatedTimeAgo: firstCat.updatedTimeAgo,
                        iconName: firstCat.iconName,
                        dishes: dishes
                    )
                }
            }
            saveCategories()
            saveTrash()
            showToast("已恢复菜品「\(dish.name)」", allowUndo: false)
        }
    }
    
    // MARK: - Restore from Trash View
    public func restoreCategory(item: DeletedCategoryItem) {
        deletedCategories.removeAll(where: { $0.id == item.id })
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            categories.append(item.category)
        }
        saveCategories()
        saveTrash()
        showToast("已还原「\(item.category.name)」", allowUndo: false)
    }
    
    public func restoreDish(item: DeletedDishItem) {
        deletedDishes.removeAll(where: { $0.id == item.id })
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if let catIndex = categories.firstIndex(where: { $0.id == item.originalCategoryId }) {
                let cat = categories[catIndex]
                var dishes = cat.dishes
                dishes.append(item.dish)
                categories[catIndex] = DishCategory(
                    id: cat.id,
                    name: cat.name,
                    englishName: cat.englishName,
                    subtitle: cat.subtitle,
                    updatedTimeAgo: cat.updatedTimeAgo,
                    iconName: cat.iconName,
                    dishes: dishes
                )
            } else if !categories.isEmpty {
                let firstCat = categories[0]
                var dishes = firstCat.dishes
                dishes.append(item.dish)
                categories[0] = DishCategory(
                    id: firstCat.id,
                    name: firstCat.name,
                    englishName: firstCat.englishName,
                    subtitle: firstCat.subtitle,
                    updatedTimeAgo: firstCat.updatedTimeAgo,
                    iconName: firstCat.iconName,
                    dishes: dishes
                )
            }
        }
        saveCategories()
        saveTrash()
        showToast("已还原「\(item.dish.name)」", allowUndo: false)
    }
    
    public func deleteCategoryPermanently(id: String) {
        deletedCategories.removeAll(where: { $0.id == id })
        saveTrash()
    }
    
    public func deleteDishPermanently(id: String) {
        deletedDishes.removeAll(where: { $0.id == id })
        saveTrash()
    }
    
    public func clearTrash() {
        deletedCategories.removeAll()
        deletedDishes.removeAll()
        saveTrash()
        showToast("已清空回收站", allowUndo: false)
    }
    
    // MARK: - Toast Banner
    public func showToast(_ message: String, allowUndo: Bool = false) {
        toastWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.toastMessage = message
        }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.toastMessage = nil
                self?.lastUndoAction = nil
            }
        }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
    }
}

private struct TrashContainer: Codable {
    let categories: [DeletedCategoryItem]
    let dishes: [DeletedDishItem]
}
