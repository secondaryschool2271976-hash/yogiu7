class_name ArabicDialogs
extends RefCounted

const BY_INDEX := {
	501: "تنين",
	502: "زومبي",
	503: "شيطان",
	504: "ناري",
	505: "ثعبان بحر",
	506: "صخري",
	507: "آلة",
	508: "سمك",
	509: "ديناصور",
	510: "حشرة",
	511: "وحش",
	512: "وحش محارب",
	513: "نبات",
	514: "مائي",
	515: "محارب",
	516: "وحش مجنح",
	517: "جنية",
	518: "ساحر",
	519: "رعد",
	520: "زاحف",
	521: "بطاقة فخ",
	522: "بطاقة سحر",
	523: "طقوس",
	524: "إله",
	531: "الضوء",
	532: "الظلام",
	533: "الماء",
	534: "النار",
	535: "الأرض",
	536: "الرياح",
	550: "/تأثير",
	551: "/اندماج",
	552: "/طقوس",
	553: "/توكين",
	554: "/روح",
	4137: "المجموعة الرئيسية يجب أن تحتوي على 40 بطاقة على الأقل.",
	4138: "لا يمكنك وضع أكثر من 3 نسخ من نفس البطاقة.",
	4139: "المجموعة الجانبية يجب أن تحتوي على 15 بطاقة بالضبط للتبديل.",
	4140: "تعذر حفظ الملف.",
}

const EXACT_PHRASES := {
	"Designate which one of your opponent's monsters that you wish to offer as tribute.": "حدد أي وحش من وحوش خصمك تريد تقديمه كتضحية.",
	"Designate which one of your opponent's monsters that you wish to offer as tribute": "حدد أي وحش من وحوش خصمك تريد تقديمه كتضحية",
	"Select a card.": "اختر بطاقة.",
	"Select a Monster Card.": "اختر بطاقة وحش.",
	"Select a Spell Card.": "اختر بطاقة سحر.",
	"Select a Trap Card.": "اختر بطاقة فخ.",
	"Select a Magic Card.": "اختر بطاقة سحر.",
	"Select a Spell or Trap Card.": "اختر بطاقة سحر أو فخ.",
	"Select a Magic or Trap Card.": "اختر بطاقة سحر أو فخ.",
	"Select a card to discard.": "اختر بطاقة للتخلص منها.",
	"Select a card from your hand.": "اختر بطاقة من يدك.",
	"Select a card from your Graveyard.": "اختر بطاقة من مقبرتك.",
	"Select a card from your Deck.": "اختر بطاقة من مجموعتك.",
	"Select a monster to Tribute.": "اختر وحشاً للتضحية به.",
	"Select 1 monster to Tribute.": "اختر وحشاً واحداً للتضحية به.",
	"Select 2 monsters to Tribute.": "اختر وحشين للتضحية بهما.",
	"Select 3 monsters to Tribute.": "اختر 3 وحوش للتضحية بها.",
	"Select a monster to sacrifice.": "اختر وحشاً للتضحية به.",
	"Select the battle position.": "اختر وضع البطاقة في الملعب.",
	"Select the Battle Position.": "اختر وضع البطاقة في الملعب.",
	"Select battle position.": "اختر وضع البطاقة في الملعب.",
	"Select a target.": "اختر هدفاً.",
	"Select a monster to destroy.": "اختر وحشاً لتدميره.",
	"Select a monster to Special Summon.": "اختر وحشاً للاستدعاء الخاص.",
	"Select a monster to equip.": "اختر وحشاً لتجهيزه بهذه البطاقة.",
	"Select a card to return to the hand.": "اختر بطاقة لإعادتها إلى اليد.",
	"Select a card to remove from play.": "اختر بطاقة لاستبعادها من اللعب.",
	"Select a Monster Type.": "اختر نوع الوحش.",
	"Select an Attribute.": "اختر عنصر الوحش.",
	"Select Heads or Tails.": "اختر صورة أو كتابة (العملة).",
	"Do you want to chain a card?": "هل تريد تفعيل بطاقة في سلسلة (Chain)؟",
	"Do you want to chain another card?": "هل تريد تفعيل بطاقة أخرى في السلسلة؟",
	"Do you want to activate a card?": "هل تريد تفعيل بطاقة؟",
	"Do you want to activate a Trap Card?": "هل تريد تفعيل بطاقة فخ؟",
	"Do you want to activate a Spell Card?": "هل تريد تفعيل بطاقة سحر؟",
	"Do you want to activate a Quick-Play Spell Card?": "هل تريد تفعيل بطاقة سحر سريعة؟",
	"Do you want to activate a Trap or Quick-Play Spell Card?": "هل تريد تفعيل بطاقة فخ أو سحر سريع؟",
	"Do you want to activate the effect?": "هل تريد تفعيل التأثير؟",
	"Do you want to activate this card's effect?": "هل تريد تفعيل تأثير هذه البطاقة؟",
	"Do you want to activate the effect of this card?": "هل تريد تفعيل تأثير هذه البطاقة؟",
	"Would you like to activate a card?": "هل تريد تفعيل بطاقة؟",
	"Would you like to chain a card?": "هل تريد تفعيل بطاقة في السلسلة؟",
	"Would you like to chain another card?": "هل تريد تفعيل بطاقة أخرى في السلسلة؟",
	"Would you like to use the effect of a card?": "هل تريد استخدام تأثير بطاقة؟",
	"Attack directly?": "هل تريد الهجوم المباشر على نقاط الخصم؟",
	"Do you want to attack directly?": "هل تريد الهجوم المباشر على نقاط الخصم؟",
	"Continue attacking?": "هل تريد متابعة الهجوم؟",
	"End your Battle Phase?": "هل تريد إنهاء مرحلة القتال؟",
	"End your turn?": "هل تريد إنهاء دورك؟",
	"Are you sure you want to surrender?": "هل أنت متأكد أنك تريد الاستسلام؟",
	"Do you want to save the replay?": "هل تريد حفظ إعادة المبارزة؟",
}

