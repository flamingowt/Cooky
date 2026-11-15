import Foundation

public struct DishCategory: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let englishName: String
    public let subtitle: String
    public let updatedTimeAgo: String
    public let iconName: String
    public let dishes: [Dish]
    
    public var count: Int {
        dishes.count
    }
    
    public init(
        id: String,
        name: String,
        englishName: String,
        subtitle: String,
        updatedTimeAgo: String,
        iconName: String,
        dishes: [Dish]
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.subtitle = subtitle
        self.updatedTimeAgo = updatedTimeAgo
        self.iconName = iconName
        self.dishes = dishes
    }
}

extension DishCategory {
    public static let sampleCategories: [DishCategory] = [
        // 1. 米饭 (Rice)
        DishCategory(
            id: "rice",
            name: "米饭精选",
            englishName: "Classic Rice Bowls",
            subtitle: "粒粒香浓 · 碳水带来的纯粹治愈",
            updatedTimeAgo: "2 小时前",
            iconName: "takeoutbag.and.cup.and.straw.fill",
            dishes: [
                Dish(
                    id: "rice_claypot",
                    name: "广式腊味煲仔饭",
                    englishName: "Cantonese Claypot Rice",
                    categoryId: "rice",
                    imageName: "rice_claypot",
                    subtitle: "焦香金黄的灵魂锅巴与醇厚腊味",
                    description: "选用正宗丝苗米与广式皇上皇腊味，以砂锅文火焖煮。开盖淋上特调豉油，米香四溢，底部微焦酥脆的锅巴让人欲罢不能。",
                    tag: "主厨招牌",
                    rating: 4.9,
                    cookingTime: "25 分钟",
                    calories: "580 kcal",
                    ingredients: ["丝苗米", "广式腊肠", "腊肉", "菜心", "秘制煲仔豉油"],
                    flavor: "咸甜微焦 · 香浓"
                ),
                Dish(
                    id: "rice_unagi",
                    name: "炙烤蒲烧鳗鱼饭",
                    englishName: "Glazed Unagi Donburi",
                    categoryId: "rice",
                    imageName: "rice_unagi",
                    subtitle: "肥美软糯 · 浓郁酱汁沁入米芯",
                    description: "精选肥嫩活鳗炭火慢烤，反复刷淋传承秘制蒲烧酱汁，外皮微焦胶质丰腴，搭配撒满海苔丝与山椒粉的珍珠米饭。",
                    tag: "人气必点",
                    rating: 4.9,
                    cookingTime: "20 分钟",
                    calories: "620 kcal",
                    ingredients: ["日本鳗鱼", "越光米", "蒲烧酱汁", "海苔丝", "山椒粉"],
                    flavor: "鲜甜浓厚 · 软糯"
                ),
                Dish(
                    id: "rice_curry",
                    name: "日式浓香咖喱蛋包饭",
                    englishName: "Japanese Curry Omurice",
                    categoryId: "rice",
                    imageName: "rice_curry",
                    subtitle: "滑嫩流心蛋裙与慢熬果香咖喱",
                    description: "香炒茄汁鸡肉饭包裹在如丝绸般流心的旋风蛋裙之中，浇上慢火熬制四小时的果香牛肉咖喱，口感层层递进。",
                    tag: "治愈系",
                    rating: 4.8,
                    cookingTime: "18 分钟",
                    calories: "540 kcal",
                    ingredients: ["可生食鸡蛋", "洋葱鸡肉炒饭", "自熬果香咖喱", "黄油", "鲜奶油"],
                    flavor: "甘甜微辛 · 顺滑"
                ),
                Dish(
                    id: "rice_hainan",
                    name: "南洋经典海南鸡饭",
                    englishName: "Hainanese Chicken Rice",
                    categoryId: "rice",
                    imageName: "rice_hainan",
                    subtitle: "皮脆肉滑 · 鸡汤与香兰叶焖饭",
                    description: "慢火浸熟的三黄鸡浸入冰水皮脆肉嫩，搭配鸡油与香兰叶、斑斓叶生滚焖煮的油饭，佐以三色灵魂蘸酱（姜蓉、辣椒酱、黑酱油）。",
                    tag: "经典南洋",
                    rating: 4.8,
                    cookingTime: "30 分钟",
                    calories: "510 kcal",
                    ingredients: ["三黄鸡", "鸡油香饭", "斑斓叶", "姜蓉酱", "特调辣椒酱"],
                    flavor: "清鲜滑嫩 · 葱香"
                ),
                Dish(
                    id: "rice_bibimbap",
                    name: "韩式石锅热气拌饭",
                    englishName: "Korean Hot Stone Bibimbap",
                    categoryId: "rice",
                    imageName: "rice_bibimbap",
                    subtitle: "滋滋作响 · 丰富的时蔬与流心蛋",
                    description: "滚烫石锅中铺满七种缤纷时蔬与调味牛肉末，打入新鲜流心蛋，拌入自制苹果甜辣酱，一口咬下尽是丰富的脆爽层次。",
                    tag: "热气腾腾",
                    rating: 4.7,
                    cookingTime: "15 分钟",
                    calories: "490 kcal",
                    ingredients: ["米饭", "肥牛碎", "菠菜", "豆芽", "香菇", "韩式拌饭酱"],
                    flavor: "香辣微甜 · 焦脆"
                ),
                Dish(
                    id: "rice_paella",
                    name: "西班牙海鲜藏红花饭",
                    englishName: "Spanish Seafood Paella",
                    categoryId: "rice",
                    imageName: "rice_paella",
                    subtitle: "满锅青口海虾与金黄藏红花香",
                    description: "传统大铁盘烹制，选用西班牙圆米与珍稀藏红花慢煮，吸收深海大虾、青口贝与墨鱼的极鲜汁水，米粒弹牙干爽。",
                    tag: "异域海鲜",
                    rating: 4.9,
                    cookingTime: "35 分钟",
                    calories: "560 kcal",
                    ingredients: ["西班牙圆米", "黑虎虾", "青口贝", "鱿鱼圈", "藏红花", "柠檬"],
                    flavor: "鲜香四溢 · 浓郁"
                ),
                Dish(
                    id: "rice_beef_don",
                    name: "日式汁烧肥牛温泉蛋丼",
                    englishName: "Sukiyaki Beef & Onsen Egg Bowl",
                    categoryId: "rice",
                    imageName: "dish_beef",
                    subtitle: "鲜嫩肥牛浸润甜咸汁 · 戳破流心蛋",
                    description: "选用谷饲安格斯雪花肥牛与甘甜洋葱丝，以秘制寿喜汁微沸慢煨。铺在饱满米饭上，点缀一颗温润流心温泉蛋，酱汁香浓扑鼻。",
                    tag: "大口吃肉",
                    rating: 4.9,
                    cookingTime: "15 分钟",
                    calories: "590 kcal",
                    ingredients: ["肥牛卷", "可生食温泉蛋", "洋葱", "日式甜酱油", "海苔丝", "白芝麻"],
                    flavor: "咸甜多汁 · 蛋香醇厚"
                ),
                Dish(
                    id: "rice_shrimp_fried",
                    name: "扬州翡翠手剥鲜虾炒饭",
                    englishName: "Yangzhou Emerald Shrimp Fried Rice",
                    categoryId: "rice",
                    imageName: "dish_shrimp",
                    subtitle: "粒粒金黄包裹米粒 · 鲜嫩弹牙大虾",
                    description: "选用隔夜丝苗米与土鸡蛋黄金炒制，粒粒金黄分明。搭配鲜活手剥青虾仁、甜青豆与火腿丁，镬气十足，清鲜干爽。",
                    tag: "经典功夫",
                    rating: 4.8,
                    cookingTime: "12 分钟",
                    calories: "480 kcal",
                    ingredients: ["丝苗米饭", "鲜活海虾仁", "农家土鸡蛋", "金华火腿丁", "甜脆青豆", "香葱"],
                    flavor: "镬气清香 · 鲜咸弹牙"
                ),
                Dish(
                    id: "rice_pork_chop",
                    name: "黄金酥脆厚切炸猪排饭",
                    englishName: "Crispy Katsu Donburi",
                    categoryId: "rice",
                    imageName: "dish_pork",
                    subtitle: "卡滋卡滋金黄外酥 · 锁住鲜甜肉汁",
                    description: "精选中段厚切梅花肉，裹上日式生面包糠现炸至金黄酥脆。切块后淋上微酸解腻的特制猪排酱，搭配高丽菜丝与越光米饭。",
                    tag: "满足首选",
                    rating: 4.9,
                    cookingTime: "22 分钟",
                    calories: "650 kcal",
                    ingredients: ["厚切猪排", "日式生面包屑", "高丽菜丝", "越光米", "秘制炸猪排酱", "黄芥末"],
                    flavor: "外酥里嫩 · 咸酸香脆"
                ),
                Dish(
                    id: "rice_mapo",
                    name: "正宗川味麻婆豆腐盖浇饭",
                    englishName: "Authentic Sichuan Mapo Tofu Rice",
                    categoryId: "rice",
                    imageName: "dish_mapo",
                    subtitle: "红亮油润 · 麻辣鲜香烫酥嫩",
                    description: "遵循川菜精髓，汉源大红袍花椒与郫县陈年豆瓣酱煸出红油，嫩豆腐滑而不烂，牛肉碎焦酥喷香，浇在热米饭上是绝佳米饭杀手。",
                    tag: "米饭杀手",
                    rating: 4.8,
                    cookingTime: "16 分钟",
                    calories: "510 kcal",
                    ingredients: ["嫩豆腐", "手剁牛肉末", "郫县豆瓣酱", "汉源花椒粉", "蒜苗", "东北大米"],
                    flavor: "麻辣烫香 · 鲜醇滑嫩"
                ),
                Dish(
                    id: "rice_kungpao",
                    name: "老牌宫保鸡丁香米盖饭",
                    englishName: "Kung Pao Chicken Rice Bowl",
                    categoryId: "rice",
                    imageName: "dish_kungpao",
                    subtitle: "荔枝微辣复合味型 · 脆花生与嫩鸡丁",
                    description: "新鲜鸡腿肉切丁大火快滑，搭配酥脆油炸花生米与干红辣椒，糊辣荔枝味汁裹满每一粒鸡肉，酸甜适口微带麻香。",
                    tag: "传统名菜",
                    rating: 4.7,
                    cookingTime: "14 分钟",
                    calories: "530 kcal",
                    ingredients: ["鲜鸡腿肉", "酥脆花生", "干红辣椒", "大葱白", "宫保秘汁", "五常大米"],
                    flavor: "糊辣荔枝 · 酸甜微辛"
                ),
                Dish(
                    id: "rice_salmon",
                    name: "炙烤三文鱼牛油果波奇饭",
                    englishName: "Torched Salmon & Avocado Poke",
                    categoryId: "rice",
                    imageName: "dish_veggie",
                    subtitle: "焦香三文鱼搭配绵密牛油果 · 清爽低卡",
                    description: "法罗群岛厚切三文鱼表面微火炙烤激发出丰美油脂香气，配以熟透牛油果、鲜甜芒果与海藻沙拉，淋上日式焙煎芝麻油醋汁。",
                    tag: "轻食健康",
                    rating: 4.9,
                    cookingTime: "10 分钟",
                    calories: "450 kcal",
                    ingredients: ["刺身三文鱼", "牛油果", "海藻沙拉", "熟芒果丁", "藜麦珍珠米", "焙煎芝麻汁"],
                    flavor: "清新脂香 · 丰富爽口"
                ),
                Dish(
                    id: "rice_taiwan_lu",
                    name: "台式古早味金牌卤肉饭",
                    englishName: "Taiwanese Braised Pork Rice",
                    categoryId: "rice",
                    imageName: "rice_claypot",
                    subtitle: "慢火细熬胶质丰润 · 拌米饭每一口都拉丝",
                    description: "选用肥瘦相间的精品五花肉切小丁，慢火煸出油脂，加入炸红葱酥、陈年金兰酱油与八角慢火细熬三小时，浓稠胶质裹满白饭。",
                    tag: "夜市记忆",
                    rating: 4.8,
                    cookingTime: "30 分钟",
                    calories: "570 kcal",
                    ingredients: ["精品带皮五花肉", "自炸红葱酥", "台湾古早酱油", "五香卤蛋", "腌黄瓜片"],
                    flavor: "咸甜微糯 · 葱油喷香"
                ),
                Dish(
                    id: "rice_risotto",
                    name: "黑松露牛肝菌奶油烩饭",
                    englishName: "Black Truffle & Porcini Risotto",
                    categoryId: "rice",
                    imageName: "rice_curry",
                    subtitle: "意式浓醇奶香 · 意大利圆米粒粒弹牙",
                    description: "选用意大利皮埃蒙特Arborio米与野生牛肝菌，以白葡萄酒与鸡高汤文火慢搅乳化，出锅前拌入帕玛森干酪与顶级黑松露油。",
                    tag: "奢享西餐",
                    rating: 4.9,
                    cookingTime: "25 分钟",
                    calories: "520 kcal",
                    ingredients: ["Arborio大米", "野生牛肝菌", "黑松露酱", "帕玛森干酪", "安佳黄油", "干白葡萄酒"],
                    flavor: "浓郁奶香 · 菌香扑鼻"
                ),
                Dish(
                    id: "rice_pineapple",
                    name: "泰式金牌菠萝海鲜炒饭",
                    englishName: "Thai Royal Pineapple Seafood Rice",
                    categoryId: "rice",
                    imageName: "rice_paella",
                    subtitle: "装盛在新鲜菠萝壳中 · 果香与海味碰撞",
                    description: "整颗熟透甜菠萝掏空做盅，米饭拌入金黄咖喱粉大火快炒，加入黑虎虾仁、鱿鱼圈、腰果与肉松，酸甜交织，南洋度假风扑面而来。",
                    tag: "热带风情",
                    rating: 4.8,
                    cookingTime: "20 分钟",
                    calories: "500 kcal",
                    ingredients: ["新鲜菠萝", "泰国香米", "海虾仁", "香脆腰果", "肉松", "泰国黄咖喱粉"],
                    flavor: "酸甜清香 · 咖喱微辛"
                ),
                Dish(
                    id: "rice_dolsot_beef",
                    name: "炭火厚烧牛舌双拼盖饭",
                    englishName: "Charcoal Grilled Beef Tongue Rice",
                    categoryId: "rice",
                    imageName: "rice_unagi",
                    subtitle: "厚切弹脆牛舌 · 秘制椒盐葱白烧汁",
                    description: "精选牛舌根部嫩肉，厚切花刀炭火急烤至微焦香脆，刷上特制柠檬椒盐汁与青葱油，搭配软糯越光米，口感爽脆多汁嚼劲十足。",
                    tag: "老饕推荐",
                    rating: 4.9,
                    cookingTime: "18 分钟",
                    calories: "580 kcal",
                    ingredients: ["精品厚切牛舌", "越光米", "自制葱油酱", "白芝麻", "鲜柠檬汁", "七味粉"],
                    flavor: "炭火焦香 · 爽脆咸鲜"
                ),
                Dish(
                    id: "rice_loco_moco",
                    name: "夏威夷风情汉堡肉煎蛋饭",
                    englishName: "Hawaiian Loco Moco",
                    categoryId: "rice",
                    imageName: "dish_beef",
                    subtitle: "手打纯牛肉汉堡排 · 浓郁肉汁覆满流心蛋",
                    description: "经典夏威夷街头名吃，纯手打安格斯牛肉排煎至表面金黄锁汁，盛于米饭上，盖上双面溏心太阳蛋，浇上慢熬浓缩牛骨肉汁（Brown Gravy）。",
                    tag: "碳水炸弹",
                    rating: 4.7,
                    cookingTime: "18 分钟",
                    calories: "640 kcal",
                    ingredients: ["纯牛肉汉堡排", "太阳溏心蛋", "自熬牛肉浓汁", "热白米饭", "煎蘑菇片"],
                    flavor: "肉香四溢 · 浓汁丰盈"
                ),
                Dish(
                    id: "rice_oyakodon",
                    name: "东京浅草嫩鸡亲子丼",
                    englishName: "Tokyo Asakusa Oyakodon",
                    categoryId: "rice",
                    imageName: "rice_hainan",
                    subtitle: "半熟滑蛋裹满鸡腿肉 · 昆布柴鱼高汤清甜",
                    description: "鸡腿肉切块在柴鱼昆布高汤中煨煮至熟嫩，分两次倒入蛋液，保持蛋白半熟凝固、蛋黄流动的滑润状态，滑入米饭上温热治愈。",
                    tag: "温润家常",
                    rating: 4.8,
                    cookingTime: "12 分钟",
                    calories: "470 kcal",
                    ingredients: ["鲜鸡腿肉", "可生食鸡蛋", "洋葱丝", "柴鱼昆布高汤", "味醂", "三叶芹"],
                    flavor: "清甜嫩滑 · 蛋香浓厚"
                ),
                Dish(
                    id: "rice_kimchi_fried",
                    name: "黄金拉丝芝士泡菜炒饭",
                    englishName: "Melted Cheese Kimchi Fried Rice",
                    categoryId: "rice",
                    imageName: "rice_bibimbap",
                    subtitle: "酸爽老坛泡菜大火爆香 · 厚厚马苏里拉拉丝",
                    description: "熟成老坛辣白菜切碎与五花肉丁煸炒，拌入香米饭大火翻炒透香，表面铺满一层厚厚的马苏里拉芝士火枪炙烤融化，拉丝可达半米。",
                    tag: "热量狂欢",
                    rating: 4.8,
                    cookingTime: "15 分钟",
                    calories: "560 kcal",
                    ingredients: ["老坛泡菜", "薄切五花肉", "马苏里拉芝士", "韩式海苔碎", "香油", "米饭"],
                    flavor: "酸辣开胃 · 浓郁拉丝"
                ),
                Dish(
                    id: "rice_duck",
                    name: "老北京脆皮烤鸭荷叶香饭",
                    englishName: "Beijing Crispy Roast Duck Rice",
                    categoryId: "rice",
                    imageName: "rice_claypot",
                    subtitle: "枣木明炉现烤鸭皮酥脆 · 秘制甜面酱与黄瓜丝",
                    description: "枣木烤鸭片出油亮酥脆鸭皮与带肉鸭片，配上荷叶清蒸香米饭、手工熬制陈年甜面酱与细嫩京葱白丝，皮脆肉嫩，回味甘甜。",
                    tag: "宫廷风味",
                    rating: 4.9,
                    cookingTime: "20 分钟",
                    calories: "590 kcal",
                    ingredients: ["枣木挂炉烤鸭", "荷叶蒸香米", "自熬甜面酱", "葱丝黄瓜条", "脆鸭皮"],
                    flavor: "皮酥肉香 · 酱甜不腻"
                )
            ]
        ),
        
        // 2. 面食 (Noodles & Pasta)
        DishCategory(
            id: "noodles",
            name: "特色面食",
            englishName: "Artisanal Noodles & Pasta",
            subtitle: "劲道爽滑 · 传承千年的面点风味",
            updatedTimeAgo: "3 小时前",
            iconName: "fork.knife",
            dishes: [
                Dish(
                    id: "noodles_beef",
                    name: "兰州手拉清汤牛肉面",
                    englishName: "Lanzhou Hand-pulled Beef Noodles",
                    categoryId: "noodles",
                    imageName: "noodles_beef",
                    subtitle: "一清二白三红四绿五黄的极致考究",
                    description: "清晨现熬牛腿骨老汤，手工拉制细面爽滑劲道。铺上白萝卜片、厚切酱牛肉，撒满翠绿蒜苗与红亮油泼辣子，一碗汤清气正。",
                    tag: "非遗手艺",
                    rating: 4.9,
                    cookingTime: "12 分钟",
                    calories: "460 kcal",
                    ingredients: ["手拉拉面", "慢熬黄牛骨汤", "卤牛肉", "白萝卜", "香菜蒜苗", "油泼辣子"],
                    flavor: "鲜美醇香 · 劲道"
                ),
                Dish(
                    id: "noodles_ramen",
                    name: "博多特浓豚骨拉面",
                    englishName: "Hakata Tonkotsu Ramen",
                    categoryId: "noodles",
                    imageName: "noodles_ramen",
                    subtitle: "熬煮16小时浓郁白汤与厚切叉烧",
                    description: "猪骨大火翻滚熬出如乳白丝滑汤底，配以低温慢煮极嫩叉烧肉、半熟糖心溏心蛋、爽脆黑木耳丝，浓香挂面，一口入魂。",
                    tag: "浓郁殿堂",
                    rating: 4.9,
                    cookingTime: "15 分钟",
                    calories: "650 kcal",
                    ingredients: ["博多极细面", "特浓豚骨汤", "秘制叉烧", "溏心蛋", "黑木耳", "烤海苔"],
                    flavor: "醇厚浓郁 · 鲜甜"
                ),
                Dish(
                    id: "noodles_pasta",
                    name: "传统意式经典肉酱面",
                    englishName: "Classic Bolognese Tagliatelle",
                    categoryId: "noodles",
                    imageName: "noodles_pasta",
                    subtitle: "红酒慢炖小牛肉与现刨帕玛森干酪",
                    description: "手工揉制意式宽面裹满慢火慢煨三小时的波隆那肉酱，番茄酸甜与肉香完美平衡，顶层飘洒丰厚熟成24个月帕玛森雪花干酪。",
                    tag: "西式经典",
                    rating: 4.8,
                    cookingTime: "20 分钟",
                    calories: "520 kcal",
                    ingredients: ["手工意面", "小牛肉肉酱", "圣马扎诺番茄", "红酒", "帕玛森干酪"],
                    flavor: "酸甜肉香 · 馥郁"
                ),
                Dish(
                    id: "noodles_dandan",
                    name: "正宗川味担担面",
                    englishName: "Authentic Sichuan Dan Dan Noodles",
                    categoryId: "noodles",
                    imageName: "noodles_dandan",
                    subtitle: "麻酱碎米芽菜与香酥肉臊",
                    description: "碗底打入秘制红油、复制酱油、宜宾碎米芽菜与浓香芝麻酱。细面捞起趁热拌匀，每根面条都挂满肉臊与花生碎，麻辣鲜香。",
                    tag: "川香四溢",
                    rating: 4.8,
                    cookingTime: "10 分钟",
                    calories: "480 kcal",
                    ingredients: ["水叶子面", "炒肉脆臊", "宜宾芽菜", "川味红油", "芝麻酱", "花生碎"],
                    flavor: "麻辣咸鲜 · 浓香"
                ),
                Dish(
                    id: "noodles_wonton",
                    name: "广式鲜虾云吞竹升面",
                    englishName: "Cantonese Wonton Noodle Soup",
                    categoryId: "noodles",
                    imageName: "noodles_wonton",
                    subtitle: "弹牙全蛋竹升面与整颗爽脆鲜虾",
                    description: "传统鸭蛋竹竿压制的极弹细面，汤底加入大地鱼、虾子与罗汉果慢吊。云吞皮薄如蝉翼，包裹整颗大虾仁与猪后腿肉，爽脆多汁。",
                    tag: "弹牙鲜爽",
                    rating: 4.8,
                    cookingTime: "12 分钟",
                    calories: "430 kcal",
                    ingredients: ["全蛋竹升面", "整只大虾仁", "大地鱼虾子汤", "韭黄", "鲜猪肉"],
                    flavor: "清甜甘鲜 · 爽脆"
                ),
                Dish(
                    id: "noodles_soba",
                    name: "京都宇治鸭肉冷荞麦面",
                    englishName: "Kyoto Duck Kamo Seiro Soba",
                    categoryId: "noodles",
                    imageName: "noodles_soba",
                    subtitle: "石磨荞麦香气与炙烤合鸭暖汁",
                    description: "八割石磨荞麦面冰镇滤水，保持最爽利的断口性与清雅谷香。蘸入加入炙烤大葱与肥美鸭肉的滚烫鲣节出汁，冷热交融妙趣横生。",
                    tag: "清雅素心",
                    rating: 4.7,
                    cookingTime: "15 分钟",
                    calories: "390 kcal",
                    ingredients: ["石磨荞麦面", "炙烤鸭胸肉", "千寿大葱", "鲣节高汤", "本枯节"],
                    flavor: "清冽微甜 · 麦香"
                )
            ]
        ),
        
        // 3. 炒菜 (Stir-fry & Dishes)
        DishCategory(
            id: "dishes",
            name: "经典炒菜",
            englishName: "Master Stir-Fry Dishes",
            subtitle: "镬气十足 · 烈火快炒与舌尖交响",
            updatedTimeAgo: "1 小时前",
            iconName: "flame.fill",
            dishes: [
                Dish(
                    id: "dish_kungpao",
                    name: "传统糊辣宫保鸡丁",
                    englishName: "Traditional Kung Pao Chicken",
                    categoryId: "dishes",
                    imageName: "dish_kungpao",
                    subtitle: "荔枝小炒 · 脆嫩弹牙的花生与鸡腿肉",
                    description: "大火热油炝炸花椒干椒，下入鲜嫩去骨鸡腿丁快速翻炒。加入金黄酥脆花生仁与大葱白段，淋上酸甜微辣的黄金比例保宁醋荔枝汁。",
                    tag: "火候绝活",
                    rating: 4.9,
                    cookingTime: "15 分钟",
                    calories: "420 kcal",
                    ingredients: ["鲜鸡腿肉", "去皮炸花生", "大葱段", "四川干辣椒", "保宁醋", "白糖"],
                    flavor: "酸甜微辣 · 糊香"
                ),
                Dish(
                    id: "dish_mapo",
                    name: "沸腾手作麻婆豆腐",
                    englishName: "Sizzling Mapo Tofu",
                    categoryId: "dishes",
                    imageName: "dish_mapo",
                    subtitle: "麻辣鲜香烫嫩酥 · 舌尖的红油风暴",
                    description: "正宗汉源红花椒与郫县豆瓣酱炒出红亮红油，牛肉酥脆焦香，嫩豆腐滑如凝脂三入三芡。出锅撒满一层厚厚的青花椒面，麻到心尖。",
                    tag: "米饭杀手",
                    rating: 4.9,
                    cookingTime: "18 分钟",
                    calories: "360 kcal",
                    ingredients: ["嫩豆腐", "黄牛肉末", "郫县红油豆瓣", "汉源花椒粉", "蒜苗", "水豆粉"],
                    flavor: "麻辣滚烫 · 嫩滑"
                ),
                Dish(
                    id: "dish_beef",
                    name: "爆炒鲜嫩小炒黄牛肉",
                    englishName: "Fiery Stir-Fried Beef with Wild Chili",
                    categoryId: "dishes",
                    imageName: "dish_beef",
                    subtitle: "猛火十秒出锅 · 鲜辣爽脆的香菜与野山椒",
                    description: "精选云贵高原散养黄牛吊龙部位，横刀薄切。大铁锅烧至冒烟，野山椒与青线椒爆香后下肉快速颠勺十余下，牛肉嫩汁瞬间锁住。",
                    tag: "镬气巅峰",
                    rating: 4.9,
                    cookingTime: "8 分钟",
                    calories: "390 kcal",
                    ingredients: ["黄牛吊龙", "野山椒", "鲜青红线椒", "小香菜", "大蒜", "生抽"],
                    flavor: "野辣鲜嫩 · 镬气"
                ),
                Dish(
                    id: "dish_shrimp",
                    name: "避风塘金蒜炒大虾",
                    englishName: "Typhoon Shelter Golden Shrimp",
                    categoryId: "dishes",
                    imageName: "dish_shrimp",
                    subtitle: "酥脆金黄蒜蓉与鲜甜弹牙基围虾",
                    description: "基围虾开背炸至外壳酥脆如薄纸，肉质紧实弹牙。以慢火炸制的金黄蒜蓉、豆豉与面包糠同锅爆炒，蒜香浓烈扑鼻，连虾壳都能吃下。",
                    tag: "港味招牌",
                    rating: 4.8,
                    cookingTime: "20 分钟",
                    calories: "450 kcal",
                    ingredients: ["深海鲜活大虾", "自炸金蒜蓉", "炸豆豉", "香脆面包糠", "红椒碎"],
                    flavor: "蒜香焦脆 · 咸鲜"
                ),
                Dish(
                    id: "dish_pork",
                    name: "经典秘制鱼香肉丝",
                    englishName: "Shredded Pork with Garlic Sauce",
                    categoryId: "dishes",
                    imageName: "dish_pork",
                    subtitle: "无鱼而有鱼香 · 泡椒与木耳冬笋丝",
                    description: "川菜二十四味型中的鱼香巅峰。四川自贡自酿老坛泡红辣椒剁碎炒出红油，里脊肉丝滑嫩幼细，黑木耳与冬笋丝清脆爽口，余味悠长。",
                    tag: "经典下饭",
                    rating: 4.8,
                    cookingTime: "16 分钟",
                    calories: "380 kcal",
                    ingredients: ["猪里脊肉", "自贡泡红椒", "冬笋丝", "黑木耳", "葱姜蒜", "秘制鱼香汁"],
                    flavor: "咸甜酸辣 · 鲜香"
                ),
                Dish(
                    id: "dish_veggie",
                    name: "东北特色地三鲜",
                    englishName: "Stir-Fried Eggplant, Potato & Pepper",
                    categoryId: "dishes",
                    imageName: "dish_veggie",
                    subtitle: "土豆软糯 · 茄子吸汁 · 青椒清脆",
                    description: "选用秋季沙土豆与紫茄块，过油定型后加入大蒜末快速翻炒。浓郁芡汁将地里最新鲜的三味食材紧密包裹，香浓下饭不输大鱼大肉。",
                    tag: "家常地道",
                    rating: 4.7,
                    cookingTime: "18 分钟",
                    calories: "330 kcal",
                    ingredients: ["沙地土豆", "圆紫茄", "青尖椒", "蒜末", "生抽芡汁"],
                    flavor: "咸甜适口 · 软糯"
                )
            ]
        ),
        
        // 4. 饮品 (Drinks & Beverages)
        DishCategory(
            id: "drinks",
            name: "特调饮品",
            englishName: "Signature Drinks & Refreshments",
            subtitle: "清爽解腻 · 每一口都是沁凉甘甜",
            updatedTimeAgo: "刚刚更新",
            iconName: "cup.and.saucer.fill",
            dishes: [
                Dish(
                    id: "drink_mango",
                    name: "港式手作杨枝甘露",
                    englishName: "Mango Pomelo Sago Delight",
                    categoryId: "drinks",
                    imageName: "drink_mango",
                    subtitle: "新鲜鹰嘴芒泥 · 爆汁红西柚与西米",
                    description: "新鲜成熟鹰嘴芒打制细腻果泥，加入香滑椰浆与进口水牛奶。底部铺满晶莹剔透的水晶西米，顶层点缀满满手剥南非红西柚粒，酸甜解腻。",
                    tag: "解腻首选",
                    rating: 4.9,
                    cookingTime: "8 分钟",
                    calories: "280 kcal",
                    ingredients: ["鹰嘴芒果肉", "南非红西柚", "泰国小西米", "特浓椰浆", "水牛奶"],
                    flavor: "浓郁甘甜 · 爆汁"
                ),
                Dish(
                    id: "drink_matcha",
                    name: "京都宇治浓抹茶拿铁",
                    englishName: "Kyoto Uji Matcha Latte",
                    categoryId: "drinks",
                    imageName: "drink_matcha",
                    subtitle: "石臼研磨一番茶与北海道牧场厚乳",
                    description: "选用日本京都宇治产特级研磨抹茶粉，手工茶筅击打出细腻翠绿茶沫。缓缓注入冰镇北海道牧场纯牛乳，茶香高雅微苦回甘，层次分明。",
                    tag: "茶道美学",
                    rating: 4.9,
                    cookingTime: "5 分钟",
                    calories: "190 kcal",
                    ingredients: ["宇治一番抹茶", "纯牛奶", "天然三温糖浆", "冰块"],
                    flavor: "茶香清幽 · 微苦回甘"
                ),
                Dish(
                    id: "drink_lemon",
                    name: "手打鸭屎香暴打柠檬茶",
                    englishName: "Hand-Pounded Duck Shit Lemon Tea",
                    categoryId: "drinks",
                    imageName: "drink_lemon",
                    subtitle: "广东香水柠檬与潮州凤凰单丛乌龙",
                    description: "现切厚片高山香水柠檬，雪克杯中全力手打释放丰富精油香气。撞入冰镇高香凤凰单丛（鸭屎香）茶汤，酸爽激荡，瞬间唤醒味蕾。",
                    tag: "暴爽解腻",
                    rating: 4.8,
                    cookingTime: "4 分钟",
                    calories: "140 kcal",
                    ingredients: ["高山香水柠檬", "潮州鸭屎香单丛", "天然冰糖浆", "纯净冰块"],
                    flavor: "酸爽激爽 · 兰香"
                ),
                Dish(
                    id: "drink_coffee",
                    name: "海盐生椰冷萃拿铁",
                    englishName: "Sea Salt Coconut Cold Brew",
                    categoryId: "drinks",
                    imageName: "drink_coffee",
                    subtitle: "鲜榨生椰乳与18小时慢速滴滤咖啡",
                    description: "选用日晒耶加雪菲咖啡豆慢速冷萃18小时，自带柑橘花香。搭配冷压鲜榨生椰乳，最后撒入一撮现磨法国盐之花海盐，咸甜交织。",
                    tag: "特调咖啡",
                    rating: 4.8,
                    cookingTime: "6 分钟",
                    calories: "160 kcal",
                    ingredients: ["冷萃咖啡原液", "菲诺厚椰乳", "法国盐之花", "冰块"],
                    flavor: "椰香醇厚 · 咸甜"
                ),
                Dish(
                    id: "drink_boba",
                    name: "手作黑糖虎纹鲜奶波霸",
                    englishName: "Brown Sugar Boba Fresh Milk",
                    categoryId: "drinks",
                    imageName: "drink_boba",
                    subtitle: "慢火古法熬煮黑糖与Q弹木薯珍珠",
                    description: "古法台湾黑糖块慢熬两小时，珍珠裹满温热浓稠的黑糖浆，在杯壁挂出如同虎纹般的绚丽纹理。倒入冰纯牛奶，冷热对撞，软糯Q弹。",
                    tag: "甜蜜暴击",
                    rating: 4.8,
                    cookingTime: "10 分钟",
                    calories: "340 kcal",
                    ingredients: ["手作木薯珍珠", "古法手工黑糖", "鲜牛奶", "黑糖挂壁浆"],
                    flavor: "焦香甜蜜 · Q弹"
                ),
                Dish(
                    id: "drink_berry",
                    name: "满杯多肉莓莓气泡水",
                    englishName: "Fresh Berry Sparkling Soda",
                    categoryId: "drinks",
                    imageName: "drink_berry",
                    subtitle: "鲜草莓覆盆子果泥与激爽苏打水",
                    description: "新鲜当季红颜草莓与覆盆子手捣出丰沛果汁，加入天然薄荷叶与青柠片，注入激爽充沛的苏打水，气泡在舌尖跳跃，粉嫩治愈。",
                    tag: "清凉果香",
                    rating: 4.7,
                    cookingTime: "5 分钟",
                    calories: "110 kcal",
                    ingredients: ["红颜草莓", "覆盆子", "青柠片", "新鲜薄荷", "无糖苏打水"],
                    flavor: "清爽激泡 · 莓果香"
                )
            ]
        )
    ]
}

