"use strict";

function adminPanelHtml() {
  return `<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>إدارة أكواد الهدايا — Yu-Gi-Oh! Power of Chaos</title>
  <style>
    :root {
      --bg: #0c0a14;
      --panel: #161224;
      --panel-2: #1e1831;
      --border: #3a2e5c;
      --gold: #eab949;
      --gold-dim: #b68827;
      --text: #f3ecdb;
      --muted: #b1a8c4;
      --green: #42d68a;
      --red: #f16969;
      --amber: #f5b951;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      background: radial-gradient(circle at top, #1b1433 0%, var(--bg) 62%);
      color: var(--text);
      font-family: system-ui, -apple-system, "Segoe UI", Tahoma, sans-serif;
      padding: 20px;
    }
    .wrap { max-width: 980px; margin: 0 auto; }
    header {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 20px;
      padding-bottom: 14px;
      border-bottom: 1px solid var(--border);
    }
    h1 { margin: 0; font-size: 24px; color: var(--gold); }
    .subtitle { margin: 4px 0 0; color: var(--muted); font-size: 14px; }
    .card {
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px;
      margin-bottom: 18px;
      box-shadow: 0 12px 30px rgba(0, 0, 0, 0.35);
    }
    .card h2 {
      margin: 0 0 14px;
      font-size: 18px;
      color: var(--gold);
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
      gap: 12px;
    }
    label {
      display: block;
      font-size: 13px;
      color: var(--muted);
      margin-bottom: 5px;
    }
    input, select, textarea {
      width: 100%;
      padding: 10px 12px;
      border-radius: 9px;
      border: 1px solid var(--border);
      background: var(--panel-2);
      color: var(--text);
      font-size: 14px;
      outline: none;
      font-family: inherit;
    }
    input:focus, textarea:focus, select:focus { border-color: var(--gold); }
    textarea { min-height: 112px; resize: vertical; line-height: 1.5; }
    .mode-tabs { display: flex; gap: 10px; margin-bottom: 14px; flex-wrap: wrap; }
    .mode-tab {
      flex: 1;
      min-width: 180px;
      padding: 10px 14px;
      border-radius: 10px;
      border: 1px solid var(--border);
      background: var(--panel-2);
      color: var(--muted);
      font-weight: 700;
      font-size: 14px;
      cursor: pointer;
    }
    .mode-tab.active {
      border-color: var(--gold);
      background: linear-gradient(180deg, rgba(234, 185, 73, 0.22), rgba(182, 136, 39, 0.12));
      color: var(--gold);
    }
    .deck-badge {
      font-size: 12px;
      font-weight: 700;
      padding: 3px 9px;
      border-radius: 7px;
      background: rgba(138, 86, 255, 0.22);
      color: #d5baff;
      border: 1px solid rgba(173, 134, 255, 0.45);
    }
    .unlock-badge {
      font-size: 12px;
      font-weight: 700;
      padding: 3px 9px;
      border-radius: 7px;
      background: rgba(66, 214, 138, 0.2);
      color: #7bf0b3;
      border: 1px solid rgba(66, 214, 138, 0.45);
    }
    .row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
    .btn {
      border: 1px solid var(--gold-dim);
      background: linear-gradient(180deg, #f3c85c, #c79325);
      color: #161020;
      font-weight: 700;
      border-radius: 9px;
      padding: 10px 16px;
      cursor: pointer;
      font-size: 14px;
    }
    .btn:disabled { opacity: 0.55; cursor: not-allowed; }
    .btn-ghost {
      background: var(--panel-2);
      color: var(--text);
      border: 1px solid var(--border);
    }
    .btn-danger {
      background: #3d1822;
      color: #ff9c9c;
      border: 1px solid #7c2c3f;
    }
    .btn-sm { padding: 6px 10px; font-size: 12px; }
    .chips { display: flex; flex-wrap: wrap; gap: 8px; margin: 12px 0 14px; }
    .chip {
      background: var(--panel-2);
      border: 1px solid var(--border);
      color: var(--text);
      border-radius: 8px;
      padding: 6px 10px;
      font-size: 12px;
      cursor: pointer;
    }
    .chip:hover { border-color: var(--gold); color: var(--gold); }
    .msg {
      margin-top: 10px;
      font-size: 14px;
      font-weight: 600;
      min-height: 20px;
    }
    .msg.ok { color: var(--green); }
    .msg.err { color: var(--red); }
    .list { display: flex; flex-direction: column; gap: 12px; }
    .gift-item {
      background: var(--panel-2);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 14px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .gift-top {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
    }
    .code-badge {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 18px;
      font-weight: 800;
      letter-spacing: 1px;
      color: var(--gold);
      background: #120e1e;
      border: 1px solid var(--gold-dim);
      padding: 4px 12px;
      border-radius: 8px;
    }
    .status-tag {
      font-size: 12px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 7px;
    }
    .st-active { background: rgba(66, 214, 138, 0.16); color: var(--green); }
    .st-full { background: rgba(241, 105, 105, 0.16); color: var(--red); }
    .st-off { background: rgba(245, 185, 81, 0.16); color: var(--amber); }
    .progress-wrap {
      width: 100%;
      height: 8px;
      background: #120e1e;
      border-radius: 99px;
      overflow: hidden;
    }
    .progress-bar {
      height: 100%;
      background: linear-gradient(90deg, var(--gold-dim), var(--gold));
      transition: width 0.25s ease;
    }
    .meta-row {
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      font-size: 13px;
      color: var(--muted);
    }
    .redemptions-box {
      background: #120e1e;
      border: 1px solid var(--border);
      border-radius: 9px;
      padding: 10px 12px;
      font-size: 13px;
    }
    .hidden { display: none !important; }
    .auth-box { max-width: 440px; margin: 40px auto; }
  </style>
</head>
<body>
  <div class="wrap">
    <header>
      <div>
        <h1>إدارة أكواد الهدايا المحدودة</h1>
        <p class="subtitle">أنشئ كود هدية لبطاقة واحدة أو لمجموعة / باقة بطاقات كاملة وحدد عدد الأشخاص المسموح لهم باستخدامه.</p>
      </div>
      <div class="row">
        <button id="refreshBtn" class="btn btn-ghost hidden" type="button">تحديث القائمة</button>
        <button id="logoutBtn" class="btn btn-danger hidden" type="button">تسجيل الخروج</button>
      </div>
    </header>

    <section id="authCard" class="card auth-box">
      <h2 id="authTitle">جاري التحقق من إعدادات الإدارة…</h2>
      <p id="authDesc" class="subtitle" style="margin-bottom:14px;"></p>
      <form id="authForm">
        <label for="passcodeInput">كلمة مرور الإدارة</label>
        <input id="passcodeInput" type="password" autocomplete="current-password" minlength="8" maxlength="128" required placeholder="أدخل كلمة مرور قوية (8 أحرف على الأقل)" />
        <div id="confirmWrap" class="hidden" style="margin-top:10px;">
          <label for="passcodeConfirm">تأكيد كلمة مرور الإدارة</label>
          <input id="passcodeConfirm" type="password" autocomplete="new-password" minlength="8" maxlength="128" placeholder="أعد إدخال كلمة المرور" />
        </div>
        <div style="margin-top:14px;">
          <button id="authSubmit" class="btn" type="submit" style="width:100%;">دخول</button>
        </div>
        <div id="authMsg" class="msg"></div>
      </form>
    </section>

    <main id="dashboard" class="hidden">
      <section class="card">
        <h2>إنشاء كود هدية جديد</h2>
        <div class="mode-tabs">
          <button id="modeCardBtn" class="mode-tab active" type="button">🃏 كود بطاقة واحدة</button>
          <button id="modeDeckBtn" class="mode-tab" type="button">📦 كود مجموعة / باقة بطاقات</button>
          <button id="modeUnlockAllBtn" class="mode-tab" type="button">🔓 كود فتح كل البطاقات</button>
        </div>

        <div id="quickLabel" class="subtitle">اختيار سريع لبطاقات مشهورة:</div>
        <div id="quickPicks" class="chips"></div>

        <form id="createForm">
          <div class="grid">
            <div>
              <label for="giftCodeInput">كود الهدية (الذي سيشاركه اللاعبون)</label>
              <div class="row">
                <input id="giftCodeInput" type="text" maxlength="32" required placeholder="مثال: FUSION10" style="flex:1;direction:ltr;text-align:left;" />
                <button id="genCodeBtn" class="btn btn-ghost btn-sm" type="button">عشوائي</button>
              </div>
            </div>
            <div id="singleCardWrap">
              <label for="cardCodeInput">كود البطاقة أو اسمها (عربي / إنجليزي)</label>
              <input id="cardCodeInput" type="text" maxlength="64" required placeholder="مثال: 24094653 أو الانصهار أو Polymerization" />
              <div id="cardSuggestions" class="chips" style="margin:6px 0 0;"></div>
            </div>
            <div>
              <label id="labelTitle" for="cardLabelInput">اسم البطاقة (اختياري للعرض)</label>
              <input id="cardLabelInput" type="text" maxlength="64" placeholder="مثال: بطاقة الانصهار" />
            </div>
            <div>
              <label for="maxUsesInput">الحد الأقصى للأشخاص</label>
              <input id="maxUsesInput" type="number" min="1" max="100000" value="10" required />
            </div>
            <div id="singleCopiesWrap">
              <label for="copiesInput">عدد النسخ لكل لاعب</label>
              <select id="copiesInput">
                <option value="1" selected>1 نسخة</option>
                <option value="2">2 نسخ</option>
                <option value="3">3 نسخ</option>
              </select>
            </div>
            <div>
              <label for="expiresHoursInput">صلاحية بالساعات (اختياري)</label>
              <input id="expiresHoursInput" type="number" min="1" max="8760" placeholder="اتركه فارغاً ليبقى مفتوحاً" />
            </div>
          </div>

          <div id="deckBuilderWrap" class="hidden" style="margin-top:14px;">
            <label for="deckSearchInput">ابحث عن بطاقة لإضافتها للمجموعة (عربي / إنجليزي / كود):</label>
            <div class="row" style="margin-bottom:6px;">
              <input id="deckSearchInput" type="text" maxlength="64" placeholder="اكتب اسم بطاقة أو كودها لإضافتها…" style="flex:1;" />
              <select id="deckAddCopies" style="width:110px;">
                <option value="1" selected>x1</option>
                <option value="2">x2</option>
                <option value="3">x3</option>
              </select>
            </div>
            <div id="deckSearchSuggestions" class="chips" style="margin:6px 0 10px;"></div>

            <div class="row" style="justify-content:space-between;margin-bottom:5px;">
              <label for="deckCardsInput" style="margin:0;">قائمة بطاقات المجموعة (بطاقة في كل سطر — يمكنك كتابة x2 أو x3):</label>
              <span id="deckCountBadge" class="deck-badge">0 بطاقة</span>
            </div>
            <textarea id="deckCardsInput" placeholder="مثال:&#10;89631139 x3&#10;24094653 x2&#10;46986414&#10;أو اسم البطاقة بالعربي أو الإنجليزي"></textarea>
          </div>

          <div id="unlockAllInfo" class="redemptions-box hidden" style="margin-top:14px;border-color:rgba(66,214,138,0.45);color:#cfece0;">
            🔓 عند استخدام هذا الكود: تُفتح جميع بطاقات اللعبة للاعب (3 نسخ لكل بطاقة)، ويتم نقل حسابه تلقائياً في الأونلاين من <strong>وضع المنافسة</strong> إلى <strong>وضع اختبار المجموعات</strong> حفاظاً على العدل بين اللاعبين.
          </div>

          <div style="margin-top:14px;">
            <button id="createBtn" class="btn" type="submit">إنشاء كود الهدية</button>
          </div>
          <div id="createMsg" class="msg"></div>
        </form>
      </section>

      <section class="card">
        <h2>أكواد الهدايا الحالية</h2>
        <div id="codesList" class="list"></div>
      </section>
    </main>
  </div>

  <script>
    (function () {
      let adminToken = "";
      let isSetupMode = false;
      let rewardMode = "card";

      const QUICK_CARDS = [
        { label: "بطاقة الانصهار (Polymerization)", code: "24094653", prefix: "FUSION" },
        { label: "التنين الأبيض أزرق العينين", code: "89631139", prefix: "BEWD" },
        { label: "الساحر الأسود", code: "46986414", prefix: "DMAG" },
        { label: "أوبليسك المعذب", code: "10000000", prefix: "OBELISK" },
        { label: "تنين رع المجنح", code: "10000010", prefix: "RA" },
        { label: "سلايفر تنين السماء", code: "10000020", prefix: "SLIFER" },
        { label: "إكسوديا المحرم", code: "33396948", prefix: "EXODIA" }
      ];

      const QUICK_DECKS = [
        {
          label: "مجموعة إكسوديا المحرم",
          prefix: "EXODIA-SET",
          lines: ["33396948", "08124921", "44519536", "07902349", "70903634", "55144522", "79571449"]
        },
        {
          label: "مجموعة التنين الأبيض",
          prefix: "BEWD-SET",
          lines: ["89631139 x3", "23995346", "24094653 x2", "17985575 x2", "43973174 x2"]
        },
        {
          label: "مجموعة الساحر الأسود",
          prefix: "DMAG-SET",
          lines: ["46986414 x3", "38033121 x2", "40737112", "24094653 x2", "71413901 x2"]
        },
        {
          label: "باقة الآلهة المصرية",
          prefix: "GODS-SET",
          lines: ["10000000", "10000010", "10000020"]
        },
        {
          label: "مجموعة عالم الكرتون",
          prefix: "TOON-SET",
          lines: ["15259703 x2", "53183600 x2", "91842653 x2", "65458948 x2", "16392422 x2"]
        }
      ];

      const authCard = document.getElementById("authCard");
      const authTitle = document.getElementById("authTitle");
      const authDesc = document.getElementById("authDesc");
      const authForm = document.getElementById("authForm");
      const passcodeInput = document.getElementById("passcodeInput");
      const confirmWrap = document.getElementById("confirmWrap");
      const passcodeConfirm = document.getElementById("passcodeConfirm");
      const authSubmit = document.getElementById("authSubmit");
      const authMsg = document.getElementById("authMsg");

      const dashboard = document.getElementById("dashboard");
      const refreshBtn = document.getElementById("refreshBtn");
      const logoutBtn = document.getElementById("logoutBtn");
      const modeCardBtn = document.getElementById("modeCardBtn");
      const modeDeckBtn = document.getElementById("modeDeckBtn");
      const modeUnlockAllBtn = document.getElementById("modeUnlockAllBtn");
      const quickLabel = document.getElementById("quickLabel");
      const quickPicks = document.getElementById("quickPicks");
      const createForm = document.getElementById("createForm");
      const giftCodeInput = document.getElementById("giftCodeInput");
      const genCodeBtn = document.getElementById("genCodeBtn");
      const singleCardWrap = document.getElementById("singleCardWrap");
      const singleCopiesWrap = document.getElementById("singleCopiesWrap");
      const cardCodeInput = document.getElementById("cardCodeInput");
      const cardSuggestions = document.getElementById("cardSuggestions");
      const labelTitle = document.getElementById("labelTitle");
      const cardLabelInput = document.getElementById("cardLabelInput");
      const maxUsesInput = document.getElementById("maxUsesInput");
      const copiesInput = document.getElementById("copiesInput");
      const expiresHoursInput = document.getElementById("expiresHoursInput");
      const deckBuilderWrap = document.getElementById("deckBuilderWrap");
      const unlockAllInfo = document.getElementById("unlockAllInfo");
      const deckSearchInput = document.getElementById("deckSearchInput");
      const deckAddCopies = document.getElementById("deckAddCopies");
      const deckSearchSuggestions = document.getElementById("deckSearchSuggestions");
      const deckCardsInput = document.getElementById("deckCardsInput");
      const deckCountBadge = document.getElementById("deckCountBadge");
      const createMsg = document.getElementById("createMsg");
      const codesList = document.getElementById("codesList");

      function setMsg(el, text, isOk) {
        el.textContent = text || "";
        el.className = "msg" + (text ? (isOk ? " ok" : " err") : "");
      }

      function randomSuffix(len) {
        const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        let out = "";
        for (let i = 0; i < len; i += 1) {
          out += chars[Math.floor(Math.random() * chars.length)];
        }
        return out;
      }

      function parseDeckLines(text) {
        const out = [];
        const tokens = String(text || "").split(/[\\n,;]+/);
        for (const raw of tokens) {
          let line = raw.trim();
          if (!line) continue;
          let copies = 1;
          const m = line.match(/^(.*?)(?:\\s*[xX×*]\\s*([1-3]))$/);
          if (m) {
            line = m[1].trim();
            copies = Number.parseInt(m[2], 10);
          }
          if (!line) continue;
          out.push({ cardCode: line, copies: Math.max(1, Math.min(3, copies)), zone: "main" });
        }
        return out;
      }

      function updateDeckCountBadge() {
        const parsed = parseDeckLines(deckCardsInput.value);
        const total = parsed.reduce((acc, item) => acc + item.copies, 0);
        deckCountBadge.textContent = total + " بطاقة (" + parsed.length + " نوع)";
      }

      function setRewardMode(mode) {
        rewardMode = mode === "deck" ? "deck" : (mode === "unlock_all" ? "unlock_all" : "card");
        modeCardBtn.classList.toggle("active", rewardMode === "card");
        modeDeckBtn.classList.toggle("active", rewardMode === "deck");
        modeUnlockAllBtn.classList.toggle("active", rewardMode === "unlock_all");
        singleCardWrap.classList.toggle("hidden", rewardMode !== "card");
        singleCopiesWrap.classList.toggle("hidden", rewardMode !== "card");
        deckBuilderWrap.classList.toggle("hidden", rewardMode !== "deck");
        unlockAllInfo.classList.toggle("hidden", rewardMode !== "unlock_all");
        quickLabel.classList.toggle("hidden", rewardMode === "unlock_all");
        quickPicks.classList.toggle("hidden", rewardMode === "unlock_all");
        cardCodeInput.required = rewardMode === "card";
        if (rewardMode === "unlock_all") {
          labelTitle.textContent = "وصف الكود (اختياري للعرض)";
          cardLabelInput.placeholder = "مثال: فتح جميع بطاقات اللعبة";
          if (!cardLabelInput.value.trim()) cardLabelInput.value = "فتح كل البطاقات";
        } else if (rewardMode === "deck") {
          quickLabel.textContent = "اختيار سريع لمجموعات / باقات جاهزة:";
          labelTitle.textContent = "اسم المجموعة (يظهر للاعبين)";
          cardLabelInput.placeholder = "مثال: مجموعة التنين الأبيض";
        } else {
          quickLabel.textContent = "اختيار سريع لبطاقات مشهورة:";
          labelTitle.textContent = "اسم البطاقة (اختياري للعرض)";
          cardLabelInput.placeholder = "مثال: بطاقة الانصهار";
        }
        renderQuickPicks();
        updateDeckCountBadge();
      }

      async function api(method, url, body) {
        const headers = { Accept: "application/json" };
        if (body !== undefined) headers["Content-Type"] = "application/json";
        if (adminToken) headers["Authorization"] = "Bearer " + adminToken;
        const res = await fetch(url, {
          method,
          headers,
          body: body !== undefined ? JSON.stringify(body) : undefined
        });
        const data = await res.json().catch(() => ({ ok: false, error: "invalid_response" }));
        if (res.status === 401 && adminToken) {
          adminToken = "";
          showAuth();
          setMsg(authMsg, "انتهت جلسة الإدارة، يرجى تسجيل الدخول مجدداً.", false);
        }
        return { status: res.status, data };
      }

      function renderQuickPicks() {
        quickPicks.textContent = "";
        if (rewardMode === "deck") {
          QUICK_DECKS.forEach((dk) => {
            const b = document.createElement("button");
            b.type = "button";
            b.className = "chip";
            b.textContent = "📦 " + dk.label;
            b.addEventListener("click", () => {
              cardLabelInput.value = dk.label;
              deckCardsInput.value = dk.lines.join("\\n");
              if (!giftCodeInput.value.trim()) {
                giftCodeInput.value = dk.prefix + "-" + randomSuffix(4);
              }
              updateDeckCountBadge();
            });
            quickPicks.appendChild(b);
          });
          return;
        }
        QUICK_CARDS.forEach((item) => {
          const b = document.createElement("button");
          b.type = "button";
          b.className = "chip";
          b.textContent = item.label + " (" + item.code + ")";
          b.addEventListener("click", () => {
            cardCodeInput.value = item.code;
            cardLabelInput.value = item.label;
            if (!giftCodeInput.value.trim()) {
              giftCodeInput.value = item.prefix + "-" + randomSuffix(4);
            }
          });
          quickPicks.appendChild(b);
        });
      }

      function showDashboard() {
        authCard.classList.add("hidden");
        dashboard.classList.remove("hidden");
        refreshBtn.classList.remove("hidden");
        logoutBtn.classList.remove("hidden");
        loadCodes();
      }

      function showAuth() {
        dashboard.classList.add("hidden");
        refreshBtn.classList.add("hidden");
        logoutBtn.classList.add("hidden");
        authCard.classList.remove("hidden");
      }

      async function checkStatus() {
        const { data } = await api("GET", "/api/admin/status");
        if (!data.ok) {
          authTitle.textContent = "تعذر الاتصال بالسيرفر";
          return;
        }
        isSetupMode = !data.configured;
        if (isSetupMode) {
          authTitle.textContent = "إعداد كلمة مرور الإدارة لأول مرة";
          authDesc.textContent = "قم باختيار كلمة مرور قوية لحماية لوحة إنشاء أكواد الهدايا (سيتم حفظها مشفرة في قاعدة البيانات).";
          confirmWrap.classList.remove("hidden");
          passcodeConfirm.required = true;
          authSubmit.textContent = "حفظ كلمة المرور والدخول";
        } else {
          authTitle.textContent = "تسجيل دخول الإدارة";
          authDesc.textContent = "أدخل كلمة مرور الإدارة للتحكم في أكواد الهدايا المحدودة.";
          confirmWrap.classList.add("hidden");
          passcodeConfirm.required = false;
          authSubmit.textContent = "دخول";
        }
      }

      function statusInfo(gc) {
        if (!gc.active) return { text: "موقوف يدوياً", cls: "st-off" };
        if (gc.expired) return { text: "منتهي الصلاحية", cls: "st-off" };
        if (gc.exhausted) return { text: "مكتمل — متوقف تلقائياً", cls: "st-full" };
        return { text: "نشط", cls: "st-active" };
      }

      function renderCodes(list) {
        codesList.textContent = "";
        if (!list.length) {
          const empty = document.createElement("p");
          empty.className = "subtitle";
          empty.textContent = "لا توجد أكواد هدايا بعد. أنشئ أول كود هدية من النموذج أعلاه!";
          codesList.appendChild(empty);
          return;
        }

        list.forEach((gc) => {
          const item = document.createElement("div");
          item.className = "gift-item";

          const top = document.createElement("div");
          top.className = "gift-top";

          const left = document.createElement("div");
          left.className = "row";

          const badge = document.createElement("span");
          badge.className = "code-badge";
          badge.textContent = gc.code;

          const copyBtn = document.createElement("button");
          copyBtn.type = "button";
          copyBtn.className = "btn btn-ghost btn-sm";
          copyBtn.textContent = "نسخ الكود";
          copyBtn.addEventListener("click", async () => {
            try {
              await navigator.clipboard.writeText(gc.code);
              copyBtn.textContent = "تم النسخ ✓";
              setTimeout(() => { copyBtn.textContent = "نسخ الكود"; }, 1400);
            } catch {
              copyBtn.textContent = gc.code;
            }
          });

          left.appendChild(badge);
          if (gc.rewardType === "unlock_all") {
            const unlockTag = document.createElement("span");
            unlockTag.className = "unlock-badge";
            unlockTag.textContent = "🔓 فتح كل البطاقات";
            left.appendChild(unlockTag);
          } else if (gc.rewardType === "deck" && Array.isArray(gc.cards)) {
            const totalCards = gc.cards.reduce((s, c) => s + Number(c.copies || 1), 0);
            const deckTag = document.createElement("span");
            deckTag.className = "deck-badge";
            deckTag.textContent = "📦 مجموعة (" + totalCards + " بطاقة)";
            left.appendChild(deckTag);
          }
          left.appendChild(copyBtn);

          const st = statusInfo(gc);
          const tag = document.createElement("span");
          tag.className = "status-tag " + st.cls;
          tag.textContent = st.text;

          top.appendChild(left);
          top.appendChild(tag);
          item.appendChild(top);

          const meta = document.createElement("div");
          meta.className = "meta-row";

          const mCard = document.createElement("span");
          if (gc.rewardType === "unlock_all") {
            mCard.textContent = "المكافأة: " + (gc.cardLabel || "فتح كل البطاقات") + " (ينتقل اللاعب لوضع اختبار المجموعات)";
          } else if (gc.rewardType === "deck" && Array.isArray(gc.cards)) {
            const totalCards = gc.cards.reduce((s, c) => s + Number(c.copies || 1), 0);
            mCard.textContent = "المجموعة: " + (gc.cardLabel || "مجموعة هدية") + " (" + totalCards + " بطاقة)";
          } else {
            mCard.textContent = "البطاقة: " + (gc.cardLabel ? gc.cardLabel + " (" + gc.cardCode + ")" : gc.cardCode);
          }
          const mUse = document.createElement("span");
          mUse.textContent = "الاستخدام: " + gc.usedCount + " / " + gc.maxUses + " (المتبقي: " + gc.remaining + ")";
          meta.appendChild(mCard);
          meta.appendChild(mUse);
          if (gc.rewardType === "card") {
            const mCopies = document.createElement("span");
            mCopies.textContent = "النسخ: " + gc.copies;
            meta.appendChild(mCopies);
          }
          if (gc.expiresAt) {
            const mExp = document.createElement("span");
            mExp.textContent = "ينتهي في: " + new Date(gc.expiresAt).toLocaleString("ar-EG");
            meta.appendChild(mExp);
          }
          item.appendChild(meta);

          const pWrap = document.createElement("div");
          pWrap.className = "progress-wrap";
          const pBar = document.createElement("div");
          pBar.className = "progress-bar";
          const pct = Math.min(100, Math.round((gc.usedCount / Math.max(1, gc.maxUses)) * 100));
          pBar.style.width = pct + "%";
          pWrap.appendChild(pBar);
          item.appendChild(pWrap);

          const actions = document.createElement("div");
          actions.className = "row";

          const toggleBtn = document.createElement("button");
          toggleBtn.type = "button";
          toggleBtn.className = "btn btn-ghost btn-sm";
          toggleBtn.textContent = gc.active ? "إيقاف مؤقت" : "إعادة التفعيل";
          toggleBtn.addEventListener("click", async () => {
            await api("PATCH", "/api/admin/gift-codes/" + encodeURIComponent(gc.code), { active: !gc.active });
            loadCodes();
          });

          const plusBtn = document.createElement("button");
          plusBtn.type = "button";
          plusBtn.className = "btn btn-ghost btn-sm";
          plusBtn.textContent = "+5 أشخاص للحد";
          plusBtn.addEventListener("click", async () => {
            await api("PATCH", "/api/admin/gift-codes/" + encodeURIComponent(gc.code), { maxUses: gc.maxUses + 5 });
            loadCodes();
          });

          const redemptionsBox = document.createElement("div");
          redemptionsBox.className = "redemptions-box hidden";

          const viewBtn = document.createElement("button");
          viewBtn.type = "button";
          viewBtn.className = "btn btn-ghost btn-sm";
          viewBtn.textContent = "عرض المستفيدين (" + gc.usedCount + ")";
          viewBtn.addEventListener("click", async () => {
            if (!redemptionsBox.classList.contains("hidden")) {
              redemptionsBox.classList.add("hidden");
              return;
            }
            const { data } = await api("GET", "/api/admin/gift-codes/" + encodeURIComponent(gc.code) + "/redemptions");
            redemptionsBox.textContent = "";
            if (!data.ok || !data.redemptions || !data.redemptions.length) {
              redemptionsBox.textContent = "لم يستخدم أحد هذا الكود بعد.";
            } else {
              data.redemptions.forEach((r, idx) => {
                const line = document.createElement("div");
                line.textContent = (idx + 1) + ". " + r.displayName + " (#" + r.playerId + ") — " + new Date(r.redeemedAt).toLocaleString("ar-EG");
                redemptionsBox.appendChild(line);
              });
            }
            redemptionsBox.classList.remove("hidden");
          });

          let cardsBox = null;
          if (gc.rewardType === "deck" && Array.isArray(gc.cards) && gc.cards.length > 0) {
            cardsBox = document.createElement("div");
            cardsBox.className = "redemptions-box hidden";
            const cardsBtn = document.createElement("button");
            cardsBtn.type = "button";
            cardsBtn.className = "btn btn-ghost btn-sm";
            cardsBtn.textContent = "عرض البطاقات (" + gc.cards.length + ")";
            cardsBtn.addEventListener("click", () => {
              if (!cardsBox.classList.contains("hidden")) {
                cardsBox.classList.add("hidden");
                return;
              }
              cardsBox.textContent = "";
              gc.cards.forEach((c, idx) => {
                const line = document.createElement("div");
                line.textContent = (idx + 1) + ". " + (c.cardLabel || c.cardCode) + " (" + c.cardCode + ") × " + (c.copies || 1);
                cardsBox.appendChild(line);
              });
              cardsBox.classList.remove("hidden");
            });
            actions.appendChild(cardsBtn);
          }

          const delBtn = document.createElement("button");
          delBtn.type = "button";
          delBtn.className = "btn btn-danger btn-sm";
          delBtn.textContent = "حذف";
          delBtn.addEventListener("click", async () => {
            if (!window.confirm("حذف كود الهدية " + gc.code + " نهائياً؟")) return;
            await api("DELETE", "/api/admin/gift-codes/" + encodeURIComponent(gc.code));
            loadCodes();
          });

          actions.appendChild(toggleBtn);
          actions.appendChild(plusBtn);
          actions.appendChild(viewBtn);
          actions.appendChild(delBtn);
          item.appendChild(actions);
          if (cardsBox) item.appendChild(cardsBox);
          item.appendChild(redemptionsBox);

          codesList.appendChild(item);
        });
      }

      async function loadCodes() {
        const { data } = await api("GET", "/api/admin/gift-codes");
        if (data.ok && Array.isArray(data.giftCodes)) {
          renderCodes(data.giftCodes);
        }
      }

      authForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        setMsg(authMsg, "", true);
        const pass = passcodeInput.value;
        if (isSetupMode) {
          if (pass !== passcodeConfirm.value) {
            setMsg(authMsg, "كلمتا المرور غير متطابقتين.", false);
            return;
          }
          const { data } = await api("POST", "/api/admin/setup", { passcode: pass });
          if (!data.ok) {
            setMsg(authMsg, "تعذر الحفظ: " + (data.error || "خطأ غير متوقع"), false);
            return;
          }
          adminToken = data.token;
          passcodeInput.value = "";
          passcodeConfirm.value = "";
          showDashboard();
        } else {
          const { data } = await api("POST", "/api/admin/login", { passcode: pass });
          if (!data.ok) {
            setMsg(authMsg, "كلمة المرور غير صحيحة أو تم تجاوز عدد المحاولات.", false);
            return;
          }
          adminToken = data.token;
          passcodeInput.value = "";
          showDashboard();
        }
      });

      modeCardBtn.addEventListener("click", () => setRewardMode("card"));
      modeDeckBtn.addEventListener("click", () => setRewardMode("deck"));
      modeUnlockAllBtn.addEventListener("click", () => setRewardMode("unlock_all"));
      deckCardsInput.addEventListener("input", updateDeckCountBadge);

      let searchTimer = null;
      cardCodeInput.addEventListener("input", () => {
        clearTimeout(searchTimer);
        const q = cardCodeInput.value.trim();
        if (q.length < 2) {
          cardSuggestions.textContent = "";
          return;
        }
        searchTimer = setTimeout(async () => {
          const { data } = await api("GET", "/api/admin/cards/search?q=" + encodeURIComponent(q));
          cardSuggestions.textContent = "";
          if (!data.ok || !Array.isArray(data.cards)) return;
          data.cards.slice(0, 6).forEach((c) => {
            const b = document.createElement("button");
            b.type = "button";
            b.className = "chip";
            b.textContent = (c.ar || c.en) + " (" + c.code + ")";
            b.addEventListener("click", () => {
              cardCodeInput.value = c.code;
              cardLabelInput.value = c.ar || c.en;
              cardSuggestions.textContent = "";
            });
            cardSuggestions.appendChild(b);
          });
        }, 220);
      });

      let deckSearchTimer = null;
      deckSearchInput.addEventListener("input", () => {
        clearTimeout(deckSearchTimer);
        const q = deckSearchInput.value.trim();
        if (q.length < 2) {
          deckSearchSuggestions.textContent = "";
          return;
        }
        deckSearchTimer = setTimeout(async () => {
          const { data } = await api("GET", "/api/admin/cards/search?q=" + encodeURIComponent(q));
          deckSearchSuggestions.textContent = "";
          if (!data.ok || !Array.isArray(data.cards)) return;
          data.cards.slice(0, 6).forEach((c) => {
            const b = document.createElement("button");
            b.type = "button";
            b.className = "chip";
            b.textContent = "+ " + (c.ar || c.en) + " (" + c.code + ")";
            b.addEventListener("click", () => {
              const cp = Number.parseInt(deckAddCopies.value, 10) || 1;
              const entry = cp > 1 ? (c.code + " x" + cp) : c.code;
              const cur = deckCardsInput.value.trim();
              deckCardsInput.value = cur ? (cur + "\\n" + entry) : entry;
              deckSearchInput.value = "";
              deckSearchSuggestions.textContent = "";
              updateDeckCountBadge();
            });
            deckSearchSuggestions.appendChild(b);
          });
        }, 220);
      });

      genCodeBtn.addEventListener("click", () => {
        const prefix = rewardMode === "unlock_all" ? "ALLCARDS-" : (rewardMode === "deck" ? "DECK-" : "GIFT-");
        giftCodeInput.value = prefix + randomSuffix(6);
      });

      createForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        setMsg(createMsg, "", true);
        const payload = {
          code: giftCodeInput.value.trim(),
          rewardType: rewardMode,
          cardLabel: cardLabelInput.value.trim(),
          maxUses: Number.parseInt(maxUsesInput.value, 10)
        };
        if (rewardMode === "unlock_all") {
          payload.cardLabel = payload.cardLabel || "فتح كل البطاقات";
        } else if (rewardMode === "deck") {
          const parsedCards = parseDeckLines(deckCardsInput.value);
          if (!parsedCards.length) {
            setMsg(createMsg, "أضف بطاقة واحدة على الأقل داخل المجموعة أولاً.", false);
            return;
          }
          payload.cards = parsedCards;
        } else {
          payload.cardCode = cardCodeInput.value.trim();
          payload.copies = Number.parseInt(copiesInput.value, 10);
        }
        const expHours = Number.parseFloat(expiresHoursInput.value);
        if (Number.isFinite(expHours) && expHours > 0) {
          payload.expiresAt = Date.now() + Math.round(expHours * 3600 * 1000);
        }
        const { data } = await api("POST", "/api/admin/gift-codes", payload);
        if (!data.ok) {
          const map = {
            code_exists: "هذا الكود موجود بالفعل، اختر كوداً آخر.",
            invalid_code: "الكود يجب أن يكون 3 إلى 32 حرفاً أو رقماً بالإنجليزية.",
            invalid_card_code: "أحد أكواد أو أسماء البطاقات غير صالح، يرجى مراجعته.",
            invalid_deck_cards: "يرجى إضافة بين 1 و 120 بطاقة للمجموعة.",
            deck_too_large: "إجمالي عدد البطاقات في المجموعة يتجاوز الحد المسموح (150).",
            invalid_max_uses: "الحد الأقصى للأشخاص يجب أن يكون بين 1 و 100000."
          };
          setMsg(createMsg, map[data.error] || ("خطأ: " + data.error), false);
          return;
        }
        const kindTxt = data.giftCode.rewardType === "unlock_all"
          ? "كود فتح كل البطاقات"
          : (data.giftCode.rewardType === "deck" ? "كود المجموعة" : "كود الهدية");
        setMsg(createMsg, "تم إنشاء " + kindTxt + " " + data.giftCode.code + " بنجاح! (الحد: " + data.giftCode.maxUses + " أشخاص)", true);
        giftCodeInput.value = "";
        expiresHoursInput.value = "";
        loadCodes();
      });

      refreshBtn.addEventListener("click", loadCodes);
      logoutBtn.addEventListener("click", () => {
        adminToken = "";
        showAuth();
      });

      setRewardMode("card");
      checkStatus();
    })();
  </script>
</body>
</html>`;
}

module.exports = { adminPanelHtml };
