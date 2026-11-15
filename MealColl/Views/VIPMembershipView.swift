import SwiftUI

/// 私厨 VIP 会员购买界面（契合 MealColl 极简暖调私厨风格与香槟金视觉体系）
public struct VIPMembershipView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = RecipeDataManager.shared
    
    @State private var selectedPlanId: String = "annual"
    @State private var isPurchasing: Bool = false
    
    private struct VIPPlan: Identifiable {
        let id: String
        let title: String
        let price: String
        let originalPrice: String
        let unit: String
        let subtitle: String
        let badge: String?
        let savingsText: String
    }
    
    private let plans: [VIPPlan] = [
        VIPPlan(
            id: "annual",
            title: "年度尊享",
            price: "¥38",
            originalPrice: "¥188",
            unit: "/ 年",
            subtitle: "折合 ¥3.1 / 月",
            badge: "限时 2 折",
            savingsText: "立省 ¥150"
        ),
        VIPPlan(
            id: "lifetime",
            title: "终身私厨",
            price: "¥98",
            originalPrice: "¥398",
            unit: "/ 永久",
            subtitle: "一次开通 · 永久有效",
            badge: "超值买断",
            savingsText: "立省 ¥300"
        ),
        VIPPlan(
            id: "monthly",
            title: "月度体验",
            price: "¥12",
            originalPrice: "¥30",
            unit: "/ 月",
            subtitle: "灵活按月体验",
            badge: nil,
            savingsText: "立省 ¥18"
        )
    ]
    
    private struct VIPPrivilege: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }
    
    private let privileges: [VIPPrivilege] = [
        VIPPrivilege(
            icon: "sparkles",
            title: "AI 菜谱解析无限次",
            description: "短视频、长图、网页链接全路径极速提取，不限每日次数"
        ),
        VIPPrivilege(
            icon: "book.closed.fill",
            title: "专属秘制私厨菜谱库",
            description: "畅享主厨精选风味菜谱、火候秘诀与独家调味量化配比"
        ),
        VIPPrivilege(
            icon: "icloud.and.arrow.up.fill",
            title: "多端备份与队列无忧",
            description: "大类卡片、下厨日历、待入库任务跨设备安全留存不丢失"
        ),
        VIPPrivilege(
            icon: "doc.richtext.fill",
            title: "高清图文导出无水印",
            description: "一键生成杂志级私厨食谱长图与步骤卡片，方便打印分享"
        )
    ]
    
    private var selectedPlan: VIPPlan {
        plans.first(where: { $0.id == selectedPlanId }) ?? plans[0]
    }
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroMembershipCard
                        planSelectionSection
                        privilegesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 130)
                }
            }
            
            bottomPurchaseBar
        }
    }
    
    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if dataManager.isVIP {
                    dataManager.showToast("已恢复私厨 VIP 尊享身份")
                } else {
                    dataManager.showToast("暂未查询到历史订阅记录")
                }
            }) {
                Text("恢复购买")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("私厨 VIP")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 30, height: 30)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
    
    // MARK: - 香槟金会员主卡
    private var heroMembershipCard: some View {
        ZStack(alignment: .topTrailing) {
            // 柔和的装饰菱形高光
            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 150, height: 150)
                .blur(radius: 26)
                .offset(x: 36, y: -42)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    MinimalistAvatarView(size: 46, showCameraBadge: false)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(dataManager.userNickname)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            
                            HStack(spacing: 3) {
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 9, weight: .black))
                                Text(dataManager.isVIP ? "VIP 已激活" : "未开通")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(dataManager.isVIP ? Color(red: 0.984, green: 0.886, blue: 0.655) : .black.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(dataManager.isVIP ? Color.black : Color.black.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        
                        Text(dataManager.isVIP ? "当前方案：\(dataManager.vipPlanName.isEmpty ? "尊享会员" : dataManager.vipPlanName)" : "限时 2 折 · 开启你的专属美味灵感库")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black.opacity(0.75))
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.black)
                        Text("船长私厨 · VIP 尊享版")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(.black)
                    }
                    
                    Text("解锁无限次 AI 视频/图文解析 · 秘制私厨食谱全库畅享")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.black.opacity(0.78))
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.984, green: 0.886, blue: 0.655),
                            Color(red: 0.929, green: 0.765, blue: 0.455)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 0.82, green: 0.65, blue: 0.30).opacity(0.28), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }
    
    // MARK: - 会员方案选择
    private var planSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选择会员方案")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("限时特惠")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.58, green: 0.38, blue: 0.06))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.984, green: 0.886, blue: 0.655).opacity(0.7))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 10) {
                ForEach(plans) { plan in
                    let isSelected = (plan.id == selectedPlanId)
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            selectedPlanId = plan.id
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(plan.title)
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(plan.price)
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(plan.unit)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(plan.originalPrice)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(uiColor: .tertiaryLabel))
                                .strikethrough()
                            
                            Spacer(minLength: 2)
                            
                            Text(plan.subtitle)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(isSelected ? Color(red: 0.58, green: 0.38, blue: 0.06) : .secondary)
                                .lineLimit(1)
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isSelected ? Color(red: 0.996, green: 0.976, blue: 0.918) : Color(uiColor: .systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    isSelected ? Color(red: 0.82, green: 0.61, blue: 0.22) : Color.black.opacity(0.06),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .overlay(alignment: .topTrailing) {
                            if let badge = plan.badge {
                                Text(badge)
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(isSelected ? .white : .black)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        isSelected
                                        ? Color.black
                                        : Color(red: 0.984, green: 0.886, blue: 0.655)
                                    )
                                    .clipShape(Capsule())
                                    .offset(x: -6, y: -9)
                            }
                        }
                        .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 10 : 4, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.top, 6)
        }
    }
    
    // MARK: - 尊享特权说明
    private var privilegesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("VIP 专属特权")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(.primary)
            
            VStack(spacing: 14) {
                ForEach(privileges) { item in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.984, green: 0.886, blue: 0.655).opacity(0.55),
                                            Color(red: 0.929, green: 0.765, blue: 0.455).opacity(0.35)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                            
                            Image(systemName: item.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 0.56, green: 0.37, blue: 0.06))
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundColor(.primary)
                            Text(item.description)
                                .font(.system(size: 12.5))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
            )
        }
    }
    
    // MARK: - 底部悬浮购买栏
    private var bottomPurchaseBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(selectedPlan.price)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text(selectedPlan.unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(selectedPlan.title) · \(selectedPlan.savingsText)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(Color(red: 0.58, green: 0.38, blue: 0.06))
                }
                
                Spacer()
                
                Button(action: {
                    performPurchase()
                }) {
                    HStack(spacing: 6) {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                            Text("开通中...")
                        } else {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(dataManager.isVIP ? "立即升级 / 续费" : "立即开通 VIP")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
                }
                .disabled(isPurchasing)
                .buttonStyle(ScaleButtonStyle())
            }
            
            Text("点击立即开通即可体验私厨 VIP 全套尊享特权")
                .font(.system(size: 10.5))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.06), radius: 14, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func performPurchase() {
        guard !isPurchasing else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isPurchasing = true
        let chosenPlan = selectedPlan
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            isPurchasing = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dataManager.activateVIP(planName: chosenPlan.title)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                dismiss()
            }
        }
    }
}

