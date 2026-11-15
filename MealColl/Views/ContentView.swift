import SwiftUI

public struct ContentView: View {
    @ObservedObject private var dataManager = RecipeDataManager.shared
    @ObservedObject private var workflowManager = RecipeAIWorkflowManager.shared
    @State private var cookingRecords: [CookingRecord] = []
    
    // Primary page index: 0 = 船长.de私厨, 1 = 菜谱日历（右侧）
    @State private var primaryTab: Int = 0
    
    // Category Detail & 3D Flipping Modal states
    @State private var selectedCategory: DishCategory? = nil
    @State private var selectedDish: Dish? = nil
    @State private var selectedDishFrame: CGRect = .zero
    
    // Profile sheet state
    @State private var showProfile: Bool = false
    
    // All dishes flattened for calendar lookup
    private var allDishes: [Dish] {
        dataManager.categories.flatMap { $0.dishes }
    }
    
    // Only allow horizontal paging to calendar on Page 0 when NOT in category detail, NOT viewing a dish, and NOT editing
    private var isPagingDisabled: Bool {
        if primaryTab == 0 {
            return selectedCategory != nil || selectedDish != nil || dataManager.isEditing
        } else {
            return selectedDish != nil
        }
    }
    
    public init() {
        let all = DishCategory.sampleCategories.flatMap { $0.dishes }
        _cookingRecords = State(initialValue: CookingRecord.sampleRecords(dishes: all))
        
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-testDetail") || args.contains("-testCardCycle") {
            _selectedCategory = State(initialValue: DishCategory.sampleCategories[0])
        } else if args.contains("-testModal") || args.contains("-testStepGallery") {
            _selectedCategory = State(initialValue: DishCategory.sampleCategories[0])
            _selectedDish = State(initialValue: DishCategory.sampleCategories[0].dishes[0])
        } else if args.contains("-testCalendar") {
            _primaryTab = State(initialValue: 1)
        } else if args.contains("-testEditCategories") {
            RecipeDataManager.shared.isEditingCategories = true
        } else if args.contains("-testEditDishes") {
            _selectedCategory = State(initialValue: DishCategory.sampleCategories[0])
            RecipeDataManager.shared.isEditingDishes = true
        } else if args.contains("-testDeleteToast") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                RecipeDataManager.shared.deleteCategory(id: "rice")
            }
        } else if args.contains("-testProfile") {
            _showProfile = State(initialValue: true)
        }
    }
    
    public var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            // Primary Fullscreen Paging (Page 0: 船长.de私厨, Page 1: 右边菜谱日历)
            TabView(selection: $primaryTab) {
                // Page 0: 船长.de私厨 (主页)
                CategoryListView(
                    categories: dataManager.categories,
                    selectedCategory: $selectedCategory,
                    selectedDishId: selectedDish?.id,
                    onSelectDish: { dish, frame in
                        selectedDishFrame = frame
                        selectedDish = dish
                    },
                    onTapMore: {
                        showProfile = true
                    },
                    onGoToCalendar: {
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                            primaryTab = 1
                        }
                    }
                )
                .tag(0)
                
                // Page 1: 菜谱日历 (位于右侧，主页向左划/右侧切入)
                RecipeCalendarView(
                    dishes: allDishes,
                    cookingRecords: $cookingRecords,
                    onSelectDish: { dish, frame in
                        selectedDishFrame = frame
                        selectedDish = dish
                    },
                    onGoToRecipes: {
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                            primaryTab = 0
                        }
                    },
                    onTapProfile: {
                        showProfile = true
                    }
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
            .background(PageScrollViewFinder(disabled: isPagingDisabled))
            
            // Layer 3: 3D Flip & Pull-Down Book-Close Modal (Video 2 Exact Interaction)
            if let dish = selectedDish {
                DishDetailModalView(
                    dish: dish,
                    sourceFrame: selectedDishFrame,
                    onLogCooked: { loggedDish in
                        logTodayCooked(dish: loggedDish)
                    },
                    onDismiss: {
                        selectedDish = nil
                    }
                )
                .zIndex(200)
            }
            
            // Layer 4: Global Toast Banner Overlay
            VStack {
                Spacer()
                ToastBannerView(dataManager: dataManager)
                    .padding(.bottom, 28)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .zIndex(300)
            
            // Layer 5: Recipe Parsing Morphing Animation (极简纯色线条灵动岛形变加载动效)
            if workflowManager.showParsingOverlay {
                RecipeParsingMorphView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                        removal: .scale(scale: 0.92).combined(with: .opacity)
                    ))
                    .zIndex(500)
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-testProfile") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showProfile = true
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-testCardCycle") {
                // Simulate tapping the first card in the 2-column grid (left column, row 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    selectedDishFrame = CGRect(x: 20, y: 122, width: 174, height: 222)
                    selectedDish = DishCategory.sampleCategories[0].dishes[0]
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView {
                showProfile = false
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    // MARK: - Widget Deep Link Handling
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mealcoll" else { return }
        let host = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        switch host {
        case "calendar":
            withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                selectedCategory = nil
                selectedDish = nil
                primaryTab = 1
            }
        case "category":
            if let catId = queryItems.first(where: { $0.name == "id" })?.value,
               let category = dataManager.categories.first(where: { $0.id == catId }) {
                withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                    primaryTab = 0
                    selectedDish = nil
                    selectedCategory = category
                }
            }
        case "dish":
            if let dishId = queryItems.first(where: { $0.name == "id" })?.value,
               let dish = allDishes.first(where: { $0.id == dishId }) {
                selectedDishFrame = .zero
                selectedDish = dish
            }
        case "import":
            let source = queryItems.first(where: { $0.name == "source" })?.value ?? "link"
            withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                primaryTab = 0
                selectedCategory = nil
                selectedDish = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                NotificationCenter.default.post(
                    name: Notification.Name("MealCollTriggerImport"),
                    object: nil,
                    userInfo: ["source": source]
                )
            }
        default:
            break
        }
    }
    
    // MARK: - Log Cooking for Today
    private func logTodayCooked(dish: Dish) {
        let calendar = Calendar.current
        let today = Date()
        if let idx = cookingRecords.firstIndex(where: { calendar.isDateInToday($0.date) && $0.dishId == dish.id }) {
            cookingRecords.remove(at: idx)
        } else {
            let record = CookingRecord(
                date: today,
                dishId: dish.id,
                note: "今天亲手做了：\(dish.name)，美味达成！"
            )
            cookingRecords.insert(record, at: 0)
        }
    }
}

