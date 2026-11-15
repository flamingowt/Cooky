// MealColl Recipe Workflow Frontend Controller

let currentSessionId = '';
let currentSheets = [];
let demoRecipeData = null;

// DOM Elements
const stage1 = document.getElementById('stage1');
const stage2 = document.getElementById('stage2');
const stage3 = document.getElementById('stage3');

const stepNode1 = document.getElementById('stepNode1');
const stepNode2 = document.getElementById('stepNode2');
const stepNode3 = document.getElementById('stepNode3');

const urlInput = document.getElementById('urlInput');
const btnStartProcess = document.getElementById('btnStartProcess');
const processSpinner = document.getElementById('processSpinner');
const stage1Msg = document.getElementById('stage1Msg');

const btnLoadSample1 = document.getElementById('btnLoadSample1');
const btnUploadLocal = document.getElementById('btnUploadLocal');
const fileInput = document.getElementById('fileInput');

// Stage 2 elements
const sheetTabs = document.getElementById('sheetTabs');
const currentSheetImg = document.getElementById('currentSheetImg');
const sheetSubtitle = document.getElementById('sheetSubtitle');
const promptText = document.getElementById('promptText');
const btnCopyPrompt = document.getElementById('btnCopyPrompt');
const btnFillDemoJson = document.getElementById('btnFillDemoJson');
const jsonInput = document.getElementById('jsonInput');
const btnSynthesize = document.getElementById('btnSynthesize');
const synthSpinner = document.getElementById('synthSpinner');

// Stage 3 elements
const btnBackToEdit = document.getElementById('btnBackToEdit');
const btnExportSwift = document.getElementById('btnExportSwift');
const dishCoverImg = document.getElementById('dishCoverImg');
const dishTitle = document.getElementById('dishTitle');
const valDifficulty = document.getElementById('valDifficulty');
const valTime = document.getElementById('valTime');
const valCount = document.getElementById('valCount');
const valCalories = document.getElementById('valCalories');
const mainIngList = document.getElementById('mainIngList');
const auxIngList = document.getElementById('auxIngList');
const seasoningList = document.getElementById('seasoningList');
const stepsList = document.getElementById('stepsList');
const stepsCountBadge = document.getElementById('stepsCountBadge');
const chefNotesList = document.getElementById('chefNotesList');
const btnCheckIn = document.getElementById('btnCheckIn');
const checkInText = document.getElementById('checkInText');

// Lightbox
const lightboxModal = document.getElementById('lightboxModal');
const lightboxBackdrop = document.getElementById('lightboxBackdrop');
const lightboxClose = document.getElementById('lightboxClose');
const lightboxImg = document.getElementById('lightboxImg');
const lightboxTitle = document.getElementById('lightboxTitle');
const lightboxDesc = document.getElementById('lightboxDesc');

// Toast
const toastNotice = document.getElementById('toastNotice');

function showToast(msg) {
    toastNotice.textContent = msg;
    toastNotice.classList.add('show');
    setTimeout(() => {
        toastNotice.classList.remove('show');
    }, 2400);
}

function setStage(stageNum) {
    [stage1, stage2, stage3].forEach(el => el.classList.remove('active'));
    [stepNode1, stepNode2, stepNode3].forEach(el => el.classList.remove('active'));

    if (stageNum === 1) {
        stage1.classList.add('active');
        stepNode1.classList.add('active');
    } else if (stageNum === 2) {
        stage2.classList.add('active');
        stepNode1.classList.add('active');
        stepNode2.classList.add('active');
    } else if (stageNum === 3) {
        stage3.classList.add('active');
        stepNode1.classList.add('active');
        stepNode2.classList.add('active');
        stepNode3.classList.add('active');
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// 1. Process Video Action
async function processVideo({ videoSource = '', inputType = 'sample', videoBase64 = null }) {
    btnStartProcess.disabled = true;
    processSpinner.style.display = 'inline-block';
    stage1Msg.textContent = '🚀 正在调用本地算力 (AVFoundation & Vision) 对视频进行采样与时序网格拼图...';

    try {
        const res = await fetch('/api/process', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ videoSource, inputType, videoBase64 })
        });

        const data = await res.json();
        if (!res.ok || data.error) {
            throw new Error(data.error || '解析处理失败');
        }

        currentSessionId = data.sessionId;
        currentSheets = data.sheets || [];
        demoRecipeData = data.demoRecipe;

        // Render Stage 2
        renderStage2(data);
        setStage(2);
        showToast('✅ 视频采样拼图完成，已生成时序大图与 Prompt！');
    } catch (err) {
        console.error(err);
        stage1Msg.textContent = '❌ 处理失败: ' + err.message;
        showToast('处理失败: ' + err.message);
    } finally {
        btnStartProcess.disabled = false;
        processSpinner.style.display = 'none';
    }
}

