const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');
const { execSync } = require('child_process');

const PORT = 3888;
const BASE_DIR = __dirname;
const STORAGE_DIR = path.join(BASE_DIR, 'storage');
const SCRIPTS_DIR = path.join(BASE_DIR, 'scripts');
const PUBLIC_DIR = path.join(BASE_DIR, 'public');

[STORAGE_DIR, SCRIPTS_DIR, PUBLIC_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

function parseJsonBody(req) {
    return new Promise((resolve, reject) => {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                resolve(body ? JSON.parse(body) : {});
            } catch (err) {
                reject(err);
            }
        });
        req.on('error', reject);
    });
}

function generatePromptForMedia({ title = '烹饪菜谱', timelineText = '', sheetNames = [], duration = 0, isImages = false, noteDesc = '' }) {
    const inputContext = isImages
        ? `- 素材类型: 图文菜谱笔记 (${sheetNames.length} 张时序拼图，每张图片标有 #01 图, #02 图...)
- 原笔记文案描述:
\`\`\`text
${noteDesc.slice(0, 1500)}
\`\`\`
- 图片 OCR 文本日志:
\`\`\`text
${timelineText.slice(0, 2500)}
\`\`\``
        : `- 视频总时长: 约 ${duration.toFixed(1)} 秒
- 采样大图网格: ${sheetNames.length} 张时序大图 (${sheetNames.join(', ')})，每图 5×10 网格，帧编号 #01, #02... 并标有秒数时间戳 (如 0.5s, 1.5s)。
- 关键时间轴日志 (timeline.txt) 节选:
\`\`\`text
${timelineText.slice(0, 2500)}
\`\`\``;

    const frameRule = isImages
        ? `### 4.1 封面图与步骤配图 (图文模式)
- 封面图 \`cover_frame\`: 选最具代表性的成品装盘图，格式为 \`"spec": "cover_main:img_01"\` 或 \`"cover_main:img_01@x,y,w,h"\`；
- 步骤图 \`frame_spec\`: 每步选用对应步骤图序号，格式为 \`"step01:img_02"\` 或加局部特写坐标 \`"step01:img_02@x,y,w,h"\`。`
        : `### 4.1 封面图 (cover_frame)
- 仅输出 1 张封面主图 \`cover_main\`；
- 优先选择**成品装盘全景帧**（整道菜完整呈现、光线明亮、构图饱满、色彩有食欲）；
- 格式: \`"spec": "cover_main:秒数"\` 或带裁切 \`"cover_main:秒数@x,y,w,h"\`。

### 4.2 正文步骤图选帧与 ROI 裁切
- 选帧原则：优先选择动作最清晰、状态最典型的帧；
- **局部特写裁切 (ROI Crop)**：若画面为固定机位俯拍，当前步骤仅操作局部，必须使用 \`@x,y,w,h\` 裁切聚焦到操作主体。`;

    return `# Role
你是一位精通中西方烹饪与烘焙工艺的美食主编兼视觉导演，同时具备出版级印前质检能力。请结合输入的${isImages ? '「图文拼图与 OCR 笔记日志」' : '「视频逐秒 OCR 时间轴日志 (timeline.txt)」与「5×10 时间轴缩略图网格」'}，提取并规整出一份符合手机 App 极致排版的标准菜谱 JSON。

# Input Material Context
${inputContext}

# Core Rules & Task Guidelines

## 0. 【前置守门】输入内容属性判断
- 请首先综合审视输入的画面网格、OCR 字幕及文本描述：
- 🚫 **若判定为「非食物类」**（如风景旅行、日常穿搭、数码测评、宠物日常、非美食搞笑等完全不包含食物或烹饪的内容）：
  - **立即终止后续一切菜谱提取流程**；
  - **严格仅输出以下纯 JSON，禁止输出任何其他字段**：
  \`\`\`json
  {
    "category": "非食物"
  }
  \`\`\`
- 🍳 **若判定为「食物类」**，则继续执行下方核心任务。

## 1. 真实工序自然切分（不设步骤数限制，支持纯图还原）
- **步骤数量不设硬性上下限**：完全根据真实工艺自然划分，逻辑连贯即可（3 步到 10+ 步均可，严禁生硬合并或刻意水步数）。
- **两类场景的自适应处理**：
  - **场景 A（含完整/部分制作过程）**：按客观时序切分工序，每步选取动作清晰的关键帧 \`frame_spec\`；
  - **场景 B（无制作步骤，仅有食物成品图片/探店美食摄影）**：
    - 大模型根据成品食物外观与菜品类型，**结合自身烹饪专业知识推断并输出完整的标准工序**；
    - **此时所有步骤均不需要配图，每步的 \`frame_spec\` 直接置空传空字符串 \`""\`**；
    - 食材表中的所有用量全部标记为估算：\`"is_estimated": true\`；
    - 封面图 \`cover_frame\` 依然选用成品的精选图片。
- **每步必须包含**：
  - \`number\`: 步骤序号（两位数字："01", "02", "03"...）；
  - \`title\`: 简明双短语标题（≤12 个汉字，单行不折行）；
  - \`duration_badge\`: 时间/火候胶囊（如 "▸ 腌制 15 分钟"、"▸ 大火快炒 2 分钟"）；
  - \`text\`: 一行一句核心操作正文，精炼动作与状态；
  - \`frame_spec\`: 选帧及 ROI 裁切规范（**纯食物无制作过程时置空传 \`""\`**）。
- 🚫 **【去掉原片要点】**：步骤中不要输出任何 tip 或原片字幕提示框，保持步骤纯粹精炼。

## 2. 原片未提及信息的专业常识估算法则
原片/文字中通常缺少用量克数、难度、时间、热量，模型必须结合家常 1~2 人份常识进行科学合理估算：
- **难度 (difficulty)**：
  - 快手凉拌、焯水快炒 ➔ \`"Easy"\`
  - 涉及上浆腌肉、煎炒烹炸、火候控制 ➔ \`"Medium"\`
  - 复杂发酵、烘焙精准温控、多重复杂吊汤 ➔ \`"Chef"\`
- **时间 (time)**：
  - 纯快手小炒 ➔ \`"10m"\` 或 \`"15m"\`
  - 包含腌制/炒制/普通炖煮 ➔ \`"20m"\` 或 \`"25m"\`
  - 大菜慢炖/慢烤 ➔ \`"35m"\` 以上
- **热量卡路里 (calories)**：根据主要食材与油脂进行估算（纯数字字符串）：
  - 清爽低脂/蔬果 ➔ \`"350"\` ~ \`"450"\`
  - 家常荤素小炒/面食米饭 ➔ \`"550"\` ~ \`"680"\`
  - 红烧五花/油炸重油 ➔ \`"750"\` ~ \`"900"\`
- **用量真实抽取 vs 模型估算标识 (is_estimated)**：
  - 若原片配料卡/字幕中明确给出了克数或数量（如"西红柿2个"、"生抽2勺"），提取真实值并标记 \`"is_estimated": false\`；
  - 若原片未说明用料多少，模型按 1~2 人份常识估算（如肉类 150~250g，主料 200~300g），必须标记 \`"is_estimated": true\`，并在 amount 中标注类似 \`"/ 200g (估)"\` 或 \`"1个 (估)"\`。

## 3. 严厉禁令（Negative Constraints）
- 🚫 **【禁止脑补食材】**：原片/字幕中未出现、画面也完全未使用的食材，**绝对严禁自己凭空捏造添加**！只允许提取画面或解说中切实出现的原料！
- 🚫 **【不要抽取 Rating】**：App 界面中未出现的字段（如 rating 等）完全不需要，禁止输出。

## 4. 食材数量与调料配比量化铁律
- 📐 **食材数量 (metrics.ingredient_count)**：
  - **铁律：食材数量严格等于「主料品类数 + 辅料品类数」**（**绝对不要把调料算进去**！）。例如 2 种主料 + 4 种辅料，食材数量必须是 6！
- 📏 **调料配比必须严格量化对齐 (ratio 0.10 ~ 1.00)**：
  - **调料无需生成颜色**：**不要输出任何颜色字段**，系统将对所有调料进度条使用统一的固定品牌色。
  - **只要单位和勺数相同，长度必须完全一致**！严禁同一单位随意给不同的 ratio。
  - **标准量化对应表**：
    - \`"少许" / "适量" / "少许盐" / "半茶匙"\` ➔ \`ratio: 0.20\`
    - \`"1勺" / "1汤匙" / "10~15g"\` ➔ \`ratio: 0.45\`（所有"1勺"的调料必须统一为 0.45！）
    - \`"2勺" / "2汤匙" / "25~30g"\` ➔ \`ratio: 0.80\`（所有"2勺"的调料必须统一为 0.80！）
    - \`"3勺及以上"\` ➔ \`ratio: 1.00\`

## 5. 关键帧挑选规则
${frameRule}

## 6. 主厨复盘 (Chef's Notes)
提炼 2~3 条实用建议（科学原理、火候控制、新手避坑）。

# Output JSON Format (请严格仅输出以下纯 JSON，不要有任何 Markdown 说明)
\`\`\`json
{
  "name": "菜谱中文名 (如: 西北番茄牛肉炒面片)",
  "englishName": "英文名称 (如: Northwestern Stir-Fried Dough Drop Noodles with Beef)",
  "subtitle": "一句话卖点副标题 (如: 劲道爽滑 · 茄汁浓郁挂汁)",
  "description": "菜品风味故事与口感详述 (约80-120字)",
  "cover_frame": {
    "spec": "${isImages ? 'cover_main:img_01' : 'cover_main:0.6'}",
    "description": "装盘成品镜头"
  },
  "metrics": {
    "difficulty": "Medium",
    "time": "20m",
    "ingredient_count": 6,
    "calories": "630"
  },
  "ingredients": {
    "main": [
      { "name": "面片坯", "english": "Dough Drops", "amount": "250g", "is_estimated": true },
      { "name": "牛里脊", "english": "Beef Tenderloin", "amount": "200g", "is_estimated": true }
    ],
    "auxiliary": [
      { "name": "西红柿", "english": "Tomato", "amount": "2个", "is_estimated": false },
      { "name": "洋葱", "english": "Onion", "amount": "半个", "is_estimated": false },
      { "name": "青椒", "english": "Green Pepper", "amount": "1个", "is_estimated": false },
      { "name": "葱姜蒜", "english": "Aromatics", "amount": "适量", "is_estimated": false }
    ],
    "seasonings": [
      { "name": "生抽", "english": "Light soy sauce", "amount": "2勺", "ratio": 0.80 },
      { "name": "老抽", "english": "Dark soy sauce", "amount": "1勺", "ratio": 0.45 },
      { "name": "辣椒面", "english": "Chili flakes", "amount": "1勺", "ratio": 0.45 },
      { "name": "白胡椒、十三香", "english": "White pepper, spices", "amount": "适量", "ratio": 0.20 }
    ]
  },
  "steps": [
    {
      "number": "01",
      "title": "牛肉切片抓拌上浆",
      "duration_badge": "▸ 腌制 15 分钟 (00:04 - 00:10)",
      "text": "牛里脊逆纹切薄片，加入生抽、老抽、白胡椒抓匀，淋食用油锁水腌制。",
      "frame_spec": "${isImages ? 'step01:img_02@0.1,0.2,0.8,0.65' : 'step01:8.5@0.10,0.20,0.80,0.65'}"
    }
  ],
  "chefs_notes": [
    "面片切忌煮过头，大火煮至八分熟断生捞出过冷水，炒制时才筋道耐嚼不易坨烂。",
    "西红柿去皮切小丁，先加少许盐大火煸出浓郁沙汁，再下面片吸收原汁最入味。"
  ]
}
\`\`\``;
}