const HELP_TEXTS := [
	"لا توجد وحوش كافية للتضحية لاستدعاء هذا الوحش.",
	"لا يمكن تفعيل هذه البطاقة في نفس الدور الذي وُضعت فيه.",
	"لقد قمت بالاستدعاء العادي بالفعل في هذا الدور.",
	"لا يمكن تغيير وضع هذا الوحش في هذا الدور.",
	"لا يمكنك تفعيل هذه البطاقة الآن.",
	"لا يمكن تفعيل بطاقة السحر العادية أثناء مرحلة القتال.",
	"لا يمكن استدعاء أو وضع وحش أثناء مرحلة القتال.",
	"لا يمكن لهذا الوحش الهجوم الآن.",
	"لقد هاجم هذا الوحش بالفعل في هذا الدور.",
	"لا يمكنك التحكم بهذه البطاقة الآن.",
	"شروط تفعيل بطاقة سحر الطقوس غير متوفرة حالياً.",
	"منطقة الوحوش في ملعبك ممتلئة.",
	"منطقة السحر والفخاخ في ملعبك ممتلئة.",
	"لا يمكن استدعاء هذا الوحش استدعاءً خاصاً الآن.",
	"لا توجد أهداف صالحة لهذه البطاقة.",
	"لا يمكن وضع بطاقة فخ أثناء مرحلة القتال.",
	"لا يمكنك استخدام هذه البطاقة بسبب تأثير بطاقة أخرى.",
	"لا يمكنك تنفيذ هذا الإجراء حالياً.",
	"لا يمكن تغيير وضع هذا الوحش بسبب تأثير بطاقة أخرى.",
	"لا يمكن لهذا الوحش الهجوم بسبب تأثير بطاقة في الملعب.",
	"تفعيل هذه البطاقة ممنوع بسبب تأثير بطاقة في الملعب.",
	"لا يمكن تفعيل هذه البطاقة في هذه الخطوة من المعركة.",
	"لا يمكن تفعيل هذه البطاقة في هذه المرحلة.",
	"نقاط حياتك غير كافية لدفع تكلفة تفعيل هذه البطاقة.",
]