// Render Stage 2
function renderStage2(data) {
    sheetSubtitle.textContent = `共采样 ${data.totalFrames || 0} 帧，视频时长 ${Number(data.duration || 0).toFixed(1)} 秒，生成 ${currentSheets.length} 张 5×10 网格时序图。`;
    
    // Render sheet tabs
    sheetTabs.innerHTML = '';
    currentSheets.forEach((sheetUrl, index) => {
        const btn = document.createElement('button');
        btn.className = `sheet-tab-btn ${index === 0 ? 'active' : ''}`;
        btn.textContent = `Sheet ${index + 1}`;
        btn.onclick = () => {
            document.querySelectorAll('.sheet-tab-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentSheetImg.src = sheetUrl;
        };
        sheetTabs.appendChild(btn);
    });

    if (currentSheets.length > 0) {
        currentSheetImg.src = currentSheets[0];
    }

    // Fill Prompt
    promptText.textContent = data.prompt || '';
    jsonInput.value = '';
}

// Click on sheet to view enlarged
currentSheetImg.onclick = () => {
    window.open(currentSheetImg.src, '_blank');
};

// Copy Prompt
btnCopyPrompt.onclick = () => {
    const text = promptText.textContent;
    navigator.clipboard.writeText(text).then(() => {
        showToast('📋 已复制全部 Prompt 到剪贴板！可发给大模型');
    }).catch(() => {
        // Fallback copy
        const ta = document.createElement('textarea');
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        showToast('📋 已复制全部 Prompt 到剪贴板！');
    });
};

// Fill demo JSON
btnFillDemoJson.onclick = () => {
    if (demoRecipeData) {
        jsonInput.value = JSON.stringify(demoRecipeData, null, 2);
        showToast('✨ 已填入西北炒面片的标准示例 JSON！');
    }
};

// Stage 1 sample button
btnLoadSample1.onclick = () => {
    urlInput.value = 'http://xhslink.com/a/sample_beef_noodles 西北番茄牛肉炒面片保姆级教学';
    processVideo({ inputType: 'sample' });
};

// Stage 1 Start button
btnStartProcess.onclick = () => {
    const text = urlInput.value.trim();
    if (!text) {
        // If empty, auto load sample
        processVideo({ inputType: 'sample' });
    } else {
        processVideo({ videoSource: text, inputType: 'url' });
    }
};

// Upload button
btnUploadLocal.onclick = () => {
    fileInput.click();
};

fileInput.onchange = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    urlInput.value = `[本地文件] ${file.name} (${(file.size / (1024 * 1024)).toFixed(1)} MB)`;
    const reader = new FileReader();
    reader.onload = () => {
        const base64 = reader.result.split(',')[1];
        processVideo({ inputType: 'upload', videoBase64: base64, fileType: file.type });
    };
    reader.readAsDataURL(file);
};

// Stage 2 Synthesize Button
btnSynthesize.onclick = async () => {
    const text = jsonInput.value.trim();
    if (!text) {
        showToast('请先粘贴大模型返回的 JSON，或点击填入示例');
        return;
    }

    let parsedJson = null;
    try {
        // Strip code fences if present
        let clean = text;
        if (clean.startsWith('```json')) clean = clean.slice(7);
        if (clean.startsWith('```')) clean = clean.slice(3);
        if (clean.endsWith('```')) clean = clean.slice(0, -3);
        parsedJson = JSON.parse(clean.trim());

        // 0. 前置判定：若为非食物类内容，直接拦截并终止
        if (parsedJson.category === '非食物') {
            showToast('🚫 大模型识别为【非食物类】，流程已终止');
            alert('🚫 流程终止通知：\n\n大模型判定当前内容为【非食物类】（不包含任何美食或烹饪信息）。\n\n按业务规则，无需提取菜谱，流程已终止。请尝试粘贴美食烹饪相关的链接！');
            return;
        }
    } catch (err) {
        showToast('❌ JSON 格式不合法，请检查标点和闭合括号: ' + err.message);
        return;
    }

    btnSynthesize.disabled = true;
    synthSpinner.style.display = 'inline-block';

    try {
        const res = await fetch('/api/extract-and-render', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                sessionId: currentSessionId,
                recipeJson: parsedJson
            })
        });

        const data = await res.json();
        if (!res.ok || data.error) {
            throw new Error(data.error || '合成裁切失败');
        }

        renderRecipeApp(data.recipe);
        setStage(3);
        showToast('🎉 菜谱已成功合成！已精准完成关键帧裁切');
    } catch (err) {
        console.error(err);
        showToast('合成失败: ' + err.message);
    } finally {
        btnSynthesize.disabled = false;
        synthSpinner.style.display = 'none';
    }
};

