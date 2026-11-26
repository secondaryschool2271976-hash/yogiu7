# دليل استكمال المشروع للشات الجديد (AI Assistant Handoff & Master README)

> **تعليمات إلزامية لأي جلسة ذكاء اصطناعي جديدة (MANDATORY FIRST READ FOR NEW CHAT SESSIONS):**
> عند بدء أي محادثة جديدة على هذا المشروع، اقرأ هذا الملف بالكامل أولاً واتبع الخطوات المرتبة أدناه قبل إجراء أي تعديل.

---

## 1. خطوات العمل الإلزامية بالترتيب عند بدء أي مهمة جديدة

1. **الخطوة الأولى — قراءة ملفات المراجع الموثقة:**
   - اقرأ هذا الملف (`/README.md`) والملف التفصيلي للمستودعات:
     - `/Yu-Gi-Oh-Power-of-Chaos-Remake-main/docs/EXTERNAL_REPOSITORIES_REFERENCE.md`
     - `/Yu-Gi-Oh-Power-of-Chaos-Remake-main/game/assets/cards/repositories_reference.json`
2. **الخطوة الثانية — تحديد المستودع المرجعي الأكثر إفادة:**
   - **المستودع رقم 1 الأكثر إفادة والأولوية القصوى:** هو **`ProjectIgnis/CardScripts`** (`https://github.com/ProjectIgnis/CardScripts`).
   - **لماذا هو الأكثر إفادة؟** لأن قاعدة بيانات مشروعنا (`/Yu-Gi-Oh-Power-of-Chaos-Remake-main/game/assets/cards/extra_cards.json`) تحتوي بالفعل على جميع بيانات الـ 630 بطاقة الإضافية (`2500..3129`) من `YGOJSON` (بما فيها الأسماء والوصف بـ 7 لغات منها العربية، الإحصائيات، الصور المحلية `.webp`، وحقل `"password"` المكون من 8 أرقام الرسمية لكل بطاقة). كل `"password"` يطابق مباشرة ملف `c<password>.lua` في مستودع `ProjectIgnis/CardScripts`، والذي يشرح برمجياً شروط التفعيل (`SetCondition`)، التكلفة (`SetCost`)، الأهداف (`SetTarget`)، والتنفيذ (`SetOperation`).
3. **الخطوة الثالثة — فحص الملفات المتأثرة في المحركين (Core + Joey):**
   - اللعبة تعمل بمحركين داخل Godot 4.7:
     - **محرك Core (يوجي وكايبا، وبديل جوي الاحتياطي):** `/Yu-Gi-Oh-Power-of-Chaos-Remake-main/game/duel/core/` (`duel.gd`, `duel_port_a.gd`..`duel_port_o.gd`).
     - **محرك Joey الأصلي:** `/Yu-Gi-Oh-Power-of-Chaos-Remake-main/game/duel/joey/` (`joey_engine.gd`, `joey_port_a.gd`..`joey_port_zs.gd`).
     - **منظومة التأثيرات المخصصة الموحدة للمحركين:**
       - الموزع الرئيسي: `game/duel/core/custom_card_effects.gd`
       - العمليات والأنيميشن الموحدة: `game/duel/core/custom_duel_ops.gd`
       - الفخاخ المخصصة (97 بطاقة): `game/duel/core/custom_effects_traps.gd`
       - السحر المخصص (146 بطاقة): `game/duel/core/custom_effects_spells.gd`
       - الوحوش المخصصة 1 (`2500..2799`، 184 بطاقة): `game/duel/core/custom_effects_monsters_1.gd`
       - الوحوش المخصصة 2 (`2800..3129`، 162 بطاقة): `game/duel/core/custom_effects_monsters_2.gd`
       - الدمج والطقوس الإضافية: `game/duel/core/extra_card_effects.gd`