static func help_text(index: int) -> String:
	if index >= 0 and index < HELP_TEXTS.size():
		return String(HELP_TEXTS[index])
	return "لا يمكنك القيام بهذا الإجراء الآن."


static func localize_dialog_array(source: Array) -> Array:
	var out: Array = source.duplicate()
	for i in out.size():
		if BY_INDEX.has(i):
			out[i] = BY_INDEX[i]
		elif out[i] is String:
			out[i] = translate_template(String(out[i]))
	return out


static func translate_template(raw: String) -> String:
	if raw == "":
		return raw
	var parts: PackedStringArray = raw.split("<HR>", false)
	if parts.size() > 1:
		var out_parts: PackedStringArray = []
		for p in parts:
			out_parts.append(translate_template(p))
		return "<HR>".join(out_parts)
	var br_parts: PackedStringArray = raw.split("<BR>", false)
	if br_parts.size() > 1:
		var out_br: PackedStringArray = []
		for b in br_parts:
			out_br.append(_translate_segment(b))
		return "<BR>".join(out_br)
	return _translate_segment(raw)


static func translate_formatted(text: String) -> String:
	if text == "":
		return text
	var lines: PackedStringArray = text.split("\n", false)
	var out: PackedStringArray = []
	for line in lines:
		out.append(_translate_segment(line))
	return "\n".join(out)