btnBackToEdit.onclick = () => {
    setStage(2);
};

// Render Mobile Recipe Card (1:1 with MealColl SwiftUI)
function renderRecipeApp(recipe) {
    dishTitle.textContent = recipe.name || '精选家常美味';
    dishCoverImg.src = recipe.cover_image_url || '/storage/' + currentSessionId + '/crops/cover_main.jpg';

    // Metrics: 食材数量严格等于 主料品类数 + 辅料品类数 (不含调料)
    valDifficulty.textContent = (recipe.metrics && recipe.metrics.difficulty) || 'Medium';
    valTime.textContent = (recipe.metrics && recipe.metrics.time) || '20m';
    
    const mainCount = recipe.ingredients?.main?.length || 0;
    const auxCount = recipe.ingredients?.auxiliary?.length || 0;
    const ingCategoryCount = (recipe.metrics && recipe.metrics.ingredient_count) || (mainCount + auxCount);
    valCount.textContent = ingCategoryCount;
    valCalories.textContent = (recipe.metrics && recipe.metrics.calories) || '630';

    // 1. Main Ingredients (支持显示估算标识)
    mainIngList.innerHTML = '';
    const mainItems = (recipe.ingredients && recipe.ingredients.main) || [];
    mainItems.forEach(item => {
        const card = document.createElement('div');
        card.className = 'main-ing-card';
        const estimatedBadge = item.is_estimated ? '<span class="est-tag" title="原片未给出具体克数，模型结合常识估算">估</span>' : '';
        card.innerHTML = `
            <div class="main-ing-thumb">🥩</div>
            <div class="main-ing-info">
                <div class="main-ing-name">${item.name}</div>
                <div class="main-ing-amount">${item.amount || ''} ${estimatedBadge}</div>
            </div>
        `;
        mainIngList.appendChild(card);
    });

    // 2. Auxiliary Ingredients
    auxIngList.innerHTML = '';
    const auxItems = (recipe.ingredients && recipe.ingredients.auxiliary) || [];
    auxItems.forEach(item => {
        const card = document.createElement('div');
        card.className = 'aux-ing-card';
        const estimatedBadge = item.is_estimated ? '<span class="est-tag">估</span>' : '';
        card.innerHTML = `
            <div class="aux-ing-icon">🥗</div>
            <div class="aux-ing-name">${item.name}</div>
            <div class="aux-ing-amount">${item.amount || ''} ${estimatedBadge}</div>
        `;
        auxIngList.appendChild(card);
    });

    // 3. Seasonings (系统给所有调料统一固定颜色，配比严格量化对齐)
    seasoningList.innerHTML = '';
    const seasoningItems = (recipe.ingredients && recipe.ingredients.seasonings) || [];
    const SYSTEM_SEASONING_COLOR = '#443228'; // 系统统一固定高品质纯色
    seasoningItems.forEach(item => {
        const row = document.createElement('div');
        row.className = 'seasoning-row';
        const ratioPct = Math.round((item.ratio || 0.45) * 100);

        row.innerHTML = `
            <div class="seasoning-title-col">
                <div class="seasoning-cn">${item.name}</div>
                <div class="seasoning-en">${item.english || 'Seasoning'}</div>
            </div>
            <div class="seasoning-bar-track">
                <div class="seasoning-bar-fill" style="width: ${Math.max(20, ratioPct)}%; background-color: ${SYSTEM_SEASONING_COLOR};">
                    <span class="seasoning-amount-badge">${item.amount}</span>
                </div>
            </div>
        `;
        seasoningList.appendChild(row);
    });

    // 4. Steps (纯粹一行一句，无制作图片时自适应为纯文字布局)
    stepsList.innerHTML = '';
    const steps = recipe.steps || [];
    stepsCountBadge.textContent = `(${steps.length} 步)`;

    steps.forEach((st, idx) => {
        const card = document.createElement('div');
        const imgUrl = st.image_url;

        if (imgUrl) {
            card.className = 'step-card';
            card.innerHTML = `
                <div class="step-thumb-wrap" onclick="openLightbox('${imgUrl}', '步骤 ${st.number || idx + 1}: ${st.title || ''}', '${st.text || ''}')">
                    <img src="${imgUrl}" alt="Step ${st.number}" onerror="this.src='${dishCoverImg.src}'" />
                    <div class="zoom-badge">🔍</div>
                </div>
                <div class="step-content">
                    <div class="step-meta-row">
                        <span class="step-num-text">${st.number || String(idx + 1).padStart(2, '0')}</span>
                        <span class="step-title-text">${st.title || ''}</span>
                    </div>
                    <div class="step-desc-text">${st.text || ''}</div>
                </div>
            `;
        } else {
            // 纯食物知识还原：无步骤图片模式
            card.className = 'step-card step-card-textonly';
            card.innerHTML = `
                <div class="step-content">
                    <div class="step-meta-row">
                        <span class="step-num-text">${st.number || String(idx + 1).padStart(2, '0')}</span>
                        <span class="step-title-text">${st.title || ''}</span>
                        ${st.duration_badge ? `<span class="step-badge-pill">${st.duration_badge}</span>` : ''}
                    </div>
                    <div class="step-desc-text">${st.text || ''}</div>
                </div>
            `;
        }
        stepsList.appendChild(card);
    });

    // 5. Chef Notes
    chefNotesList.innerHTML = '';
    const notes = recipe.chefs_notes || [];
    if (notes.length === 0) {
        document.getElementById('chefNotesSection').style.display = 'none';
    } else {
        document.getElementById('chefNotesSection').style.display = 'block';
        notes.forEach(note => {
            const li = document.createElement('li');
            li.textContent = note;
            chefNotesList.appendChild(li);
        });
    }
}

