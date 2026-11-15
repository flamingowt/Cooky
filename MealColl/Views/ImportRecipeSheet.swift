import SwiftUI

public struct ImportRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = RecipeDataManager.shared
    
    @State private var linkText: String = ""
    @State private var isAnalyzing: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Pure white background covering entire sheet down to the bottom safe area (下面不漏字)
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Single Dashed Box Container (只有一个虚线框)
                dashedContainer
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                
                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-testImportFilled") {
                linkText = "http://xhslink.com/a/salmon_rice_6612beef 蒜香柠檬三文鱼配米饭详细做法"
            }
        }
    }
    
    // MARK: - Single Dashed Box Container
    private var dashedContainer: some View {
        ZStack {
            // Dashed Border Card
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.6, dash: [7, 5])
                )
                .foregroundColor(
                    linkText.isEmpty
                        ? Color(uiColor: .separator)
                        : Color.black.opacity(0.65)
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
            
            if linkText.isEmpty {
                // Empty state: Exactly matches user's uploaded image (只有这些内容)
                VStack(spacing: 12) {
                    // Light blue circular background with blue link badge plus icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.89, green: 0.95, blue: 1.0))
                            .frame(width: 58, height: 58)
                        
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                    }
                    
                    // Title
                    Text("点击此处直接粘贴链接")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Subtitles
                    VStack(spacing: 3) {
                        Text("支持小红书、抖音、B站、下厨房等链接")
                        Text("系统将自动解析为精美菜谱、用料配比及烹饪步骤")
                    }
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    pasteFromClipboard()
                }
            } else {
                // Filled state: Clean, no excess words (图二不要这么多字，按钮就写开始解析，颜色换成黑底白字)
                VStack(spacing: 10) {
                    // Top row: Clean clear button on the right
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                linkText = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(uiColor: .tertiaryLabel))
                        }
                    }
                    .padding(.top, 2)
                    .padding(.trailing, 2)
                    
                    // Editable Text Area (clean, concise)
                    TextEditor(text: $linkText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground).opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(maxHeight: 74)
                    
                    // Button: "开始解析", 黑底白字
                    Button(action: {
                        startParsingAndImport()
                    }) {
                        HStack(spacing: 6) {
                            if isAnalyzing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.85)
                                Text("正在解析...")
                                    .font(.system(size: 15, weight: .bold))
                            } else {
                                Text("开始解析")
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)
                    }
                    .disabled(isAnalyzing || linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 200)
    }
    
    // MARK: - Actions
    private func pasteFromClipboard() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let clipboardString = UIPasteboard.general.string, !clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                linkText = clipboardString
            }
        } else {
            // Provide realistic sample link if clipboard in simulator is empty
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                linkText = "http://xhslink.com/a/salmon_rice_6612beef 蒜香柠檬三文鱼配米饭详细做法"
            }
        }
    }
    
    private func startParsingAndImport() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isAnalyzing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            let parsedDish = generateParsedDish(from: linkText)
            let targetCategory = dataManager.categories.first?.id ?? "rice"
            
            dataManager.addDish(parsedDish, toCategoryId: targetCategory)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isAnalyzing = false
            dismiss()
        }
    }
    
    private func generateParsedDish(from text: String) -> Dish {
        let lower = text.lowercased()
        
        if lower.contains("三文鱼") || lower.contains("salmon") || lower.contains("鱼") {
            return Dish(
                id: "parsed_\(UUID().uuidString.prefix(8))",
                name: "蒜香柠檬三文鱼配米饭",
                englishName: "Pan-Seared Salmon Rice Bowl",
                categoryId: dataManager.categories.first?.id ?? "rice",
                imageName: "ing_salmon",
                subtitle: "外焦里嫩 · 蒜香浓郁柠檬清香",
                description: "精选深海厚切三文鱼，以黑胡椒与海盐腌制入味，小火香煎至鱼皮焦脆，搭配蒜香黄油柠檬汁，铺在热气腾腾的米饭上，风味极具层次。",
                tag: "小红书爆款",
                rating: 4.9,
                cookingTime: "25分钟",
                calories: "730大卡",
                ingredients: ["厚切三文鱼", "精选越光米", "洋葱", "蒜瓣", "黄油", "柠檬片"],
                flavor: "蒜香酸爽"
            )
        } else if lower.contains("牛肉") || lower.contains("牛排") || lower.contains("beef") {
            return Dish(
                id: "parsed_\(UUID().uuidString.prefix(8))",
                name: "日式和牛烧肉拌饭",
                englishName: "Wagyu Beef Donburi",
                categoryId: dataManager.categories.first?.id ?? "rice",
                imageName: "dish_beef",
                subtitle: "油脂丰腴 · 秘制酱汁拌饭绝配",
                description: "和牛薄切快速炙烤封边，浇上洋葱熬煮的日式咸甜烧肉汁，半熟温泉蛋拌开，口感润滑丰腴。",
                tag: "抖音同款",
                rating: 4.9,
                cookingTime: "18分钟",
                calories: "680大卡",
                ingredients: ["安格斯肥牛", "越光米饭", "无菌可生食鸡蛋", "紫洋葱", "白芝麻"],
                flavor: "咸甜浓郁"
            )
        } else {
            return Dish(
                id: "parsed_\(UUID().uuidString.prefix(8))",
                name: "黑松露野菌煲仔饭",
                englishName: "Truffle & Mushroom Claypot",
                categoryId: dataManager.categories.first?.id ?? "rice",
                imageName: "rice_claypot",
                subtitle: "焦香金黄锅巴 · 野山菌鲜爽",
                description: "砂锅文火焖煮丝苗米，铺满云南野菌与黑松露特调酱汁，锅边淋入猪油激出酥脆金黄锅巴，香气四溢。",
                tag: "AI智能解析",
                rating: 4.9,
                cookingTime: "25分钟",
                calories: "640大卡",
                ingredients: ["丝苗米", "黑松露酱", "牛肝菌", "广式特级腊肠", "香葱碎"],
                flavor: "菌香咸鲜"
            )
        }
    }
}