function getDemoRecipeData() {
    return {
        "name": "西北番茄牛肉炒面片",
        "englishName": "Northwestern Stir-Fried Dough Drop Noodles with Beef",
        "subtitle": "劲道爽滑 · 茄汁浓郁挂汁",
        "description": "精选筋道面片现揪现煮，牛里脊薄切上浆锁水，大火爆出红油辣香，配以鲜番茄熬出的浓厚原汁，面片吸饱汤汁，酸辣咸香过瘾。",
        "cover_frame": {
            "spec": "cover_main:0.6",
            "description": "成品盛盘特写镜头"
        },
        "metrics": {
            "difficulty": "Medium",
            "time": "20m",
            "ingredient_count": 6,
            "calories": "630"
        },
        "ingredients": {
            "main": [
                { "name": "面片坯", "english": "Dough Drops", "amount": "250g", "is_estimated": true },
                { "name": "牛里脊", "english": "Beef Tenderloin", "amount": "200g", "is_estimated": true }
            ],
            "auxiliary": [
                { "name": "西红柿", "english": "Tomato", "amount": "2个", "is_estimated": false },
                { "name": "洋葱", "english": "Onion", "amount": "半个", "is_estimated": false },
                { "name": "青椒", "english": "Green Pepper", "amount": "1个", "is_estimated": false },
                { "name": "葱姜蒜", "english": "Aromatics", "amount": "适量", "is_estimated": false }
            ],
            "seasonings": [
                { "name": "生抽", "english": "Light soy sauce", "amount": "2勺", "ratio": 0.80 },
                { "name": "老抽", "english": "Dark soy sauce", "amount": "1勺", "ratio": 0.45 },
                { "name": "辣椒面", "english": "Chili flakes", "amount": "1勺", "ratio": 0.45 },
                { "name": "白胡椒、十三香", "english": "White pepper, spices", "amount": "适量", "ratio": 0.20 }
            ]
        },
        "steps": [
            {
                "number": "01",
                "title": "牛肉切片抓拌上浆",
                "duration_badge": "▸ 腌制 15 分钟 (00:04 - 00:10)",
                "text": "牛里脊逆纹切薄片，加入生抽、老抽、白胡椒抓匀，淋食用油锁水腌制。",
                "frame_spec": "step01:8.5@0.10,0.20,0.80,0.65"
            },
            {
                "number": "02",
                "title": "沸水揪面片过凉",
                "duration_badge": "▸ 水开揪面 (00:14 - 00:17)",
                "text": "锅中水沸腾后揪入面片，大火煮熟后捞出过凉水沥干备用。",
                "frame_spec": "step02:15.5@0.10,0.20,0.80,0.65"
            },
            {
                "number": "03",
                "title": "滑炒牛肉变色盛出",
                "duration_badge": "▸ 热油滑炒 (00:18 - 00:22)",
                "text": "起锅烧油，油热放入腌好的牛肉，快速大火翻炒至变色立即控油盛出。",
                "frame_spec": "step03:20.5@0.10,0.20,0.80,0.65"
            },
            {
                "number": "04",
                "title": "爆香料头炒红油",
                "duration_badge": "▸ 爆出香味 (00:22 - 00:27)",
                "text": "锅留底油放入葱姜蒜末爆香，加入一大勺上色辣椒面翻炒出诱人红油。",
                "frame_spec": "step04:25.5@0.10,0.20,0.80,0.65"
            },
            {
                "number": "05",
                "title": "煸炒番茄熬出浓汤",
                "duration_badge": "▸ 熬出茄汁 (00:28 - 00:31)",
                "text": "倒入去皮西红柿丁大火翻炒，利用酸性与红油结合，翻炒出浓郁沙沙汤汁。",
                "frame_spec": "step05:29.5@0.10,0.20,0.80,0.65"
            },
            {
                "number": "06",
                "title": "下入配菜与综合调料",
                "duration_badge": "▸ 复合调味 (00:32 - 00:36)",
                "text": "放入其余配菜翻炒，加入生抽、老抽、花椒粉、十三香、盐与鸡精翻炒均匀。",
                "frame_spec": "step06:34.5@0.10,0.20,0.80,0.65"
            },
            {
                "number": "07",
                "title": "淋入面汤下煮熟面片",
                "duration_badge": "▸ 煮汤融合 (00:37 - 00:40)",
                "text": "锅中淋入少许煮面原汤，倒入沥干的面片与牛肉，大火快速翻炒裹匀汤汁。",
                "frame_spec": "step07:38.5@0.10,0.20,0.80,0.65"
            },
            {
                "number": "08",
                "title": "收汁出锅成品装盘",
                "duration_badge": "▸ 翻炒出锅 (00:41 - 00:44)",
                "text": "大火翻匀收汁，面片吸饱红亮鲜浓汤汁，盛入盘中即可趁热享用。",
                "frame_spec": "step08:43.0@0.05,0.15,0.90,0.70"
            }
        ],
        "chefs_notes": [
            "面片切忌煮过头，大火煮至八分熟断生捞出过冷水，炒制时才筋道耐嚼不易坨烂。",
            "西红柿去皮切小丁，先加少许盐大火煸出浓郁沙汁，再下面片吸收原汁最入味。",
            "牛肉滑炒时间不要超过30秒，变色即起锅，最后一步合炒让余温加热，保持极嫩口感。"
        ]
    };
}