// Lightbox
function openLightbox(imgUrl, title, desc) {
    lightboxImg.src = imgUrl;
    lightboxTitle.textContent = title;
    lightboxDesc.textContent = desc;
    lightboxModal.classList.add('active');
}

lightboxClose.onclick = () => lightboxModal.classList.remove('active');
lightboxBackdrop.onclick = () => lightboxModal.classList.remove('active');

// Check-in button toggle
btnCheckIn.onclick = () => {
    btnCheckIn.classList.toggle('checked');
    if (btnCheckIn.classList.contains('checked')) {
        checkInText.textContent = '已打卡至今日菜谱日历 ✓';
        showToast('📅 已标记为今日烹饪！已记入日历');
    } else {
        checkInText.textContent = '今日做了这道菜 · 记入日历';
    }
};

// Export to Dish.swift format
btnExportSwift.onclick = () => {
    const jsonStr = jsonInput.value.trim();
    if (!jsonStr) return;
    try {
        const recipe = JSON.parse(jsonStr);
        const swiftCode = `// Swift Dish 数据结构
let parsedDish = Dish(
    id: "dish_${Date.now()}",
    name: "${recipe.name || '精选菜谱'}",
    englishName: "${recipe.englishName || 'Recipe'}",
    categoryId: "rice",
    imageName: "dish_cover",
    subtitle: "${recipe.subtitle || ''}",
    description: "${(recipe.description || '').replace(/"/g, '\\"')}",
    tag: "精选菜谱",
    rating: 5.0,
    cookingTime: "${recipe.metrics?.time || '20m'}",
    calories: "${recipe.metrics?.calories || '630'}大卡",
    ingredients: [${(recipe.ingredients?.main || []).map(i => `"${i.name}"`).concat((recipe.ingredients?.auxiliary || []).map(i => `"${i.name}"`)).join(', ')}],
    flavor: "风味地道"
)`;
        navigator.clipboard.writeText(swiftCode);
        showToast('📋 已复制 Swift Dish 代码！可直接放入 App');
    } catch (e) {
        showToast('导出出错: ' + e.message);
    }
};

