# مرجع المستودعات وقواعد البيانات الخارجية (External Repositories & Card Databases Reference)

هذا الملف المرجعي محفوظ بشكل دائم داخل المشروع لتوثيق جميع مستودعات GitHub وقواعد البيانات الخارجية المعتمدة لتطوير وتوسيع بطاقات وتأثيرات لعبة **Yu-Gi-Oh! Power of Chaos Remake**، وكيفية ربطها بملفات المحرك داخل المشروع.

---

## 1. مستودعات الأكواد البرمجية لتأثيرات البطاقات (Card Effect Logic & Scripts)

### أ. مستودع سكريبتات التأثيرات (Project Ignis / EDOPro - CardScripts)
- **الرابط الرسمي:** `https://github.com/ProjectIgnis/CardScripts`
- **المحتوى والغرض:**
  - يضم ملفات `Lua` (`c<passcode>.lua`) لأكثر من 13,000 بطاقة يوغي يو مقترنة بالرقم الرسمي للبطاقة (8-digit Passcode / Konami ID أو Passcode).
  - يحدد بدقة شروط تفعيل التأثير (`SetCondition`, `SetCost`, `SetTarget`) ومنطق التنفيذ (`SetOperation`) ونوع التأثير (`EFFECT_TYPE_ACTIVATE`, `EFFECT_TYPE_IGNITION`, `EFFECT_TYPE_QUICK_O`, `EFFECT_TYPE_TRIGGER_O`, `EFFECT_TYPE_SINGLE`, `EFFECT_TYPE_FIELD`, `EFFECT_TYPE_CONTINUOUS`).
- **مسارات الربط داخل مشروعنا:**
  - الموزع الرئيسي للتأثيرات المخصصة: `game/duel/core/custom_card_effects.gd`
  - العمليات الموحدة وحركات البطاقات (Core + Joey): `game/duel/core/custom_duel_ops.gd`
  - تأثيرات الفخاخ المخصصة (97 بطاقة): `game/duel/core/custom_effects_traps.gd`
  - تأثيرات السحر المخصصة (146 بطاقة): `game/duel/core/custom_effects_spells.gd`
  - تأثيرات الوحوش المخصصة (الجزء 1 - IDs `2500..2799`، 184 بطاقة): `game/duel/core/custom_effects_monsters_1.gd`
  - تأثيرات الوحوش المخصصة (الجزء 2 - IDs `2800..3129`، 162 بطاقة): `game/duel/core/custom_effects_monsters_2.gd`
  - قواعد الدمج والطقوس الإضافية: `game/duel/core/extra_card_effects.gd`

### ب. قاعدة بيانات النصوص والخصائص المرافقة (Project Ignis - BabelCDB)
- **الرابط الرسمي:** `https://github.com/ProjectIgnis/BabelCDB`
- **المحتوى والغرض:**
  - تضم قواعد بيانات `SQLite` (`.cdb`) تحتوي على جدولَي `datas` (الإحصائيات، النوع، العنصر، المستوى، الهجوم، الدفاع، الفئة) و`texts` (أسماء البطاقات ونصوص تأثيراتها ونصوص الرسائل المرتبطة بأرقام البطاقات في `CardScripts`).
- **مسار الربط داخل مشروعنا:**
  - قاعدة بيانات البطاقات الإضافية المدمجة: `game/assets/cards/extra_cards.json`
  - مدير تحميل البطاقات في المحرك: `game/autoload/card_db.gd` و `game/core/card_catalog.gd`

---

## 2. قواعد بيانات JSON وواجهات البرمجة الجاهزة (Card Metadata, Texts & Artworks)

### أ. مستودع YGOJSON (قاعدة بيانات JSON شاملة ومجمعة)
- **الرابط الرسمي:** `https://github.com/iconmaster5326/YGOJSON`
- **الفرع المجمع:** فرع `aggregate` (يجمع كل البطاقات في ملف JSON واحد منظم).
- **المحتوى والغرض:**
  - يوفر بيانات البطاقات القياسية: الأسماء بلغات متعددة، نصوص التأثيرات، الأنواع الفرعية، المستوى، نقاط الهجوم والدفاع، وأكواد المجموعات.