const server = http.createServer(async (req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        return res.end();
    }

    try {
        if (pathname === '/api/process' && req.method === 'POST') {
            const body = await parseJsonBody(req);
            let { videoSource, inputType } = body;
            
            const sessionId = 'session_' + Date.now();
            const sessionDir = path.join(STORAGE_DIR, sessionId);
            fs.mkdirSync(sessionDir, { recursive: true });

            let isImagesMode = false;
            let noteDesc = '';
            let resolvedVideoPath = '';
            let imageFiles = [];

            if (inputType === 'sample' || !videoSource) {
                const defaultSample = '/Users/dufangchi/Desktop/炒面片.mov';
                if (!fs.existsSync(defaultSample)) {
                    return res.writeHead(400, { 'Content-Type': 'application/json' })
                        .end(JSON.stringify({ error: '系统未找到测试视频：' + defaultSample }));
                }
                resolvedVideoPath = defaultSample;
            } else if (inputType === 'url') {
                console.log(`Resolving media from URL input: ${videoSource}`);
                const resolverScript = path.join(SCRIPTS_DIR, 'media_resolver.py');
                let resolveResult;
                try {
                    const rawOutput = execSync(`python3 "${resolverScript}" "${videoSource.replace(/"/g, '\\"')}" "${sessionDir}"`, {
                        encoding: 'utf-8',
                        timeout: 25000
                    });
                    resolveResult = JSON.parse(rawOutput.trim());
                } catch (resErr) {
                    return res.writeHead(400, { 'Content-Type': 'application/json' })
                        .end(JSON.stringify({ error: '解析失败: ' + resErr.message }));
                }

                if (resolveResult.error) {
                    return res.writeHead(400, { 'Content-Type': 'application/json' })
                        .end(JSON.stringify({ error: resolveResult.error }));
                }

                if (resolveResult.type === 'images') {
                    isImagesMode = true;
                    imageFiles = resolveResult.image_paths || [];
                    noteDesc = resolveResult.desc || '';
                } else if (resolveResult.type === 'video') {
                    resolvedVideoPath = resolveResult.video_path;
                    noteDesc = resolveResult.desc || '';
                }
            } else if (inputType === 'upload' && body.videoBase64) {
                const isImg = body.fileType && body.fileType.startsWith('image/');
                if (isImg) {
                    isImagesMode = true;
                    const destImg = path.join(sessionDir, 'img_01.jpg');
                    fs.writeFileSync(destImg, Buffer.from(body.videoBase64, 'base64'));
                    imageFiles = [destImg];
                } else {
                    const destVideo = path.join(sessionDir, 'uploaded_video.mp4');
                    fs.writeFileSync(destVideo, Buffer.from(body.videoBase64, 'base64'));
                    resolvedVideoPath = destVideo;
                }
            }

            let meta = {};
            let timelineText = '';

            if (isImagesMode && imageFiles.length > 0) {
                const stitchScript = path.join(SCRIPTS_DIR, 'stitch_images.swift');
                const quotedImgs = imageFiles.map(p => `"${p}"`).join(' ');
                execSync(`swift "${stitchScript}" "${sessionDir}" ${quotedImgs}`, { encoding: 'utf-8', timeout: 30000 });

                const metaFile = path.join(sessionDir, 'meta.json');
                meta = fs.existsSync(metaFile) ? JSON.parse(fs.readFileSync(metaFile, 'utf-8')) : {};
                const timelineFile = path.join(sessionDir, 'timeline.txt');
                timelineText = fs.existsSync(timelineFile) ? fs.readFileSync(timelineFile, 'utf-8') : '';
            } else {
                if (!resolvedVideoPath || !fs.existsSync(resolvedVideoPath)) {
                    return res.writeHead(400, { 'Content-Type': 'application/json' })
                        .end(JSON.stringify({ error: '视频文件不存在或下载不完整' }));
                }

                const fstat = fs.statSync(resolvedVideoPath);
                if (fstat.size < 50000) {
                    return res.writeHead(400, { 'Content-Type': 'application/json' })
                        .end(JSON.stringify({ error: '下载到的视频文件异常（小于50KB），可能链接被平台拦截。请直接上传本地视频或使用内置示例测试！' }));
                }

                fs.writeFileSync(path.join(sessionDir, 'video_path.txt'), resolvedVideoPath);
                const sampleScript = path.join(SCRIPTS_DIR, 'sample_and_sheet.swift');
                execSync(`swift "${sampleScript}" "${resolvedVideoPath}" "${sessionDir}" 3`, {
                    encoding: 'utf-8',
                    timeout: 45000
                });

                const metaFile = path.join(sessionDir, 'meta.json');
                meta = fs.existsSync(metaFile) ? JSON.parse(fs.readFileSync(metaFile, 'utf-8')) : {};
                const timelineFile = path.join(sessionDir, 'timeline.txt');
                timelineText = fs.existsSync(timelineFile) ? fs.readFileSync(timelineFile, 'utf-8') : '';
            }

            const sheetUrls = (meta.sheets || []).map(sheet => `/storage/${sessionId}/${sheet}`);
            const prompt = generatePromptForMedia({
                title: isImagesMode ? '图文菜谱笔记' : path.basename(resolvedVideoPath),
                timelineText,
                sheetNames: meta.sheets || [],
                duration: meta.duration || 0,
                isImages: isImagesMode,
                noteDesc
            });

            return res.writeHead(200, { 'Content-Type': 'application/json' })
                .end(JSON.stringify({
                    sessionId,
                    isImages: isImagesMode,
                    duration: meta.duration || 0,
                    totalFrames: meta.totalFrames || meta.totalImages || 0,
                    sheets: sheetUrls,
                    prompt,
                    demoRecipe: getDemoRecipeData()
                }));
        }

        if (pathname === '/api/extract-and-render' && req.method === 'POST') {
            const body = await parseJsonBody(req);
            const { sessionId, recipeJson } = body;
            
            if (!sessionId || !recipeJson) {
                return res.writeHead(400, { 'Content-Type': 'application/json' })
                    .end(JSON.stringify({ error: 'Missing sessionId or recipeJson' }));
            }

            const sessionDir = path.join(STORAGE_DIR, sessionId);
            const cropsDir = path.join(sessionDir, 'crops');
            fs.mkdirSync(cropsDir, { recursive: true });

            const metaFile = path.join(sessionDir, 'meta.json');
            const meta = fs.existsSync(metaFile) ? JSON.parse(fs.readFileSync(metaFile, 'utf-8')) : {};
            const isImagesMode = meta.type === 'images';

            if (!isImagesMode) {
                const videoPathFile = path.join(sessionDir, 'video_path.txt');
                const targetVideoPath = fs.existsSync(videoPathFile) 
                    ? fs.readFileSync(videoPathFile, 'utf-8').trim()
                    : '/Users/dufangchi/Desktop/炒面片.mov';

                const specs = [];
                if (recipeJson.cover_frame && recipeJson.cover_frame.spec) {
                    specs.push(recipeJson.cover_frame.spec);
                }
                if (Array.isArray(recipeJson.steps)) {
                    recipeJson.steps.forEach((st, idx) => {
                        if (st.frame_spec && st.frame_spec.trim() !== '') {
                            specs.push(st.frame_spec.trim());
                        }
                    });
                }

                if (specs.length > 0) {
                    const extractScript = path.join(SCRIPTS_DIR, 'extract_keyframes.swift');
                    const quotedSpecs = specs.map(s => `"${s}"`).join(' ');
                    try {
                        execSync(`swift "${extractScript}" "${targetVideoPath}" "${cropsDir}" ${quotedSpecs}`, {
                            encoding: 'utf-8',
                            timeout: 30000
                        });
                    } catch (err) {
                        console.error('Extract error:', err.message);
                    }
                }

                const coverSpec = recipeJson.cover_frame ? recipeJson.cover_frame.spec : 'cover_main:0.6';
                const coverName = coverSpec ? coverSpec.split(':')[0] : 'cover_main';
                recipeJson.cover_image_url = `/storage/${sessionId}/crops/${coverName}.jpg`;

                if (Array.isArray(recipeJson.steps)) {
                    recipeJson.steps.forEach((st, idx) => {
                        if (st.frame_spec && st.frame_spec.trim() !== '') {
                            const stepName = st.frame_spec.trim().split(':')[0];
                            st.image_url = `/storage/${sessionId}/crops/${stepName}.jpg`;
                        } else {
                            st.image_url = null; // 纯食物无制作过程，步骤不配图
                        }
                    });
                }
            } else {
                recipeJson.cover_image_url = `/storage/${sessionId}/img_01.jpg`;
                if (Array.isArray(recipeJson.steps)) {
                    recipeJson.steps.forEach((st, idx) => {
                        const imgIdx = Math.min(idx + 1, meta.totalImages || 1);
                        st.image_url = `/storage/${sessionId}/img_${String(imgIdx).padStart(2, '0')}.jpg`;
                    });
                }
            }

            return res.writeHead(200, { 'Content-Type': 'application/json' })
                .end(JSON.stringify({
                    success: true,
                    recipe: recipeJson
                }));
        }

        if (pathname.startsWith('/storage/')) {
            const relPath = pathname.replace('/storage/', '');
            const filePath = path.join(STORAGE_DIR, relPath);
            if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
                const ext = path.extname(filePath).toLowerCase();
                const mimeTypes = {
                    '.jpg': 'image/jpeg',
                    '.jpeg': 'image/jpeg',
                    '.png': 'image/png',
                    '.mp4': 'video/mp4',
                    '.mov': 'video/quicktime',
                    '.txt': 'text/plain; charset=utf-8',
                    '.json': 'application/json'
                };
                res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
                return fs.createReadStream(filePath).pipe(res);
            } else {
                res.writeHead(404);
                return res.end('File not found');
            }
        }

        let filePath = path.join(PUBLIC_DIR, pathname === '/' ? 'index.html' : pathname);
        if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
            const ext = path.extname(filePath).toLowerCase();
            const mimeTypes = {
                '.html': 'text/html; charset=utf-8',
                '.css': 'text/css; charset=utf-8',
                '.js': 'application/javascript; charset=utf-8'
            };
            res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'text/plain' });
            return fs.createReadStream(filePath).pipe(res);
        }

        res.writeHead(404);
        res.end('Not found');
    } catch (e) {
        console.error('Server error:', e);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
    }
});

server.listen(PORT, () => {
    console.log(`🍳 MealColl 菜谱工作流测试台已更新 Prompt 规则 (Port ${PORT})`);
});