// MARK: - UIPageViewController Queuing ScrollView Introspector
public struct PageScrollViewFinder: UIViewRepresentable {
    public var disabled: Bool
    
    public init(disabled: Bool) {
        self.disabled = disabled
    }
    
    public func makeUIView(context: Context) -> UIView {
        let view = PageHelperView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        let coordinator = context.coordinator
        view.onDidMoveToWindow = { [weak coordinator] in
            guard let coordinator = coordinator else { return }
            Self.togglePageScrolling(from: view, disabled: self.disabled, coordinator: coordinator)
        }
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            Self.togglePageScrolling(from: uiView, disabled: disabled, coordinator: context.coordinator)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        weak var pageScrollView: UIScrollView?
    }
    
    private static func togglePageScrolling(from view: UIView, disabled: Bool, coordinator: Coordinator) {
        let scrollView: UIScrollView?
        if let cached = coordinator.pageScrollView {
            scrollView = cached
        } else {
            var root: UIView? = view
            while let parent = root?.superview {
                root = parent
            }
            let targetView = view.window ?? root
            scrollView = targetView.flatMap { findPagingScrollView(in: $0) }
            coordinator.pageScrollView = scrollView
        }
        
        if let sv = scrollView {
            if sv.isScrollEnabled == disabled {
                sv.isScrollEnabled = !disabled
                #if DEBUG
                print("[PageScrollViewFinder] Set isScrollEnabled = \(!disabled) on \(type(of: sv))")
                #endif
            }
        }
    }
    
    private static func findPagingScrollView(in root: UIView) -> UIScrollView? {
        if let sv = root as? UIScrollView {
            let name = String(describing: type(of: sv))
            if name.contains("Paging") || name.contains("Queuing") {
                return sv
            }
            if let nextVC = sv.next as? UIViewController, String(describing: type(of: nextVC)).contains("PageViewController") {
                return sv
            }
            if let parentName = sv.superview.map({ String(describing: type(of: $0)) }), parentName.contains("Paging") {
                return sv
            }
        }
        for sub in root.subviews {
            if let found = findPagingScrollView(in: sub) {
                return found
            }
        }
        return nil
    }
}

private class PageHelperView: UIView {
    var onDidMoveToWindow: (() -> Void)?
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onDidMoveToWindow?()
        }
    }
}