- **مسار الربط داخل مشروعنا:**
  - تم استيراد وتكويد حزمة الـ 630 بطاقة الإضافية (`internal_id` من `2500` إلى `3129`) داخل:
    - `game/assets/cards/extra_cards.json`
    - اختبار التحقق الآلي الشامل: `tools/tests/test_ygojson_and_extra_effects.py`

### ب. واجهة بيانات YGOPRODeck المباشرة (JSON API)
- **الرابط الرسمي:** `https://db.ygoprodeck.com/api/v7/cardinfo.php`
- **المحتوى والغرض:**
  - يعيد ملف JSON واحد يضم كل بطاقات يوغي يو (أكثر من 13,000 بطاقة) بكامل تفاصيلها ونصوص تأثيراتها وأرقامها الرسمية (`id`) وروابط صورها.
- **قواعد الاستخدام المهمة داخل المشروع:**
  1. **عدم السحب المباشر للصور أثناء اللعب (No Runtime Hotlinking):** يجب دائماً تحميل الصور محلياً وحفظها داخل أصول اللعبة (`game/assets/cards/` أو حزمة المحتوى المحلي) لتجنب حظر الـ IP وضمان عمل اللعبة بدون إنترنت (Offline).
  2. **الاستيراد عبر ملفات مرفقة أو مجمعة:** عند إضافة دفعات جديدة من البطاقات، يتم تمرير ملف JSON المجمع أو مجلد سكريبتات Lua ليتم تحويلها إلى دوال GDScript داخل `custom_effects_*.gd` وتسجيل بياناتها في `extra_cards.json`.

---

## 3. جدول المطابقة القياسي بين مستودعات (EDOPro / YGOJSON) ومحرك اللعبة (PoC Engine IDs)

عند تحويل أي بطاقة أو سكريبت من `ProjectIgnis/CardScripts` أو `YGOJSON` أو `BabelCDB` إلى محرك اللعبة، يجب الالتزام بأرقام الفصائل والعناصر الخاصة بمحرك Power of Chaos:

### أ. أرقام العناصر (Attributes - `CustomDuelOps.monster_attr`)
| العنصر (Attribute) | الرقم في المحرك (PoC ID) |
|---|---|
| LIGHT (ضوء) | `1` |
| DARK (ظلام) | `2` |
| WATER (ماء) | `3` |
| FIRE (نار) | `4` |
| EARTH (أرض) | `5` |
| WIND (رياح) | `6` |
| DIVINE (إلهي) | `7` |

### ب. أرقام فصائل الوحوش (Monster Races - `CustomDuelOps.monster_race`)
| الفصيلة (Race / Type) | الرقم في المحرك (PoC ID) |
|---|---|
| Dragon (تنين) | `1` |
| Zombie (زومبي) | `2` |
| Fiend (شيطان) | `3` |
| Pyro (ناري) | `4` |
| Sea Serpent (ثعبان بحر) | `5` |
| Rock (صخري) | `6` |
| Machine (آلة) | `7` |
| Fish (سمك) | `8` |
| Dinosaur (ديناصور) | `9` |
| Insect (حشرة) | `10` |
| Beast (وحش) | `11` |
| Beast-Warrior (محارب وحش) | `12` |
| Plant (نبات) | `13` |
| Aqua (مائي) | `14` |
| Warrior (محارب) | `15` |
| Winged Beast (وحش مجنح) | `16` |
| Fairy (جني / ملاك) | `17` |
| Spellcaster (ساحر) | `18` |
| Thunder (رعد) | `19` |
| Reptile (زواحف) | `20` |
| Divine-Beast (وحش إلهي) | `24` (`0x18`) |

### ج. حماية البطاقات الأصلية
- البطاقات الأصلية في اللعبة تحمل المعرفات `0..2499` وتعمل عبر المحرك الأصلي (`DuelPort*` و `JoeyPort*`).
- البطاقات الإضافية المخصصة تبدأ من `2500` فما فوق (`CustomCardEffects.handles(cid)` يتحقق دائماً من `cid >= 2500`) لضمان عدم المساس بأي تأثير أو أنيميشن للبطاقات الأصلية.