4. **الخطوة الرابعة — الالتزام بقواعد Godot 4.7 الصارمة:**
   - **منع استخدام `:=` مع قيم `Variant` غير محددة النوع** (مثل فهرسة القواميس `dict["key"]` أو `dict.get(...)` أو خصائص `duel.m` غير المحددة النوع)؛ استخدم دائماً أنواعاً صريحة مثل `var x: int = int(...)` أو `var x = ...` حتى لا يفشل بناء الأندرويد (`Godot 4.7.2 --headless --editor --import`).
   - **التحقق من وجود الدوال في سلسلة الوراثة:** قبل استدعاء أي دالة `f5xxxxx` داخل `joey_port_*.gd` أو `duel_port_*.gd`، تأكد من وجودها في `joey_decl.gd` أو `duel_decl.gd`، أو استخدم دوال `CustomDuelOps` الموحدة (`CustomDuelOps.pile_count`, `CustomDuelOps.pile_idx`, `CustomDuelOps.zone_idx`, إلخ).
   - **حماية البطاقات الأصلية (`0..2499`):** لا تغير تأثيرات البطاقات الأصلية؛ `CustomCardEffects.handles(cid)` يجب أن يظل مقيداً بـ `cid >= 2500`.
5. **الخطوة الخامسة — تشغيل اختبارات التحقق قبل إنهاء أي تعديل:**
   - شغّل دائماً حزمة الاختبارات الآلية:
     ```bash
     python3 -m unittest Yu-Gi-Oh-Power-of-Chaos-Remake-main/tools/tests/test_ygojson_and_extra_effects.py -v
     ```

---

## 2. قائمة المستودعات المرجعية المعتمدة في المشروع

| # | اسم المستودع / المصدر | الرابط | الأهمية والغرض في مشروعنا |
|---|---|---|---|
| **1** | **Project Ignis / EDOPro (`CardScripts`)** *(الأكثر إفادة)* | `https://github.com/ProjectIgnis/CardScripts` | **المرجع البرمجي الأول:** يحتوي على سكريبتات `Lua` (`c<password>.lua`) لأكثر من 13,000 بطاقة، ويُستخدم لمطابقة وإصلاح منطق تأثيرات البطاقات وشروط تفعيلها بدقة 100% داخل `custom_effects_*.gd`. |
| **2** | **Project Ignis (`BabelCDB`)** | `https://github.com/ProjectIgnis/BabelCDB` | قواعد بيانات `SQLite` (`.cdb`) لنصوص التأثيرات وأسماء البطاقات وأرقامها الرسمية المقترنة بسكريبتات `CardScripts`. |
| **3** | **YGOJSON (`iconmaster5326/YGOJSON`)** | `https://github.com/iconmaster5326/YGOJSON` | قاعدة بيانات JSON المجمعة (فرع `aggregate`) التي استُخدمت لبناء بيانات الـ 630 بطاقة الإضافية في `game/assets/cards/extra_cards.json`. |
| **4** | **YGOPRODeck JSON API v7** | `https://db.ygoprodeck.com/api/v7/cardinfo.php` | ملف JSON شامل لبيانات وصور البطاقات. **ملاحظة مهمة:** يجب دائماً حفظ الصور محلياً داخل المشروع وعدم سحبها مباشرة من الرابط أثناء اللعب لتجنب حظر الـ IP. |

---

## 3. جدول أرقام الفصائل والعناصر في محرك Power of Chaos

عند مراجعة أو كتابة أي تأثير في `custom_effects_*.gd`:
- **العناصر (`CustomDuelOps.monster_attr`):**
  - `1`: LIGHT (ضوء) | `2`: DARK (ظلام) | `3`: WATER (ماء) | `4`: FIRE (نار) | `5`: EARTH (أرض) | `6`: WIND (رياح) | `7`: DIVINE (إلهي)
- **الفصائل (`CustomDuelOps.monster_race`):**
  - `1`: Dragon | `2`: Zombie | `3`: Fiend | `4`: Pyro | `5`: Sea Serpent | `6`: Rock | `7`: Machine | `8`: Fish | `9`: Dinosaur | `10`: Insect | `11`: Beast | `12`: Beast-Warrior | `13`: Plant | `14`: Aqua | `15`: Warrior | `16`: Winged Beast | `17`: Fairy | `18`: Spellcaster | `19`: Thunder | `20`: Reptile | `24` (`0x18`): Divine-Beast