static func _translate_segment(seg: String) -> String:
	var trimmed: String = seg.strip_edges()
	if trimmed == "":
		return seg
	if EXACT_PHRASES.has(trimmed):
		return String(EXACT_PHRASES[trimmed])
	var s: String = seg
	# Reemplazos de plantillas frecuentes del motor de duelo (dlg_eng.json)
	s = _rep_ci(s, "Designate which one of your opponent's monsters that you wish to offer as tribute", "حدد أي وحش من وحوش خصمك تريد تقديمه كتضحية")
	s = _rep_ci(s, "Do you want to activate the effect of", "هل تريد تفعيل تأثير")
	s = _rep_ci(s, "Would you like to activate the effect of", "هل تريد تفعيل تأثير")
	s = _rep_ci(s, "Do you want to use the effect of", "هل تريد استخدام تأثير")
	s = _rep_ci(s, "Would you like to use the effect of", "هل تريد استخدام تأثير")
	s = _rep_ci(s, "Do you want to activate", "هل تريد تفعيل")
	s = _rep_ci(s, "Would you like to activate", "هل تريد تفعيل")
	s = _rep_ci(s, "Do you want to chain another card", "هل تريد تفعيل بطاقة أخرى في السلسلة")
	s = _rep_ci(s, "Would you like to chain another card", "هل تريد تفعيل بطاقة أخرى في السلسلة")
	s = _rep_ci(s, "Do you want to chain", "هل تريد تفعيل بطاقة في السلسلة")
	s = _rep_ci(s, "Would you like to chain", "هل تريد تفعيل بطاقة في السلسلة")
	s = _rep_ci(s, "Do you want to Special Summon", "هل تريد استدعاء خاص لـ")
	s = _rep_ci(s, "Would you like to Special Summon", "هل تريد استدعاء خاص لـ")
	s = _rep_ci(s, "Do you want to Tribute Summon", "هل تريد استدعاء بالتضحية لـ")
	s = _rep_ci(s, "Do you want to Normal Summon", "هل تريد استدعاء عادي لـ")
	s = _rep_ci(s, "Do you want to Flip Summon", "هل تريد استدعاء بالقلب لـ")
	s = _rep_ci(s, "Do you want to Summon", "هل تريد استدعاء")
	s = _rep_ci(s, "Do you want to Set", "هل تريد وضع")
	s = _rep_ci(s, "Do you want to pay", "هل تريد دفع")
	s = _rep_ci(s, "Would you like to pay", "هل تريد دفع")
	s = _rep_ci(s, "Do you want to discard", "هل تريد التخلص من")
	s = _rep_ci(s, "Do you want to send", "هل تريد إرسال")
	s = _rep_ci(s, "Do you want to destroy", "هل تريد تدمير")
	s = _rep_ci(s, "Do you want to return", "هل تريد إعادة")
	s = _rep_ci(s, "Do you want to attack directly", "هل تريد الهجوم المباشر")
	s = _rep_ci(s, "Do you want to continue attacking", "هل تريد متابعة الهجوم")
	s = _rep_ci(s, "Do you want to", "هل تريد")
	s = _rep_ci(s, "Would you like to", "هل تريد")
	s = _rep_ci(s, "Select the battle position of", "اختر وضع البطاقة في الملعب لـ")
	s = _rep_ci(s, "Select the battle position", "اختر وضع البطاقة في الملعب")
	s = _rep_ci(s, "Select battle position", "اختر وضع البطاقة في الملعب")
	s = _rep_ci(s, "Select a monster to Tribute", "اختر وحشاً للتضحية به")
	s = _rep_ci(s, "Select monsters to Tribute", "اختر الوحوش للتضحية بها")
	s = _rep_ci(s, "Select a monster to sacrifice", "اختر وحشاً للتضحية به")
	s = _rep_ci(s, "Select monsters to sacrifice", "اختر الوحوش للتضحية بها")
	s = _rep_ci(s, "Select a card to discard", "اختر بطاقة للتخلص منها")
	s = _rep_ci(s, "Select cards to discard", "اختر بطاقات للتخلص منها")
	s = _rep_ci(s, "Select a card to destroy", "اختر بطاقة لتدميرها")
	s = _rep_ci(s, "Select a monster to destroy", "اختر وحشاً لتدميره")
	s = _rep_ci(s, "Select a Spell or Trap Card to destroy", "اختر بطاقة سحر أو فخ لتدميرها")
	s = _rep_ci(s, "Select a Magic or Trap Card to destroy", "اختر بطاقة سحر أو فخ لتدميرها")
	s = _rep_ci(s, "Select a monster to Special Summon", "اختر وحشاً للاستدعاء الخاص")
	s = _rep_ci(s, "Select a monster to equip", "اختر وحشاً لتجهيزه")
	s = _rep_ci(s, "Select a card to return to your hand", "اختر بطاقة لإعادتها إلى يدك")
	s = _rep_ci(s, "Select a card to return to the hand", "اختر بطاقة لإعادتها إلى اليد")
	s = _rep_ci(s, "Select a card to add to your hand", "اختر بطاقة لإضافتها إلى يدك")
	s = _rep_ci(s, "Select a card to send to the Graveyard", "اختر بطاقة لإرسالها إلى المقبرة")
	s = _rep_ci(s, "Select a card to remove from play", "اختر بطاقة لاستبعادها من اللعب")
	s = _rep_ci(s, "Select a target for", "اختر هدفاً لـ")
	s = _rep_ci(s, "Select a target", "اختر هدفاً")
	s = _rep_ci(s, "Select an attack target", "اختر هدف الهجوم")
	s = _rep_ci(s, "Select the monster to attack", "اختر الوحش الذي تريد مهاجمته")
	s = _rep_ci(s, "Select a Monster Type", "اختر نوع الوحش")
	s = _rep_ci(s, "Select an Attribute", "اختر عنصر الوحش")
	s = _rep_ci(s, "Select a Level", "اختر المستوى (عدد النجوم)")
	s = _rep_ci(s, "Select Heads or Tails", "اختر صورة أو كتابة (العملة)")
	s = _rep_ci(s, "Select a Monster Card", "اختر بطاقة وحش")
	s = _rep_ci(s, "Select a Spell Card", "اختر بطاقة سحر")
	s = _rep_ci(s, "Select a Magic Card", "اختر بطاقة سحر")
	s = _rep_ci(s, "Select a Trap Card", "اختر بطاقة فخ")
	s = _rep_ci(s, "Select a Spell or Trap Card", "اختر بطاقة سحر أو فخ")
	s = _rep_ci(s, "Select a Magic or Trap Card", "اختر بطاقة سحر أو فخ")
	s = _rep_ci(s, "Select a card", "اختر بطاقة")
	s = _rep_ci(s, "Select", "اختر")
	s = _rep_ci(s, "Choose", "اختر")
	s = _rep_ci(s, "from your hand", "من يدك")
	s = _rep_ci(s, "from your Graveyard", "من مقبرتك")
	s = _rep_ci(s, "from your Deck", "من مجموعتك")
	s = _rep_ci(s, "from the Graveyard", "من المقبرة")
	s = _rep_ci(s, "from the field", "من الملعب")
	s = _rep_ci(s, "on the field", "في الملعب")
	s = _rep_ci(s, "on your side of the field", "في جانبك من الملعب")
	s = _rep_ci(s, "on your opponent's side of the field", "في ملعب الخصم")
	s = _rep_ci(s, "to your hand", "إلى يدك")
	s = _rep_ci(s, "to the Graveyard", "إلى المقبرة")
	s = _rep_ci(s, "to the top of your Deck", "إلى أعلى مجموعتك")
	s = _rep_ci(s, "to the bottom of your Deck", "إلى أسفل مجموعتك")
	s = _rep_ci(s, "in Attack Position", "في وضع الهجوم")
	s = _rep_ci(s, "in Defense Position", "في وضع الدفاع")
	s = _rep_ci(s, "face-up Attack Position", "وضع الهجوم المكشوف")
	s = _rep_ci(s, "face-up Defense Position", "وضع الدفاع المكشوف")
	s = _rep_ci(s, "face-down Defense Position", "وضع الدفاع المقلوب")
	s = _rep_ci(s, "Attack Position", "وضع الهجوم")
	s = _rep_ci(s, "Defense Position", "وضع الدفاع")
	s = _rep_ci(s, "Life Points", "نقطة أساسية")
	s = _rep_ci(s, "Monster Card(s)", "بطاقات وحش")
	s = _rep_ci(s, "Monster Cards", "بطاقات وحش")
	s = _rep_ci(s, "Monster Card", "بطاقة وحش")
	s = _rep_ci(s, "Spell/Trap Card(s)", "بطاقات سحر أو فخ")
	s = _rep_ci(s, "Spell or Trap Card", "بطاقة سحر أو فخ")
	s = _rep_ci(s, "Magic or Trap Card", "بطاقة سحر أو فخ")
	s = _rep_ci(s, "Spell Card", "بطاقة سحر")
	s = _rep_ci(s, "Magic Card", "بطاقة سحر")
	s = _rep_ci(s, "Trap Card", "بطاقة فخ")
	s = _rep_ci(s, "was activated", "تم تفعيلها")
	s = _rep_ci(s, "is activated", "يتم تفعيلها")
	s = _rep_ci(s, "was destroyed", "تم تدميرها")
	s = _rep_ci(s, "was negated", "تم إبطالها")
	s = _rep_ci(s, "Shuffle your Deck", "يتم خلط مجموعتك")
	return s


static func _rep_ci(text: String, pattern: String, replacement: String) -> String:
	var lower_text: String = text.to_lower()
	var lower_pat: String = pattern.to_lower()
	var idx: int = lower_text.find(lower_pat)
	if idx < 0:
		return text
	return text.substr(0, idx) + replacement + text.substr(idx + pattern.length())
