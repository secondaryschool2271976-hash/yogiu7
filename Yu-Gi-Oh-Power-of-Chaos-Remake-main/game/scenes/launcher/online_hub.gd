extends CanvasLayer
## Plataforma Online completa basada en la edicion elegida (Yugi / Kaiba / Joey):
## 1) Pantalla inicial de inicio de sesion (Google / Invitado / Cuenta / Offline)
## 2) Selector de edicion para Modo Online (Yugi the Destiny / Kaiba the Revenge / Joey the Passion)
## 3) Hub online completo para la edicion activa:
##    - Duelo Online (Crear sala con codigo, Unirse por codigo, Wi-Fi/IP directo, Editor de mazo)
##    - Jugadores (busqueda por ID, perfil, amigos, desafio directo en la edicion activa)
##    - Amigos y solicitudes en tiempo real
##    - Mi Perfil y Visor completo de coleccion de cartas (conteos por tipo, filtros y galeria visual)
## 4) Invitaciones directas a duelo en tiempo real respetando la edicion elegida.

signal launch_online_duel(game_id: String)
signal open_deck_editor_requested(game_id: String)
signal open_classic_lan_requested(game_id: String)

const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")
const CARDS_PER_PAGE := 36

var _backdrop := ColorRect.new()
var _login_panel := PanelContainer.new()
var _picker_panel := PanelContainer.new()
var _hub_panel := PanelContainer.new()
var _invite_panel := PanelContainer.new()
var _dm_panel := PanelContainer.new()

var _mode := "" # "", "login", "pick_game", "hub"
var _after_login_mode := "" # "", "pick_game", "profile", "friends"
var _selected_game := "joey"
var _joining_game := "joey"
var _hub_tab := "duel" # "duel", "players", "friends", "chat", "profile"
var _login_register_mode := false
var _busy := false
var _google_polling := false
var _google_state := ""

# Login controls
var _login_title: Label
var _login_status: Label
var _google_btn: Button
var _google_cancel_btn: Button
var _google_poll_ticking := false
var _guest_name_input: LineEdit
var _guest_btn: Button
var _user_input: LineEdit
var _pass_input: LineEdit
var _display_input: LineEdit
var _display_row: HBoxContainer
var _auth_submit_btn: Button
var _auth_switch_btn: Button
var _offline_btn: Button

# Edition picker controls
var _picker_me_label: Label
var _picker_cards_row: HBoxContainer
var _picker_friends_btn: Button
var _picker_status: Label

# Hub header & tabs
var _hub_me_label: Label
var _hub_copy_id_btn: Button
var _game_switch_btns: Dictionary = {}
var _tab_duel_btn: Button
var _tab_players_btn: Button
var _tab_friends_btn: Button
var _tab_chat_btn: Button
var _tab_profile_btn: Button
var _hub_status_label: Label
var _hub_content: VBoxContainer

# Matchmaking state
var _matchmaking := false
var _matchmaking_elapsed := 0.0
var _matchmaking_game := "joey"
var _matchmaking_timer_lbl: Label
var _matchmaking_btn: Button
var _matchmaking_cancel_btn: Button
var _matchmaking_status: Label

# Duel room tab state
var _pool_comp_btn: Button
var _pool_sandbox_btn: Button
var _pool_info_lbl: Label
var _pool_lock_banner: PanelContainer
var _duel_hosting := false
var _duel_joining := false
var _duel_room_code_label: Label
var _duel_copy_code_btn: Button
var _duel_host_btn: Button
var _duel_cancel_host_btn: Button
var _duel_join_input: LineEdit
var _duel_join_btn: Button
var _duel_ip_input: LineEdit
var _duel_ip_btn: Button
var _duel_room_status: Label

# Players tab state
var _search_input: LineEdit
var _online_only_cb: CheckBox
var _players_list: VBoxContainer
var _players_cache: Array = []

# Friends tab state
var _friends_search_input: LineEdit
var _friends_search_results: VBoxContainer
var _friends_list: VBoxContainer

# Global & Private Chat state
var _global_chat_messages: Array[Dictionary] = []
var _global_chat_scroll: ScrollContainer
var _global_chat_list: VBoxContainer
var _global_chat_input: LineEdit
var _global_chat_send_btn: Button

var _dm_friend_id := ""
var _dm_friend_name := ""
var _dm_friend_online := false
var _dm_title_lbl: Label
var _dm_scroll: ScrollContainer
var _dm_list: VBoxContainer
var _dm_input: LineEdit
var _dm_send_btn: Button
var _dm_challenge_btn: Button

# Profile viewer state
var _viewing_profile: Dictionary = {}
var _profile_filter := "all"
var _profile_page := 0
var _profile_card_ids: Array[int] = []
var _profile_container: VBoxContainer

# Live challenge & invite state
var _waiting_challenge := false
var _challenge_target_name := ""
var _challenge_game := "joey"
var _challenge_banner: PanelContainer
var _challenge_label: Label
var _incoming_invite: Dictionary = {}
var _invite_text: Label


func _game_name(game_id: String) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		match game_id:
			"yugi": return "يوغي · Yugi the Destiny"
			"kaiba": return "كايبا · Kaiba the Revenge"
			"joey": return "جوي · Joey the Passion"
	return str(Game.TITLES.get(game_id, game_id))


func _game_short(game_id: String) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		match game_id:
			"yugi": return "يوغي"
			"kaiba": return "كايبا"
			"joey": return "جوي"
	match game_id:
		"yugi": return "Yugi"
		"kaiba": return "Kaiba"
		"joey": return "Joey"
	return game_id


func _default_installed_game() -> String:
	for g: String in ["joey", "kaiba", "yugi"]:
		if Paths.has_game(g):
			return g
	return "joey"


func _deck_card_count(game_id: String) -> int:
	if is_instance_valid(SaveData) and SaveData.data.get("decks") is Dictionary:
		var decks_map: Dictionary = SaveData.data["decks"]
		if decks_map.get(game_id) is Dictionary:
			var main_val: Variant = (decks_map[game_id] as Dictionary).get("main", [])
			if main_val is Array:
				return (main_val as Array).size()
	return 40


func _t(key: String) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		match key:
			"login_title": return "تسجيل الدخول · Yu-Gi-Oh! Online"
			"login_sub": return "سجّل دخولك داخل اللعبة فوراً أو بحساب جوجل لتحصل على ID دائم، تحفظ أوراقك، وتلعب أونلاين"
			"google_btn": return "تسجيل الدخول بحساب جوجل (Google)"
			"google_note": return "لحماية حسابك، تفتح Google صفحة تسجيل آمنة لمرة واحدة ثم تعود هنا مسجّلاً تلقائياً — أو ادخل مباشرة من داخل اللعبة بالأسفل:"
			"google_cancel": return "إلغاء الانتظار"
			"guest_section": return "دخول مباشر من داخل اللعبة (اسمك + ID دائم بدون مغادرة اللعبة):"
			"guest_hint": return "اكتب اسمك (مثال: Yugi)"
			"guest_btn": return "دخول مباشر"
			"account_section": return "أو حساب وكلمة مرور من داخل اللعبة:"
			"user_hint": return "اسم المستخدم (إنجليزي)"
			"pass_hint": return "كلمة المرور (6 أحرف على الأقل)"
			"disp_hint": return "الاسم الظاهر في اللعبة"
			"login_btn": return "تسجيل الدخول"
			"register_btn": return "إنشاء حساب جديد"
			"switch_to_reg": return "ليس لديك حساب؟ إنشاء حساب"
			"switch_to_login": return "لديك حساب بالفعل؟ تسجيل الدخول"
			"offline_btn": return "تخطي (اللعب أوفلاين الآن)"
			"google_wait": return "تم فتح المتصفح لتسجيل الدخول بحساب جوجل... في انتظار التأكيد"
			"google_unconfigured": return "تسجيل جوجل غير مفعّل على السيرفر حالياً. يمكنك الدخول بحساب أو كضيف."
			"connecting": return "جاري الاتصال بالسيرفر... (قد يستغرق لحظات لو السيرفر كان في وضع السكون)"
			"err_net": return "تعذر الاتصال بالسيرفر. تأكد من الإنترنت وحاول مرة أخرى."
			"err_creds": return "اسم المستخدم أو كلمة المرور غير صحيحة."
			"err_user": return "اسم المستخدم يجب أن يكون 3-24 حرفاً إنجليزياً أو أرقاماً."
			"err_pass": return "كلمة المرور يجب أن تكون 6 أحرف على الأقل."
			"err_taken": return "اسم المستخدم محجوز بالفعل، اختر اسماً آخر."
			"picker_title": return "الوضع الأونلاين — اختر الإصدار"
			"picker_sub": return "اختر الجزء الذي تريد اللعب به أونلاين (يوغي، كايبا، أو جوي) للدخول إلى المنصة الكاملة"
			"installed_ready": return "جاهز للعب أونلاين"
			"not_installed": return "غير مثبّت على جهازك"
			"deck_info": return "مجموعتك: %d ورقة"
			"enter_online": return "دخول الأونلاين"
			"tab_duel": return "المبارزة الأونلاين"
			"tab_players": return "اللاعبين"
			"tab_friends": return "الأصدقاء"
			"tab_chat": return "الشات العام"
			"tab_profile": return "ملفي والأوراق"
			"copy_id": return "نسخ الـ ID"
			"copied_id": return "تم نسخ الـ ID: %s"
			"copy_code": return "نسخ الكود"
			"copied_code": return "تم نسخ كود الغرفة: %s"
			"edit_deck": return "تعديل المجموعة"
			"mm_title": return "توفيق عشوائي أونلاين (مباراة فورية)"
			"mm_desc": return "ابحث تلقائياً عن خصم عشوائي متصل الآن بنفس الإصدار (%s) وابدآ المبارزة فوراً"
			"mm_start": return "بدء التوفيق العشوائي"
			"mm_cancel": return "إلغاء البحث"
			"mm_searching": return "جاري البحث عن خصم في %s... (%d في الانتظار)"
			"mm_found": return "تم العثور على خصم: %s (#%s)! جاري الدخول للمبارزة..."
			"host_title": return "إنشاء غرفة مبارزة أونلاين"
			"host_desc": return "أنشئ غرفة وأرسل الكود لصديقك ليدخل معك فوراً على الإنترنت"
			"host_btn": return "إنشاء غرفة"
			"cancel_room": return "إلغاء الغرفة"
			"waiting_room": return "في انتظار خصمك... شارك هذا الكود: %s"
			"join_title": return "الانضمام بكود غرفة"
			"join_hint": return "اكتب كود الغرفة (6 أرقام)"
			"join_btn": return "دخول الغرفة"
			"wifi_title": return "لعب واي فاي محلي (Direct IP / LAN)"
			"ip_hint": return "عنوان IP المضيف (مثال: 192.168.1.5)"
			"ip_btn": return "اتصال IP"
			"classic_lan_btn": return "شاشة LAN الكلاسيكية"
			"bad_code": return "اكتب كود الغرفة أولاً."
			"bad_ip": return "اكتب عنوان IP المضيف أولاً."
			"room_not_found": return "كود الغرفة غير موجود أو انتهت صلاحيته."
			"room_full": return "الغرفة ممتلئة بالفعل."
			"room_game_mismatch": return "هذه الغرفة مخصصة لإصدار %s — بدّل الإصدار وحاول مجدداً."
			"room_expired": return "انتهت مهلة الغرفة أو أغلقها المضيف."
			"room_timeout": return "انتهى وقت الاتصال بالغرفة، حاول مجدداً."
			"search_hint": return "ابحث بـ ID اللاعب أو الاسم..."
			"search_btn": return "بحث"
			"open_id_btn": return "فتح ID"
			"online_only": return "متصلين فقط"
			"refresh": return "تحديث"
			"online": return "متصل الآن"
			"offline": return "أوفلاين"
			"view_profile": return "الملف والأوراق"
			"add_friend": return "+ إضافة صديق"
			"pending_out": return "تم إرسال الطلب"
			"accept": return "قبول"
			"reject": return "رفض"
			"remove_friend": return "حذف"
			"challenge": return "تحدي"
			"friend_chat_btn": return "محادثة"
			"friends_badge": return "صديق"
			"incoming_title": return "طلبات صداقة واردة"
			"friends_title": return "قائمة الأصدقاء"
			"outgoing_title": return "طلبات مرسلة"
			"no_players": return "لا يوجد لاعبين مطابقين للبحث حالياً."
			"no_friends": return "لا يوجد أصدقاء بعد. ابحث عن لاعب بـ ID وأرسل له طلب صداقة!"
			"chat_hint": return "اكتب رسالة للجميع في السيرفر..."
			"chat_send": return "إرسال"
			"chat_empty": return "لا توجد رسائل بعد. ابدأ المحادثة الآن!"
			"dm_title": return "محادثة خاصة مع %s (#%s)"
			"dm_hint": return "اكتب رسالة خاصة لصديقك..."
			"dm_empty": return "لا توجد رسائل بينكما بعد."
			"rate_limited": return "أرسلت رسائل بسرعة كبيرة، انتظر قليلاً."
			"cards_lbl": return "الأوراق"
			"wins_lbl": return "فوز"
			"losses_lbl": return "خسارة"
			"total_copies": return "إجمالي النسخ"
			"unique_cards": return "فريدة"
			"f_all": return "الكل"
			"f_normal": return "وحش عادي"
			"f_effect": return "تأثير"
			"f_fusion": return "دمج"
			"f_ritual": return "طقوس"
			"f_spell": return "سحر"
			"f_trap": return "فخ"
			"prev_page": return "السابق"
			"next_page": return "التالي"
			"sync_now": return "مزامنة أوراقي"
			"synced_ok": return "تمت مزامنة أوراقك وإحصائياتك مع السيرفر!"
			"rename_btn": return "تغيير الاسم"
			"logout_btn": return "تسجيل الخروج"
			"close": return "إغلاق"
			"challenge_wait": return "تم إرسال تحدي إلى %s (%s) — في انتظار قبوله... (كود الغرفة: %s)"
			"cancel_challenge": return "إلغاء التحدي"
			"invite_title": return "⚔️ إشعار تحدي مبارزة أونلاين!"
			"invite_body": return "%s أرسل لك تحدي مبارزة أونلاين!\n(الحساب: #%s  ·  الإصدار: %s)"
			"invite_accept": return "قبول التحدي"
			"invite_decline": return "رفض"
			"invite_declined": return "رفض %s التحدي."
			"invite_offline": return "اللاعب غير متصل حالياً. يمكنك إرسال كود الغرفة (%s) له يدوياً."
			"not_found_id": return "لم يتم العثور على لاعب بهذا الـ ID."
			"req_sent": return "تم إرسال طلب الصداقة!"
			"now_friends": return "أصبحتما أصدقاء الآن!"
			"need_game": return "تحتاج تثبيت ملفات إصدار %s أولاً لبدء هذه المبارزة."
			"no_cards_yet": return "لا توجد أوراق في هذا القسم بعد."
			"pool_title": return "اختر سيرفر اللعب الأونلاين"
			"pool_competitive": return "🏆 وضع المنافسة (عادي)"
			"pool_sandbox": return "🧪 وضع اختبار المجموعات"
			"pool_comp_desc": return "سيرفر المنافسة العادلة: مخصص فقط للاعبين الذين يجمعون البطاقات بالطريقة العادية بدون كود فتح كل البطاقات."
			"pool_sandbox_desc": return "سيرفر اختبار المجموعات: يضم اللاعبين الذين فتحوا كل البطاقات (ويمكن لأي لاعب الدخول إليه لتجربة المجموعات)."
			"pool_locked_banner": return "🔒 حسابك استخدم كود «فتح كل البطاقات» — لضمان العدل، تلعب حصرياً في «🧪 وضع اختبار المجموعات» ولا يمكنك دخول وضع المنافسة."
			"pool_badge_sandbox": return "🧪 اختبار المجموعات"
			"err_sandbox_only": return "حسابك مفعّل عليه كود فتح كل البطاقات — مسموح لك اللعب فقط في سيرفر «🧪 وضع اختبار المجموعات»."
			"err_pool_mismatch_comp": return "هذه الغرفة في «🏆 وضع المنافسة» — بدّل السيرفر إلى وضع المنافسة ثم حاول مجدداً."
			"err_pool_mismatch_sandbox": return "هذه الغرفة في «🧪 وضع اختبار المجموعات» — بدّل السيرفر إلى وضع اختبار المجموعات ثم حاول مجدداً."
			"err_target_sandbox_only": return "هذا اللاعب فتح كل البطاقات ويلعب فقط في «🧪 وضع اختبار المجموعات» — بدّل إلى وضع اختبار المجموعات لتتحداه."
		return ""
	if lang == "s":
		match key:
			"login_title": return "Iniciar sesión · Yu-Gi-Oh! Online"
			"login_sub": return "Inicia sesión dentro del juego o con Google para obtener tu ID permanente y jugar online"
			"google_btn": return "Iniciar sesión con Google"
			"google_note": return "Por seguridad de Google, se abre su página oficial una sola vez y vuelves ya conectado — o entra directo dentro del juego abajo:"
			"google_cancel": return "Cancelar espera"
			"guest_section": return "Entrada directa dentro del juego (sin salir del juego):"
			"guest_hint": return "Tu nombre (ej. Yugi)"
			"guest_btn": return "Jugar como invitado"
			"account_section": return "O con cuenta y contraseña:"
			"user_hint": return "Usuario (3-24 caracteres)"
			"pass_hint": return "Contraseña (mín. 6)"
			"disp_hint": return "Nombre visible"
			"login_btn": return "Iniciar sesión"
			"register_btn": return "Crear cuenta"
			"switch_to_reg": return "¿Sin cuenta? Crear una"
			"switch_to_login": return "¿Ya tienes cuenta? Entrar"
			"offline_btn": return "Omitir (Jugar offline)"
			"google_wait": return "Se abrió el navegador para Google... esperando confirmación"
			"google_unconfigured": return "Google Sign-In no está configurado en el servidor. Usa Cuenta o Invitado."
			"connecting": return "Conectando al servidor..."
			"err_net": return "No se pudo conectar al servidor."
			"err_creds": return "Usuario o contraseña incorrectos."
			"err_user": return "Usuario inválido (3-24 letras/números)."
			"err_pass": return "Contraseña mínima de 6 caracteres."
			"err_taken": return "Ese usuario ya existe."
			"picker_title": return "Modo Online — Elige tu edición"
			"picker_sub": return "Selecciona Yugi, Kaiba o Joey para abrir la sala online completa"
			"installed_ready": return "Listo para jugar online"
			"not_installed": return "No instalado"
			"deck_info": return "Tu mazo: %d cartas"
			"enter_online": return "Entrar Online"
			"tab_duel": return "Duelo Online"
			"tab_players": return "Jugadores"
			"tab_friends": return "Amigos"
			"tab_chat": return "Chat Global"
			"tab_profile": return "Mi Perfil"
			"copy_id": return "Copiar ID"
			"copied_id": return "ID copiado: %s"
			"copy_code": return "Copiar código"
			"copied_code": return "Código copiado: %s"
			"edit_deck": return "Editar Mazo"
			"mm_title": return "Emparejamiento Aleatorio Online"
			"mm_desc": return "Busca automáticamente un oponente conectado en %s"
			"mm_start": return "Buscar Partida"
			"mm_cancel": return "Cancelar"
			"mm_searching": return "Buscando oponente en %s... (%d en cola)"
			"mm_found": return "¡Oponente encontrado: %s (#%s)! Conectando..."
			"host_title": return "Crear sala online"
			"host_desc": return "Crea una sala y comparte el código de 6 dígitos con tu amigo"
			"host_btn": return "Crear sala"
			"cancel_room": return "Cancelar sala"
			"waiting_room": return "Esperando oponente... Código: %s"
			"join_title": return "Unirse con código"
			"join_hint": return "Código de sala (6 dígitos)"
			"join_btn": return "Unirse"
			"wifi_title": return "Wi-Fi local (IP Directa / LAN)"
			"ip_hint": return "IP del anfitrión (ej. 192.168.1.5)"
			"ip_btn": return "Conectar IP"
			"classic_lan_btn": return "Pantalla LAN clásica"
			"bad_code": return "Introduce el código de sala primero."
			"bad_ip": return "Introduce la IP del anfitrión."
			"room_not_found": return "Sala no encontrada o expirada."
			"room_full": return "La sala está llena."
			"room_game_mismatch": return "Esta sala es de %s — cambia de edición e inténtalo de nuevo."
			"room_expired": return "La sala expiró o fue cerrada."
			"room_timeout": return "Tiempo de conexión agotado."
			"search_hint": return "Buscar por ID o nombre..."
			"search_btn": return "Buscar"
			"open_id_btn": return "Abrir ID"
			"online_only": return "Solo online"
			"refresh": return "Actualizar"
			"online": return "En línea"
			"offline": return "Desconectado"
			"view_profile": return "Perfil y cartas"
			"add_friend": return "+ Amigo"
			"pending_out": return "Solicitud enviada"
			"accept": return "Aceptar"
			"reject": return "Rechazar"
			"remove_friend": return "Quitar"
			"challenge": return "Desafiar"
			"friend_chat_btn": return "Chat"
			"friends_badge": return "Amigo"
			"incoming_title": return "Solicitudes recibidas"
			"friends_title": return "Tus amigos"
			"outgoing_title": return "Solicitudes enviadas"
			"no_players": return "No se encontraron jugadores."
			"no_friends": return "Aún no tienes amigos. ¡Busca por ID para añadir!"
			"chat_hint": return "Escribe un mensaje global..."
			"chat_send": return "Enviar"
			"chat_empty": return "Sin mensajes aún. ¡Saluda!"
			"dm_title": return "Chat privado con %s (#%s)"
			"dm_hint": return "Escribe un mensaje privado..."
			"dm_empty": return "No hay mensajes privados aún."
			"rate_limited": return "Envías mensajes demasiado rápido."
			"cards_lbl": return "Cartas"
			"wins_lbl": return "Victorias"
			"losses_lbl": return "Derrotas"
			"total_copies": return "Copias totales"
			"unique_cards": return "Únicas"
			"f_all": return "Todas"
			"f_normal": return "Normal"
			"f_effect": return "Efecto"
			"f_fusion": return "Fusión"
			"f_ritual": return "Ritual"
			"f_spell": return "Magia"
			"f_trap": return "Trampa"
			"prev_page": return "Anterior"
			"next_page": return "Siguiente"
			"sync_now": return "Sincronizar"
			"synced_ok": return "¡Colección sincronizada con el servidor!"
			"rename_btn": return "Cambiar nombre"
			"logout_btn": return "Cerrar sesión"
			"close": return "Cerrar"
			"challenge_wait": return "Desafío enviado a %s (%s) — Esperando respuesta... (Código: %s)"
			"cancel_challenge": return "Cancelar reto"
			"invite_title": return "⚔️ ¡Notificación de desafío online!"
			"invite_body": return "¡%s te envió un desafío de duelo!\n(Cuenta: #%s  ·  Edición: %s)"
			"invite_accept": return "Aceptar desafío"
			"invite_decline": return "Rechazar"
			"invite_declined": return "%s rechazó el desafío."
			"invite_offline": return "Jugador desconectado. Comparte el código %s manualmente."
			"not_found_id": return "No existe ningún jugador con ese ID."
			"req_sent": return "¡Solicitud de amistad enviada!"
			"now_friends": return "¡Ahora son amigos!"
			"need_game": return "Necesitas los archivos de %s para jugar este duelo."
			"no_cards_yet": return "No hay cartas en esta categoría."
			"pool_title": return "Servidor Online"
			"pool_competitive": return "🏆 Modo Competitivo"
			"pool_sandbox": return "🧪 Prueba de Mazos"
			"pool_comp_desc": return "Servidor justo: solo jugadores con progresión normal (sin código de todas las cartas)."
			"pool_sandbox_desc": return "Servidor libre: jugadores con todas las cartas desbloqueadas y cualquiera que quiera probar mazos."
			"pool_locked_banner": return "🔒 Tu cuenta usó el código de Todas las Cartas — juegas exclusivamente en «🧪 Prueba de Mazos» para mantener el modo competitivo justo."
			"pool_badge_sandbox": return "🧪 Prueba de Mazos"
			"err_sandbox_only": return "Tu cuenta tiene todas las cartas desbloqueadas: solo puedes jugar en «🧪 Prueba de Mazos»."
			"err_pool_mismatch_comp": return "Esta sala pertenece al «🏆 Modo Competitivo». Cambia de servidor e inténtalo de nuevo."
			"err_pool_mismatch_sandbox": return "Esta sala pertenece a «🧪 Prueba de Mazos». Cambia de servidor e inténtalo de nuevo."
			"err_target_sandbox_only": return "Este jugador solo juega en «🧪 Prueba de Mazos». Cambia a Prueba de Mazos para desafiarlo."
		return ""
	match key:
		"login_title": return "Sign In · Yu-Gi-Oh! Online"
		"login_sub": return "Sign in right inside the game or with Google to get your permanent Player ID & duel online"
		"google_btn": return "Sign in with Google"
		"google_note": return "Google security opens its official sign-in page once and returns you automatically — or sign in 100% in-game below:"
		"google_cancel": return "Cancel Wait"
		"guest_section": return "Instant In-Game Sign In (stays 100% inside the game):"
		"guest_hint": return "Your name (e.g. Yugi)"
		"guest_btn": return "Play as Guest"
		"account_section": return "Or sign in with Username & Password:"
		"user_hint": return "Username (3-24 chars)"
		"pass_hint": return "Password (min 6 chars)"
		"disp_hint": return "Display Name"
		"login_btn": return "Sign In"
		"register_btn": return "Create Account"
		"switch_to_reg": return "New here? Create Account"
		"switch_to_login": return "Already have an account? Sign In"
		"offline_btn": return "Skip (Play Offline)"
		"google_wait": return "Browser opened for Google Sign-In... waiting for confirmation"
		"google_unconfigured": return "Google Sign-In is not enabled on this server. Use Account or Guest."
		"connecting": return "Connecting to server... (Render free tier may take ~30s to wake up)"
		"err_net": return "Could not reach server. Check your internet connection."
		"err_creds": return "Invalid username or password."
		"err_user": return "Username must be 3-24 letters/numbers."
		"err_pass": return "Password must be at least 6 characters."
		"err_taken": return "That username is already taken."
		"picker_title": return "Online Mode — Choose Your Edition"
		"picker_sub": return "Pick Yugi, Kaiba, or Joey to enter the full online dueling platform"
		"installed_ready": return "Ready for Online"
		"not_installed": return "Not installed"
		"deck_info": return "Your Deck: %d cards"
		"enter_online": return "Enter Online"
		"tab_duel": return "Online Duel"
		"tab_players": return "Players"
		"tab_friends": return "Friends"
		"tab_chat": return "Global Chat"
		"tab_profile": return "My Profile"
		"copy_id": return "Copy ID"
		"copied_id": return "Copied Player ID: %s"
		"copy_code": return "Copy Code"
		"copied_code": return "Copied Room Code: %s"
		"edit_deck": return "Edit Deck"
		"mm_title": return "Random Online Matchmaking"
		"mm_desc": return "Automatically pair with a random connected duelist in %s"
		"mm_start": return "Find Random Match"
		"mm_cancel": return "Cancel Search"
		"mm_searching": return "Searching in %s... (%d in queue)"
		"mm_found": return "Matched with %s (#%s)! Connecting to duel..."
		"host_title": return "Create Online Room"
		"host_desc": return "Host a room and share the 6-digit code with your opponent"
		"host_btn": return "Create Room"
		"cancel_room": return "Cancel Room"
		"waiting_room": return "Waiting for opponent... Share code: %s"
		"join_title": return "Join by Room Code"
		"join_hint": return "Enter 6-digit Room Code"
		"join_btn": return "Join Room"
		"wifi_title": return "Local Wi-Fi (Direct IP / LAN)"
		"ip_hint": return "Host IP (e.g. 192.168.1.5)"
		"ip_btn": return "Connect IP"
		"classic_lan_btn": return "Classic LAN Screen"
		"bad_code": return "Enter a room code first."
		"bad_ip": return "Enter the host IP address first."
		"room_not_found": return "Room code not found or expired."
		"room_full": return "That room is already full."
		"room_game_mismatch": return "This room is for %s — switch edition and try again."
		"room_expired": return "Room expired or closed by host."
		"room_timeout": return "Connection timed out. Please try again."
		"search_hint": return "Search by Player ID or name..."
		"search_btn": return "Search"
		"open_id_btn": return "Open ID"
		"online_only": return "Online only"
		"refresh": return "Refresh"
		"online": return "Online"
		"offline": return "Offline"
		"view_profile": return "Profile & Cards"
		"add_friend": return "+ Add Friend"
		"pending_out": return "Request Sent"
		"accept": return "Accept"
		"reject": return "Reject"
		"remove_friend": return "Remove"
		"challenge": return "Challenge"
		"friend_chat_btn": return "Chat"
		"friends_badge": return "Friend"
		"incoming_title": return "Incoming Friend Requests"
		"friends_title": return "Friends List"
		"outgoing_title": return "Outgoing Requests"
		"no_players": return "No players found."
		"no_friends": return "No friends yet. Search a Player ID to add friends!"
		"chat_hint": return "Write a message to everyone on the server..."
		"chat_send": return "Send"
		"chat_empty": return "No messages yet. Say hello!"
		"dm_title": return "Private Chat with %s (#%s)"
		"dm_hint": return "Write a private message..."
		"dm_empty": return "No messages yet."
		"rate_limited": return "Sending messages too fast, please wait a moment."
		"cards_lbl": return "Cards"
		"wins_lbl": return "Wins"
		"losses_lbl": return "Losses"
		"total_copies": return "Total Copies"
		"unique_cards": return "Unique"
		"f_all": return "All"
		"f_normal": return "Normal"
		"f_effect": return "Effect"
		"f_fusion": return "Fusion"
		"f_ritual": return "Ritual"
		"f_spell": return "Spell"
		"f_trap": return "Trap"
		"prev_page": return "Prev"
		"next_page": return "Next"
		"sync_now": return "Sync Cards"
		"synced_ok": return "Your cards and stats are synced!"
		"rename_btn": return "Rename"
		"logout_btn": return "Sign Out"
		"close": return "Close"
		"challenge_wait": return "Challenge sent to %s (%s) — Waiting for response... (Room: %s)"
		"cancel_challenge": return "Cancel"
		"invite_title": return "⚔️ Online Duel Challenge!"
		"invite_body": return "%s sent you a duel challenge!\n(Account: #%s  ·  Edition: %s)"
		"invite_accept": return "Accept Challenge"
		"invite_decline": return "Decline"
		"invite_declined": return "%s declined your challenge."
		"invite_offline": return "Player is offline. Share room code %s manually."
		"not_found_id": return "No player found with that ID."
		"req_sent": return "Friend request sent!"
		"now_friends": return "You are now friends!"
		"need_game": return "%s data files are required to play this duel."
		"no_cards_yet": return "No cards in this category yet."
		"pool_title": return "Online Server Mode"
		"pool_competitive": return "🏆 Competitive Mode"
		"pool_sandbox": return "🧪 Deck Testing"
		"pool_comp_desc": return "Fair ladder server: only normal progression accounts (without the Unlock All Cards code)."
		"pool_sandbox_desc": return "Free testing server: accounts with all cards unlocked (normal players may also join here to test decks)."
		"pool_locked_banner": return "🔒 Your account redeemed the Unlock All Cards code — to keep Competitive fair, you play exclusively in «🧪 Deck Testing»."
		"pool_badge_sandbox": return "🧪 Deck Testing"
		"err_sandbox_only": return "Unlocked-all accounts can only play in the «🧪 Deck Testing» server pool."
		"err_pool_mismatch_comp": return "This room is in «🏆 Competitive Mode» — switch server pool and try again."
		"err_pool_mismatch_sandbox": return "This room is in «🧪 Deck Testing» — switch server pool and try again."
		"err_target_sandbox_only": return "This player is in «🧪 Deck Testing» only — switch to Deck Testing to challenge them."
	return ""


func _make_box(bg: Color, border: Color, radius := 10, bw := 2, pad := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(bw)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	box.anti_aliasing = true
	return box


func _style_accent_button(btn: Button, bg: Color, hover: Color, border: Color) -> void:
	btn.add_theme_font_override("font", Assets.ui_font(700))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _make_box(bg, border, 8, 2, 8))
	btn.add_theme_stylebox_override("hover", _make_box(hover, DialogTheme.CYAN_SOFT, 8, 2, 8))
	btn.add_theme_stylebox_override("pressed", _make_box(bg.darkened(0.18), DialogTheme.GOLD, 8, 2, 8))
	btn.add_theme_stylebox_override("disabled", _make_box(Color(0.08, 0.10, 0.18, 0.72), Color(0.35, 0.45, 0.60, 0.4), 8, 1, 8))


func _style_input(edit: LineEdit) -> void:
	var n := _make_box(Color(0.028, 0.036, 0.088, 0.98), Color(DialogTheme.CYAN, 0.45), 6, 1, 7)
	var f := _make_box(Color(0.036, 0.048, 0.115, 0.99), DialogTheme.CYAN, 6, 2, 7)
	edit.add_theme_stylebox_override("normal", n)
	edit.add_theme_stylebox_override("focus", f)
	edit.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.74, 0.90, 0.55))
	edit.add_theme_color_override("caret_color", DialogTheme.CYAN)
	edit.add_theme_font_override("font", Assets.ui_font())
	edit.add_theme_font_size_override("font_size", 14)


func _ready() -> void:
	layer = 92
	_selected_game = _default_installed_game()
	_backdrop.color = Color(0.012, 0.015, 0.045, 0.86)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.hide()
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(center)

	_build_login_panel(center)
	_build_picker_panel(center)
	_build_hub_panel(center)
	_build_dm_panel()
	_build_invite_panel()
	_fit_panels_to_viewport()
	get_viewport().size_changed.connect(_fit_panels_to_viewport)

	Online.session_changed.connect(_on_session_changed)
	Online.friend_request_received.connect(_on_friend_request_received)
	Online.friend_accepted_received.connect(_on_friend_accepted_received)
	Online.duel_invite_received.connect(_on_duel_invite_received)
	Online.invite_declined_received.connect(_on_invite_declined_received)
	Online.invite_status_received.connect(_on_invite_status_received)
	Online.invite_error_received.connect(_on_invite_error_received)
	Online.matchmaking_queued.connect(_on_matchmaking_queued)
	Online.matchmaking_found.connect(_on_matchmaking_found)
	Online.matchmaking_left.connect(_on_matchmaking_left)
	Online.matchmaking_error_received.connect(_on_matchmaking_error_received)
	Online.global_chat_received.connect(_on_global_chat_received)
	Online.dm_received.connect(_on_dm_received)
	Online.chat_error_received.connect(_on_chat_error_received)


func _exit_tree() -> void:
	if Online.session_changed.is_connected(_on_session_changed):
		Online.session_changed.disconnect(_on_session_changed)
	if Online.friend_request_received.is_connected(_on_friend_request_received):
		Online.friend_request_received.disconnect(_on_friend_request_received)
	if Online.friend_accepted_received.is_connected(_on_friend_accepted_received):
		Online.friend_accepted_received.disconnect(_on_friend_accepted_received)
	if Online.duel_invite_received.is_connected(_on_duel_invite_received):
		Online.duel_invite_received.disconnect(_on_duel_invite_received)
	if Online.invite_declined_received.is_connected(_on_invite_declined_received):
		Online.invite_declined_received.disconnect(_on_invite_declined_received)
	if Online.invite_status_received.is_connected(_on_invite_status_received):
		Online.invite_status_received.disconnect(_on_invite_status_received)
	if Online.invite_error_received.is_connected(_on_invite_error_received):
		Online.invite_error_received.disconnect(_on_invite_error_received)
	if Online.matchmaking_queued.is_connected(_on_matchmaking_queued):
		Online.matchmaking_queued.disconnect(_on_matchmaking_queued)
	if Online.matchmaking_found.is_connected(_on_matchmaking_found):
		Online.matchmaking_found.disconnect(_on_matchmaking_found)
	if Online.matchmaking_left.is_connected(_on_matchmaking_left):
		Online.matchmaking_left.disconnect(_on_matchmaking_left)
	if Online.matchmaking_error_received.is_connected(_on_matchmaking_error_received):
		Online.matchmaking_error_received.disconnect(_on_matchmaking_error_received)
	if Online.global_chat_received.is_connected(_on_global_chat_received):
		Online.global_chat_received.disconnect(_on_global_chat_received)
	if Online.dm_received.is_connected(_on_dm_received):
		Online.dm_received.disconnect(_on_dm_received)
	if Online.chat_error_received.is_connected(_on_chat_error_received):
		Online.chat_error_received.disconnect(_on_chat_error_received)


func _fit_panels_to_viewport() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 10.0 or vp.y <= 10.0:
		return
	var login_w: float = minf(540.0, vp.x - 28.0)
	_login_panel.custom_minimum_size = Vector2(login_w, 0)
	var pick_w: float = minf(760.0, vp.x - 24.0)
	_picker_panel.custom_minimum_size = Vector2(pick_w, 0)
	var hub_w: float = minf(774.0, vp.x - 20.0)
	var hub_h: float = minf(564.0, vp.y - 20.0)
	_hub_panel.custom_minimum_size = Vector2(hub_w, hub_h)
	if is_instance_valid(_dm_panel):
		_dm_panel.custom_minimum_size = Vector2(minf(520.0, vp.x - 28.0), minf(440.0, vp.y - 40.0))
	if is_instance_valid(_invite_panel) and _invite_panel.visible:
		_center_invite_panel()


func is_open() -> bool:
	return _mode != "" or _invite_panel.visible or _dm_panel.visible


func open_login(after_mode := "") -> void:
	_after_login_mode = after_mode
	_mode = "login"
	_google_polling = false
	_set_login_busy(false)
	_login_register_mode = false
	_update_login_mode_ui()
	_login_status.text = ""
	_fit_panels_to_viewport()
	_backdrop.show()
	_picker_panel.hide()
	_hub_panel.hide()
	_login_panel.show()


func open_game_picker() -> void:
	if not Online.is_logged_in():
		open_login("pick_game")
		return
	_stop_active_room_wait()
	_mode = "pick_game"
	_fit_panels_to_viewport()
	_backdrop.show()
	_login_panel.hide()
	_hub_panel.hide()
	_picker_panel.show()
	_refresh_picker_cards()


func open_hub(initial_tab := "duel", game_id := "") -> void:
	if not Online.is_logged_in():
		open_login("pick_game" if initial_tab == "duel" else initial_tab)
		return
	if game_id != "" and game_id in Game.GAMES:
		_selected_game = game_id
	elif not Paths.has_game(_selected_game):
		_selected_game = _default_installed_game()
	_mode = "hub"
	_hub_tab = initial_tab
	_fit_panels_to_viewport()
	_backdrop.show()
	_login_panel.hide()
	_picker_panel.hide()
	_hub_panel.show()
	_refresh_hub_header()
	if initial_tab == "profile":
		_open_profile_by_id(Online.player_id)
	else:
		_switch_tab(initial_tab)


func _on_login_succeeded() -> void:
	Online.startup_prompt_dismissed = true
	if _after_login_mode == "pick_game":
		open_game_picker()
	elif _after_login_mode == "profile":
		open_hub("profile")
	elif _after_login_mode == "friends":
		open_hub("friends")
	else:
		# Startup login complete: close cleanly so user sees the main menu with their Online ID ready.
		close_all()


func _stop_active_room_wait() -> void:
	if _matchmaking:
		_cancel_matchmaking()
	if _waiting_challenge:
		_cancel_challenge()
	if _duel_hosting or _duel_joining:
		_duel_hosting = false
		_duel_joining = false
		if Lan.active() and Lan.players() < 2:
			Lan.close()


func close_all() -> void:
	if _invite_panel.visible:
		_on_decline_invite()
		return
	_close_dm_modal()
	_stop_active_room_wait()
	_google_polling = false
	_set_login_busy(false)
	if _mode == "login":
		Online.startup_prompt_dismissed = true
	_mode = ""
	_backdrop.hide()
	_login_panel.hide()
	_picker_panel.hide()
	_hub_panel.hide()


# --- 1. Startup Login Panel ---

func _build_login_panel(parent: Control) -> void:
	_login_panel.theme = DialogTheme.theme()
	_login_panel.add_theme_stylebox_override("panel", _make_box(DialogTheme.BACKGROUND, DialogTheme.CYAN.lerp(DialogTheme.GOLD, 0.55), 14, 2, 12))
	_login_panel.custom_minimum_size = Vector2(540, 0)
	_login_panel.hide()
	parent.add_child(_login_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_login_panel.add_child(v)

	_login_title = Label.new()
	_login_title.text = _t("login_title")
	_login_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_login_title.add_theme_font_override("font", Assets.ui_font(700))
	_login_title.add_theme_font_size_override("font_size", 19)
	_login_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	v.add_child(_login_title)

	var sub := Label.new()
	sub.text = _t("login_sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68))
	v.add_child(sub)

	var google_row := HBoxContainer.new()
	google_row.add_theme_constant_override("separation", 8)
	v.add_child(google_row)

	_google_btn = Button.new()
	_google_btn.text = _t("google_btn")
	_google_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_google_btn.custom_minimum_size = Vector2(0, 38)
	_google_btn.add_theme_font_size_override("font_size", 14)
	_style_accent_button(_google_btn, Color(0.14, 0.36, 0.78, 0.98), Color(0.20, 0.45, 0.90, 1.0), DialogTheme.GOLD)
	_google_btn.pressed.connect(_on_google_pressed)
	google_row.add_child(_google_btn)

	_google_cancel_btn = Button.new()
	_google_cancel_btn.text = _t("google_cancel")
	_google_cancel_btn.custom_minimum_size = Vector2(120, 38)
	_google_cancel_btn.hide()
	_google_cancel_btn.pressed.connect(_cancel_google_login)
	google_row.add_child(_google_cancel_btn)

	var g_note := Label.new()
	g_note.text = _t("google_note")
	g_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g_note.add_theme_font_size_override("font_size", 11)
	g_note.add_theme_color_override("font_color", Color(0.76, 0.72, 0.64))
	v.add_child(g_note)

	v.add_child(HSeparator.new())

	var g_lbl := Label.new()
	g_lbl.text = _t("guest_section")
	g_lbl.add_theme_font_size_override("font_size", 12)
	v.add_child(g_lbl)

	var g_row := HBoxContainer.new()
	g_row.add_theme_constant_override("separation", 8)
	v.add_child(g_row)

	_guest_name_input = LineEdit.new()
	_guest_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guest_name_input.max_length = 24
	_guest_name_input.placeholder_text = _t("guest_hint")
	var lan_cfg: Variant = SaveData.data.get("lan", {})
	if lan_cfg is Dictionary:
		_guest_name_input.text = str((lan_cfg as Dictionary).get("name", ""))
	_style_input(_guest_name_input)
	g_row.add_child(_guest_name_input)

	_guest_btn = Button.new()
	_guest_btn.text = _t("guest_btn")
	_guest_btn.custom_minimum_size = Vector2(146, 34)
	_guest_btn.pressed.connect(_on_guest_pressed)
	g_row.add_child(_guest_btn)

	v.add_child(HSeparator.new())

	var a_lbl := Label.new()
	a_lbl.text = _t("account_section")
	a_lbl.add_theme_font_size_override("font_size", 12)
	v.add_child(a_lbl)

	var cred_row := HBoxContainer.new()
	cred_row.add_theme_constant_override("separation", 8)
	v.add_child(cred_row)

	_user_input = LineEdit.new()
	_user_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_user_input.max_length = 24
	_user_input.placeholder_text = _t("user_hint")
	_style_input(_user_input)
	cred_row.add_child(_user_input)

	_pass_input = LineEdit.new()
	_pass_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass_input.max_length = 72
	_pass_input.secret = true
	_pass_input.placeholder_text = _t("pass_hint")
	_style_input(_pass_input)
	cred_row.add_child(_pass_input)

	_display_row = HBoxContainer.new()
	_display_row.hide()
	v.add_child(_display_row)

	_display_input = LineEdit.new()
	_display_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_display_input.max_length = 24
	_display_input.placeholder_text = _t("disp_hint")
	_style_input(_display_input)
	_display_row.add_child(_display_input)

	var a_btns := HBoxContainer.new()
	a_btns.add_theme_constant_override("separation", 8)
	v.add_child(a_btns)

	_auth_submit_btn = Button.new()
	_auth_submit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_submit_btn.custom_minimum_size = Vector2(0, 34)
	_auth_submit_btn.pressed.connect(_on_account_submit)
	a_btns.add_child(_auth_submit_btn)

	_auth_switch_btn = Button.new()
	_auth_switch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_switch_btn.custom_minimum_size = Vector2(0, 34)
	_auth_switch_btn.pressed.connect(func() -> void:
		_login_register_mode = not _login_register_mode
		_update_login_mode_ui())
	a_btns.add_child(_auth_switch_btn)

	_login_status = Label.new()
	_login_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_status.custom_minimum_size = Vector2(0, 18)
	_login_status.add_theme_font_size_override("font_size", 12)
	v.add_child(_login_status)

	_offline_btn = Button.new()
	_offline_btn.text = _t("offline_btn")
	_offline_btn.custom_minimum_size = Vector2(0, 32)
	_offline_btn.pressed.connect(close_all)
	v.add_child(_offline_btn)

	_update_login_mode_ui()


func _update_login_mode_ui() -> void:
	_display_row.visible = _login_register_mode
	_auth_submit_btn.text = _t("register_btn") if _login_register_mode else _t("login_btn")
	_auth_switch_btn.text = _t("switch_to_login") if _login_register_mode else _t("switch_to_reg")


func _set_login_busy(busy: bool) -> void:
	_busy = busy
	if is_instance_valid(_google_btn):
		_google_btn.disabled = busy
	if is_instance_valid(_guest_btn):
		_guest_btn.disabled = busy
	if is_instance_valid(_auth_submit_btn):
		_auth_submit_btn.disabled = busy
	if is_instance_valid(_auth_switch_btn):
		_auth_switch_btn.disabled = busy
	if is_instance_valid(_google_cancel_btn):
		_google_cancel_btn.visible = _google_polling


func _cancel_google_login() -> void:
	_google_polling = false
	_google_state = ""
	_set_login_busy(false)
	_login_status.text = ""


func _poll_google_once() -> void:
	if not _google_polling or _google_state == "" or _google_poll_ticking:
		return
	_google_poll_ticking = true
	var poll: Dictionary = await Online.poll_google_login(_google_state)
	_google_poll_ticking = false
	if not _google_polling:
		return
	var st: String = str(poll.get("status", ""))
	if st == "done":
		_google_polling = false
		_google_state = ""
		_set_login_busy(false)
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_request_attention()
		_on_login_succeeded()
	elif st == "error" or st == "expired":
		_google_polling = false
		_google_state = ""
		_set_login_busy(false)
		_login_status.text = _t("err_net")
		_login_status.add_theme_color_override("font_color", Color(1.0, 0.52, 0.45))


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		if _google_polling and _google_state != "":
			_poll_google_once()


func _login_error_text(code: String) -> String:
	match code:
		"invalid_credentials": return _t("err_creds")
		"invalid_username": return _t("err_user")
		"invalid_password": return _t("err_pass")
		"username_taken": return _t("err_taken")
		"google_not_configured": return _t("google_unconfigured")
		_: return _t("err_net")


func _on_guest_pressed() -> void:
	if _busy: return
	_set_login_busy(true)
	_login_status.text = _t("connecting")
	_login_status.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	var res: Dictionary = await Online.login_guest(_guest_name_input.text)
	_set_login_busy(false)
	if bool(res.get("ok", false)):
		_on_login_succeeded()
	else:
		_login_status.text = _login_error_text(str(res.get("error", "")))
		_login_status.add_theme_color_override("font_color", Color(1.0, 0.52, 0.45))


func _on_account_submit() -> void:
	if _busy: return
	_set_login_busy(true)
	_login_status.text = _t("connecting")
	_login_status.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	var res: Dictionary
	if _login_register_mode:
		res = await Online.register_account(_user_input.text, _pass_input.text, _display_input.text)
	else:
		res = await Online.login_account(_user_input.text, _pass_input.text)
	_set_login_busy(false)
	if bool(res.get("ok", false)):
		_on_login_succeeded()
	else:
		_login_status.text = _login_error_text(str(res.get("error", "")))
		_login_status.add_theme_color_override("font_color", Color(1.0, 0.52, 0.45))


func _on_google_pressed() -> void:
	if _busy: return
	_set_login_busy(true)
	_login_status.text = _t("connecting")
	_login_status.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	var start: Dictionary = await Online.start_google_login()
	if not bool(start.get("ok", false)):
		_set_login_busy(false)
		_login_status.text = _login_error_text(str(start.get("error", "")))
		_login_status.add_theme_color_override("font_color", Color(1.0, 0.52, 0.45))
		return
	var auth_url: String = str(start.get("authUrl", ""))
	_google_state = str(start.get("state", ""))
	if auth_url == "" or _google_state == "":
		_set_login_busy(false)
		_login_status.text = _t("err_net")
		return
	_google_polling = true
	_set_login_busy(true)
	OS.shell_open(auth_url)
	_login_status.text = _t("google_wait")
	var deadline: int = Time.get_ticks_msec() + 180000
	while _google_polling and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(1.0).timeout
		if not _google_polling:
			break
		await _poll_google_once()
	if _google_polling:
		_google_polling = false
		_google_state = ""
		_set_login_busy(false)


# --- 2. Edition Picker Screen (Yugi / Kaiba / Joey) ---

func _build_picker_panel(parent: Control) -> void:
	_picker_panel.theme = DialogTheme.theme()
	_picker_panel.add_theme_stylebox_override("panel", _make_box(DialogTheme.BACKGROUND, DialogTheme.CYAN.lerp(DialogTheme.GOLD, 0.55), 16, 2, 18))
	_picker_panel.custom_minimum_size = Vector2(760, 0)
	_picker_panel.hide()
	parent.add_child(_picker_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_picker_panel.add_child(v)

	# Top identity & quick links bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)

	_picker_me_label = Label.new()
	_picker_me_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_me_label.add_theme_font_override("font", Assets.ui_font(700))
	_picker_me_label.add_theme_font_size_override("font_size", 15)
	_picker_me_label.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	top.add_child(_picker_me_label)

	_picker_friends_btn = Button.new()
	_picker_friends_btn.text = _t("tab_friends")
	_picker_friends_btn.pressed.connect(func() -> void: open_hub("friends"))
	top.add_child(_picker_friends_btn)

	var prof_btn := Button.new()
	prof_btn.text = _t("tab_profile")
	prof_btn.pressed.connect(func() -> void: open_hub("profile"))
	top.add_child(prof_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 34)
	close_btn.pressed.connect(close_all)
	top.add_child(close_btn)

	var title := Label.new()
	title.text = _t("picker_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Assets.ui_font(700))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", DialogTheme.GOLD)
	v.add_child(title)

	var sub := Label.new()
	sub.text = _t("picker_sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68))
	v.add_child(sub)

	_picker_cards_row = HBoxContainer.new()
	_picker_cards_row.add_theme_constant_override("separation", 12)
	v.add_child(_picker_cards_row)

	_picker_status = Label.new()
	_picker_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_status.add_theme_font_size_override("font_size", 13)
	v.add_child(_picker_status)


func _refresh_picker_cards() -> void:
	var dot: String = "● " if Online.presence_connected else "○ "
	_picker_me_label.text = "%s%s   ·   ID: #%s" % [dot, Online.display_name, Online.player_id]
	var f_txt: String = _t("tab_friends")
	var fr_badge: int = Online.incoming_request_count + Online.total_dm_unread()
	if fr_badge > 0:
		f_txt += " (%d)" % fr_badge
	_picker_friends_btn.text = f_txt
	_picker_status.text = ""

	for c in _picker_cards_row.get_children():
		c.queue_free()

	var accents: Dictionary = {
		"yugi": Color(0.58, 0.34, 0.82),
		"kaiba": Color(0.24, 0.60, 0.88),
		"joey": Color(0.86, 0.54, 0.22)
	}
	for game_id: String in Game.GAMES:
		var installed: bool = Paths.has_game(game_id)
		var accent: Color = accents.get(game_id, DialogTheme.GOLD)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border_col: Color = accent.lightened(0.25) if installed else Color(0.28, 0.34, 0.48, 0.5)
		var bg_col: Color = DialogTheme.SURFACE if installed else Color(0.04, 0.05, 0.11, 0.84)
		card.add_theme_stylebox_override("panel", _make_box(bg_col, border_col, 12, 2, 12))
		_picker_cards_row.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)

		var logo_rect := TextureRect.new()
		logo_rect.custom_minimum_size = Vector2(0, 108)
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if installed:
			logo_rect.texture = TitleArt.logo_texture(game_id)
		else:
			logo_rect.modulate = Color(0.4, 0.4, 0.45, 0.6)
		cv.add_child(logo_rect)

		var name_lbl := Label.new()
		name_lbl.text = _game_name(game_id)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_override("font", Assets.ui_font(700))
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT if installed else Color(0.6, 0.58, 0.62))
		cv.add_child(name_lbl)

		var status_lbl := Label.new()
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 12)
		if installed:
			status_lbl.text = "● %s · %s" % [_t("installed_ready"), _t("deck_info") % _deck_card_count(game_id)]
			status_lbl.add_theme_color_override("font_color", Color(0.45, 0.94, 0.58))
		else:
			status_lbl.text = _t("not_installed")
			status_lbl.add_theme_color_override("font_color", Color(0.70, 0.56, 0.56))
		cv.add_child(status_lbl)

		var enter_btn := Button.new()
		enter_btn.text = _t("enter_online")
		enter_btn.custom_minimum_size = Vector2(0, 40)
		enter_btn.disabled = not installed
		if installed:
			_style_accent_button(enter_btn, accent.darkened(0.28), accent.darkened(0.08), DialogTheme.GOLD)
		enter_btn.pressed.connect(func() -> void: open_hub("duel", game_id))
		cv.add_child(enter_btn)


# --- 3. Complete Edition Online Hub ---

func _build_hub_panel(parent: Control) -> void:
	_hub_panel.theme = DialogTheme.theme()
	_hub_panel.add_theme_stylebox_override("panel", _make_box(DialogTheme.BACKGROUND, DialogTheme.CYAN.lerp(DialogTheme.GOLD, 0.55), 14, 2, 14))
	_hub_panel.custom_minimum_size = Vector2(760, 548)
	_hub_panel.hide()
	parent.add_child(_hub_panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	_hub_panel.add_child(root_v)

	# Top bar: player identity + edition switcher + copy ID + close
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	root_v.add_child(top)

	_hub_me_label = Label.new()
	_hub_me_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hub_me_label.clip_text = true
	_hub_me_label.add_theme_font_override("font", Assets.ui_font(700))
	_hub_me_label.add_theme_font_size_override("font_size", 15)
	_hub_me_label.add_theme_color_override("font_color", DialogTheme.GOLD)
	top.add_child(_hub_me_label)

	# Edition switcher pills (Yugi | Kaiba | Joey)
	for g: String in Game.GAMES:
		var gbtn := Button.new()
		gbtn.text = _game_short(g)
		gbtn.custom_minimum_size = Vector2(64, 32)
		gbtn.pressed.connect(func() -> void: _switch_selected_game(g))
		top.add_child(gbtn)
		_game_switch_btns[g] = gbtn

	_hub_copy_id_btn = Button.new()
	_hub_copy_id_btn.text = _t("copy_id")
	_hub_copy_id_btn.custom_minimum_size = Vector2(92, 32)
	_hub_copy_id_btn.pressed.connect(func() -> void:
		if Online.player_id != "":
			DisplayServer.clipboard_set(Online.player_id)
			_set_hub_status(_t("copied_id") % Online.player_id, Color(0.65, 0.95, 0.65)))
	top.add_child(_hub_copy_id_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 32)
	close_btn.pressed.connect(close_all)
	top.add_child(close_btn)

	# Challenge waiting banner (hidden unless actively challenging someone)
	_challenge_banner = PanelContainer.new()
	_challenge_banner.add_theme_stylebox_override("panel", _make_box(Color(0.16, 0.11, 0.04, 0.96), DialogTheme.GOLD, 8, 2, 8))
	_challenge_banner.hide()
	root_v.add_child(_challenge_banner)
	var ch_row := HBoxContainer.new()
	ch_row.add_theme_constant_override("separation", 8)
	_challenge_banner.add_child(ch_row)
	_challenge_label = Label.new()
	_challenge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_challenge_label.add_theme_font_size_override("font_size", 14)
	_challenge_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	ch_row.add_child(_challenge_label)
	var ch_cancel := Button.new()
	ch_cancel.text = _t("cancel_challenge")
	ch_cancel.pressed.connect(_cancel_challenge)
	ch_row.add_child(ch_cancel)

	# Tabs row (5 tabs: Online Duel | Players | Friends | Global Chat | My Profile)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	root_v.add_child(tabs)

	_tab_duel_btn = Button.new()
	_tab_duel_btn.text = _t("tab_duel")
	_tab_duel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_duel_btn.custom_minimum_size = Vector2(0, 36)
	_tab_duel_btn.pressed.connect(func() -> void: _switch_tab("duel"))
	tabs.add_child(_tab_duel_btn)

	_tab_players_btn = Button.new()
	_tab_players_btn.text = _t("tab_players")
	_tab_players_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_players_btn.custom_minimum_size = Vector2(0, 36)
	_tab_players_btn.pressed.connect(func() -> void: _switch_tab("players"))
	tabs.add_child(_tab_players_btn)

	_tab_friends_btn = Button.new()
	_tab_friends_btn.text = _t("tab_friends")
	_tab_friends_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_friends_btn.custom_minimum_size = Vector2(0, 36)
	_tab_friends_btn.pressed.connect(func() -> void: _switch_tab("friends"))
	tabs.add_child(_tab_friends_btn)

	_tab_chat_btn = Button.new()
	_tab_chat_btn.text = _t("tab_chat")
	_tab_chat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_chat_btn.custom_minimum_size = Vector2(0, 36)
	_tab_chat_btn.pressed.connect(func() -> void: _switch_tab("chat"))
	tabs.add_child(_tab_chat_btn)

	_tab_profile_btn = Button.new()
	_tab_profile_btn.text = _t("tab_profile")
	_tab_profile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_profile_btn.custom_minimum_size = Vector2(0, 36)
	_tab_profile_btn.pressed.connect(func() -> void: _open_profile_by_id(Online.player_id))
	tabs.add_child(_tab_profile_btn)

	_hub_content = VBoxContainer.new()
	_hub_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hub_content.add_theme_constant_override("separation", 8)
	root_v.add_child(_hub_content)

	_hub_status_label = Label.new()
	_hub_status_label.custom_minimum_size = Vector2(0, 22)
	_hub_status_label.add_theme_font_size_override("font_size", 13)
	root_v.add_child(_hub_status_label)


func _switch_selected_game(game_id: String) -> void:
	if not Paths.has_game(game_id):
		_set_hub_status(_t("need_game") % _game_name(game_id), Color(1.0, 0.58, 0.45))
		return
	if _selected_game == game_id:
		return
	_stop_active_room_wait()
	_selected_game = game_id
	_refresh_hub_header()
	if _hub_tab == "duel":
		_switch_tab("duel")


func _refresh_hub_header() -> void:
	var dot: String = "● " if Online.presence_connected else "○ "
	var pool_tag: String = "  ·  " + Online.pool_label(Online.effective_pool())
	_hub_me_label.text = "%s%s  ·  #%s%s" % [dot, Online.display_name, Online.player_id, pool_tag]
	var f_txt: String = _t("tab_friends")
	var fr_badge: int = Online.incoming_request_count + Online.total_dm_unread()
	if fr_badge > 0:
		f_txt += " (%d)" % fr_badge
	_tab_friends_btn.text = f_txt
	for g: String in Game.GAMES:
		var btn: Button = _game_switch_btns.get(g)
		if btn == null:
			continue
		var installed: bool = Paths.has_game(g)
		btn.disabled = not installed
		if g == _selected_game:
			_style_accent_button(btn, Color(0.10, 0.32, 0.54, 0.98), Color(0.14, 0.42, 0.68, 1.0), DialogTheme.CYAN)
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")
			btn.remove_theme_stylebox_override("pressed")
			btn.remove_theme_stylebox_override("disabled")
			btn.remove_theme_color_override("font_color")
	_tab_duel_btn.disabled = _hub_tab == "duel"
	_tab_players_btn.disabled = _hub_tab == "players"
	_tab_friends_btn.disabled = _hub_tab == "friends"
	if is_instance_valid(_tab_chat_btn):
		_tab_chat_btn.disabled = _hub_tab == "chat"


func _set_hub_status(text: String, color := Color(1.0, 0.94, 0.72)) -> void:
	_hub_status_label.text = text
	_hub_status_label.add_theme_color_override("font_color", color)


func _clear_hub_content() -> void:
	for c in _hub_content.get_children():
		c.queue_free()


func _switch_tab(tab: String) -> void:
	if tab != "duel" and (_duel_hosting or _duel_joining or _matchmaking):
		_stop_active_room_wait()
	_hub_tab = tab
	_refresh_hub_header()
	_clear_hub_content()
	if tab == "duel":
		_build_duel_view()
	elif tab == "players":
		_build_players_view()
		_load_players()
	elif tab == "friends":
		_build_friends_view()
		_load_friends()
	elif tab == "chat":
		_build_chat_view()
		_load_global_chat()
	elif tab == "profile":
		_build_profile_view()


# --- Tab 1: Online Duel Room for Selected Edition ---

func _build_duel_view() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hub_content.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	# Selected edition banner + Edit Deck shortcut
	var ed_box := PanelContainer.new()
	ed_box.add_theme_stylebox_override("panel", _make_box(DialogTheme.SURFACE, Color(DialogTheme.CYAN, 0.55), 10, 1, 10))
	body.add_child(ed_box)
	var ed_row := HBoxContainer.new()
	ed_row.add_theme_constant_override("separation", 12)
	ed_box.add_child(ed_row)

	var logo := TextureRect.new()
	logo.custom_minimum_size = Vector2(110, 62)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if Paths.has_game(_selected_game):
		logo.texture = TitleArt.logo_texture(_selected_game)
	ed_row.add_child(logo)

	var ed_info := VBoxContainer.new()
	ed_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed_info.alignment = BoxContainer.ALIGNMENT_CENTER
	ed_row.add_child(ed_info)

	var ed_title := Label.new()
	ed_title.text = _game_name(_selected_game)
	ed_title.add_theme_font_override("font", Assets.ui_font(700))
	ed_title.add_theme_font_size_override("font_size", 17)
	ed_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	ed_info.add_child(ed_title)

	var ed_deck := Label.new()
	ed_deck.text = _t("deck_info") % _deck_card_count(_selected_game)
	ed_deck.add_theme_font_size_override("font_size", 13)
	ed_deck.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	ed_info.add_child(ed_deck)

	var deck_btn := Button.new()
	deck_btn.text = _t("edit_deck")
	deck_btn.custom_minimum_size = Vector2(140, 38)
	deck_btn.pressed.connect(func() -> void:
		if not Paths.has_game(_selected_game):
			return
		var g: String = _selected_game
		close_all()
		open_deck_editor_requested.emit(g))
	ed_row.add_child(deck_btn)

	# Online Server Pool Selector (Competitive vs Deck Testing)
	var pool_card := PanelContainer.new()
	pool_card.add_theme_stylebox_override("panel", _make_box(Color(0.065, 0.085, 0.19, 0.96), Color(DialogTheme.CYAN, 0.65), 10, 1, 10))
	body.add_child(pool_card)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pool_card.add_child(pv)

	var pt := Label.new()
	pt.text = _t("pool_title")
	pt.add_theme_font_override("font", Assets.ui_font(700))
	pt.add_theme_font_size_override("font_size", 14)
	pt.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	pv.add_child(pt)

	var p_btns := HBoxContainer.new()
	p_btns.add_theme_constant_override("separation", 8)
	pv.add_child(p_btns)

	_pool_comp_btn = Button.new()
	_pool_comp_btn.text = _t("pool_competitive")
	_pool_comp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_comp_btn.custom_minimum_size = Vector2(0, 38)
	_pool_comp_btn.pressed.connect(func() -> void: _on_select_online_pool("competitive"))
	p_btns.add_child(_pool_comp_btn)

	_pool_sandbox_btn = Button.new()
	_pool_sandbox_btn.text = _t("pool_sandbox")
	_pool_sandbox_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_sandbox_btn.custom_minimum_size = Vector2(0, 38)
	_pool_sandbox_btn.pressed.connect(func() -> void: _on_select_online_pool("sandbox"))
	p_btns.add_child(_pool_sandbox_btn)

	_pool_info_lbl = Label.new()
	_pool_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pool_info_lbl.add_theme_font_size_override("font_size", 12)
	_pool_info_lbl.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78))
	pv.add_child(_pool_info_lbl)

	_pool_lock_banner = PanelContainer.new()
	_pool_lock_banner.add_theme_stylebox_override("panel", _make_box(Color(0.24, 0.11, 0.30, 0.96), DialogTheme.GOLD, 8, 1, 8))
	var lock_lbl := Label.new()
	lock_lbl.text = _t("pool_locked_banner")
	lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_lbl.add_theme_font_override("font", Assets.ui_font(600))
	lock_lbl.add_theme_font_size_override("font_size", 12)
	lock_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	_pool_lock_banner.add_child(lock_lbl)
	pv.add_child(_pool_lock_banner)

	# Random Online Matchmaking Card
	var mm_card := PanelContainer.new()
	mm_card.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.11, 0.24, 0.96), DialogTheme.GOLD, 10, 2, 12))
	body.add_child(mm_card)
	var mm_v := VBoxContainer.new()
	mm_v.add_theme_constant_override("separation", 6)
	mm_card.add_child(mm_v)

	var mm_top := HBoxContainer.new()
	mm_top.add_theme_constant_override("separation", 10)
	mm_v.add_child(mm_top)

	var mm_info := VBoxContainer.new()
	mm_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mm_top.add_child(mm_info)

	var mm_t := Label.new()
	mm_t.text = _t("mm_title")
	mm_t.add_theme_font_override("font", Assets.ui_font(700))
	mm_t.add_theme_font_size_override("font_size", 16)
	mm_t.add_theme_color_override("font_color", DialogTheme.GOLD)
	mm_info.add_child(mm_t)

	var mm_d := Label.new()
	mm_d.text = _t("mm_desc") % _game_short(_selected_game)
	mm_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mm_d.add_theme_font_size_override("font_size", 12)
	mm_d.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	mm_info.add_child(mm_d)

	_matchmaking_timer_lbl = Label.new()
	_matchmaking_timer_lbl.text = "00:00"
	_matchmaking_timer_lbl.custom_minimum_size = Vector2(78, 0)
	_matchmaking_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_matchmaking_timer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_matchmaking_timer_lbl.add_theme_font_override("font", Assets.ui_font(700))
	_matchmaking_timer_lbl.add_theme_font_size_override("font_size", 22)
	_matchmaking_timer_lbl.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	mm_top.add_child(_matchmaking_timer_lbl)

	var mm_btns := HBoxContainer.new()
	mm_btns.add_theme_constant_override("separation", 8)
	mm_v.add_child(mm_btns)

	_matchmaking_btn = Button.new()
	_matchmaking_btn.text = "%s (%s)" % [_t("mm_start"), _game_short(_selected_game)]
	_matchmaking_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_matchmaking_btn.custom_minimum_size = Vector2(0, 40)
	_style_accent_button(_matchmaking_btn, Color(0.58, 0.34, 0.08, 0.98), Color(0.72, 0.44, 0.12, 1.0), DialogTheme.GOLD)
	_matchmaking_btn.pressed.connect(_start_matchmaking)
	mm_btns.add_child(_matchmaking_btn)

	_matchmaking_cancel_btn = Button.new()
	_matchmaking_cancel_btn.text = _t("mm_cancel")
	_matchmaking_cancel_btn.custom_minimum_size = Vector2(120, 40)
	_matchmaking_cancel_btn.hide()
	_matchmaking_cancel_btn.pressed.connect(_cancel_matchmaking)
	mm_btns.add_child(_matchmaking_cancel_btn)

	_matchmaking_status = Label.new()
	_matchmaking_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_matchmaking_status.add_theme_font_size_override("font_size", 12)
	_matchmaking_status.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62))
	mm_v.add_child(_matchmaking_status)

	# Row of 2 main cards: Host Room & Join Room
	var rooms_row := HBoxContainer.new()
	rooms_row.add_theme_constant_override("separation", 10)
	body.add_child(rooms_row)

	# Host Card
	var host_card := PanelContainer.new()
	host_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_card.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.11, 0.18, 0.95), Color(DialogTheme.CYAN, 0.65), 10, 1, 12))
	rooms_row.add_child(host_card)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 8)
	host_card.add_child(hv)

	var ht := Label.new()
	ht.text = _t("host_title")
	ht.add_theme_font_override("font", Assets.ui_font(700))
	ht.add_theme_font_size_override("font_size", 15)
	ht.add_theme_color_override("font_color", Color(0.65, 0.98, 0.72))
	hv.add_child(ht)

	var hd := Label.new()
	hd.text = _t("host_desc")
	hd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hd.add_theme_font_size_override("font_size", 12)
	hd.add_theme_color_override("font_color", Color(0.84, 0.86, 0.80))
	hv.add_child(hd)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	hv.add_child(code_row)

	_duel_room_code_label = Label.new()
	_duel_room_code_label.text = "------"
	_duel_room_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_duel_room_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel_room_code_label.add_theme_font_override("font", Assets.ui_font(700))
	_duel_room_code_label.add_theme_font_size_override("font_size", 24)
	_duel_room_code_label.add_theme_color_override("font_color", DialogTheme.GOLD)
	code_row.add_child(_duel_room_code_label)

	_duel_copy_code_btn = Button.new()
	_duel_copy_code_btn.text = _t("copy_code")
	_duel_copy_code_btn.disabled = true
	_duel_copy_code_btn.pressed.connect(func() -> void:
		if Lan.room_code != "":
			DisplayServer.clipboard_set(Lan.room_code)
			_set_hub_status(_t("copied_code") % Lan.room_code, Color(0.65, 0.95, 0.65)))
	code_row.add_child(_duel_copy_code_btn)

	var hbtns := HBoxContainer.new()
	hbtns.add_theme_constant_override("separation", 8)
	hv.add_child(hbtns)

	_duel_host_btn = Button.new()
	_duel_host_btn.text = _t("host_btn")
	_duel_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_duel_host_btn.custom_minimum_size = Vector2(0, 38)
	_style_accent_button(_duel_host_btn, Color(0.09, 0.36, 0.42, 0.98), Color(0.13, 0.48, 0.56, 1.0), DialogTheme.GOLD)
	_duel_host_btn.pressed.connect(_on_duel_host_pressed)
	hbtns.add_child(_duel_host_btn)

	_duel_cancel_host_btn = Button.new()
	_duel_cancel_host_btn.text = _t("cancel_room")
	_duel_cancel_host_btn.custom_minimum_size = Vector2(106, 38)
	_duel_cancel_host_btn.hide()
	_duel_cancel_host_btn.pressed.connect(_on_duel_cancel_pressed)
	hbtns.add_child(_duel_cancel_host_btn)

	# Join Card
	var join_card := PanelContainer.new()
	join_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_card.add_theme_stylebox_override("panel", _make_box(DialogTheme.SURFACE, Color(DialogTheme.GOLD, 0.55), 10, 1, 12))
	rooms_row.add_child(join_card)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 8)
	join_card.add_child(jv)

	var jt := Label.new()
	jt.text = _t("join_title")
	jt.add_theme_font_override("font", Assets.ui_font(700))
	jt.add_theme_font_size_override("font_size", 15)
	jt.add_theme_color_override("font_color", DialogTheme.GOLD)
	jv.add_child(jt)

	_duel_join_input = LineEdit.new()
	_duel_join_input.placeholder_text = _t("join_hint")
	_duel_join_input.max_length = 12
	_duel_join_input.text_submitted.connect(func(_s: String) -> void: _on_duel_join_pressed())
	_style_input(_duel_join_input)
	jv.add_child(_duel_join_input)

	_duel_join_btn = Button.new()
	_duel_join_btn.text = _t("join_btn")
	_duel_join_btn.custom_minimum_size = Vector2(0, 38)
	_style_accent_button(_duel_join_btn, Color(0.14, 0.30, 0.64, 0.98), Color(0.20, 0.42, 0.80, 1.0), DialogTheme.CYAN)
	_duel_join_btn.pressed.connect(_on_duel_join_pressed)
	jv.add_child(_duel_join_btn)

	_duel_room_status = Label.new()
	_duel_room_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_duel_room_status.add_theme_font_size_override("font_size", 13)
	_duel_room_status.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	jv.add_child(_duel_room_status)

	# Local Wi-Fi / Direct IP Card
	var wifi_card := PanelContainer.new()
	wifi_card.add_theme_stylebox_override("panel", _make_box(Color(0.055, 0.068, 0.145, 0.94), Color(DialogTheme.CYAN, 0.35), 10, 1, 10))
	body.add_child(wifi_card)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 6)
	wifi_card.add_child(wv)

	var wt := Label.new()
	wt.text = _t("wifi_title")
	wt.add_theme_font_size_override("font_size", 13)
	wt.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68))
	wv.add_child(wt)

	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 8)
	wv.add_child(wrow)

	_duel_ip_input = LineEdit.new()
	_duel_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_duel_ip_input.placeholder_text = _t("ip_hint")
	_style_input(_duel_ip_input)
	wrow.add_child(_duel_ip_input)

	_duel_ip_btn = Button.new()
	_duel_ip_btn.text = _t("ip_btn")
	_duel_ip_btn.pressed.connect(_on_duel_ip_pressed)
	wrow.add_child(_duel_ip_btn)

	if _selected_game == "joey":
		var lan_btn := Button.new()
		lan_btn.text = _t("classic_lan_btn")
		lan_btn.pressed.connect(func() -> void:
			close_all()
			open_classic_lan_requested.emit("joey"))
		wrow.add_child(lan_btn)

	_refresh_pool_selector_ui()


func _refresh_pool_selector_ui() -> void:
	if not is_instance_valid(_pool_comp_btn) or not is_instance_valid(_pool_sandbox_btn):
		return
	var unlocked: bool = Online.all_cards_unlocked
	var active_pool: String = Online.effective_pool()
	_pool_comp_btn.disabled = unlocked
	if active_pool == "competitive" and not unlocked:
		_style_accent_button(_pool_comp_btn, Color(0.11, 0.42, 0.28, 0.98), Color(0.16, 0.54, 0.36, 1.0), DialogTheme.GOLD)
		_style_accent_button(_pool_sandbox_btn, Color(0.10, 0.13, 0.24, 0.90), Color(0.16, 0.20, 0.34, 1.0), Color(DialogTheme.CYAN, 0.45))
	else:
		_style_accent_button(_pool_comp_btn, Color(0.10, 0.13, 0.24, 0.90), Color(0.16, 0.20, 0.34, 1.0), Color(DialogTheme.CYAN, 0.40))
		_style_accent_button(_pool_sandbox_btn, Color(0.36, 0.16, 0.54, 0.98), Color(0.46, 0.22, 0.68, 1.0), DialogTheme.GOLD)
	if is_instance_valid(_pool_info_lbl):
		_pool_info_lbl.text = _t("pool_sandbox_desc") if active_pool == "sandbox" else _t("pool_comp_desc")
	if is_instance_valid(_pool_lock_banner):
		_pool_lock_banner.visible = unlocked
	if is_instance_valid(_matchmaking_btn):
		_matchmaking_btn.text = "%s (%s · %s)" % [_t("mm_start"), _game_short(_selected_game), Online.pool_label(active_pool)]


func _on_select_online_pool(pool: String) -> void:
	if Online.all_cards_unlocked and pool == "competitive":
		_set_hub_status(_t("err_sandbox_only"), Color(1.0, 0.65, 0.40))
		_refresh_pool_selector_ui()
		return
	if Online.effective_pool() == pool:
		return
	_stop_active_room_wait()
	Online.set_online_pool(pool)
	_refresh_hub_header()
	_refresh_pool_selector_ui()
	_set_hub_status(Online.pool_label(Online.effective_pool()), Color(0.65, 0.95, 0.72))


func _on_duel_host_pressed() -> void:
	if not Paths.has_game(_selected_game):
		_set_hub_status(_t("need_game") % _game_name(_selected_game), Color(1.0, 0.52, 0.45))
		return
	_stop_active_room_wait()
	var pname: String = Online.display_name if Online.display_name != "" else "Duelist"
	var err: int = Lan.host_online(Online.server_url, pname, _selected_game, Online.effective_pool())
	if err != OK:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_duel_hosting = true
	_joining_game = _selected_game
	_duel_room_code_label.text = "..."
	_duel_copy_code_btn.disabled = true
	_duel_host_btn.disabled = true
	_duel_cancel_host_btn.show()
	_duel_room_status.text = _t("connecting")
	_set_hub_status(_t("connecting"))


func _on_duel_cancel_pressed() -> void:
	_stop_active_room_wait()
	if is_instance_valid(_duel_room_code_label):
		_duel_room_code_label.text = "------"
	if is_instance_valid(_duel_copy_code_btn):
		_duel_copy_code_btn.disabled = true
	if is_instance_valid(_duel_host_btn):
		_duel_host_btn.disabled = false
	if is_instance_valid(_duel_cancel_host_btn):
		_duel_cancel_host_btn.hide()
	if is_instance_valid(_duel_room_status):
		_duel_room_status.text = ""
	_set_hub_status("")


func _on_duel_join_pressed() -> void:
	if not Paths.has_game(_selected_game):
		_set_hub_status(_t("need_game") % _game_name(_selected_game), Color(1.0, 0.52, 0.45))
		return
	var code: String = Lan.normalize_room_code(_duel_join_input.text)
	if code == "":
		_set_hub_status(_t("bad_code"), Color(1.0, 0.58, 0.45))
		return
	_stop_active_room_wait()
	var pname: String = Online.display_name if Online.display_name != "" else "Duelist"
	var err: int = Lan.join_online(Online.server_url, code, pname, _selected_game, Online.effective_pool())
	if err != OK:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_duel_joining = true
	_joining_game = _selected_game
	_duel_room_status.text = _t("connecting")
	_set_hub_status(_t("connecting"))


func _on_duel_ip_pressed() -> void:
	if not Paths.has_game(_selected_game):
		_set_hub_status(_t("need_game") % _game_name(_selected_game), Color(1.0, 0.52, 0.45))
		return
	var raw: String = _duel_ip_input.text.strip_edges()
	if raw == "":
		_set_hub_status(_t("bad_ip"), Color(1.0, 0.58, 0.45))
		return
	var host_addr: String = raw
	var port: int = Lan.GAME_PORT
	if ":" in raw:
		var parts: PackedStringArray = raw.split(":", false, 1)
		host_addr = parts[0].strip_edges()
		var parsed_port: int = int(parts[1].strip_edges())
		if parsed_port > 0 and parsed_port <= 65535:
			port = parsed_port
	_stop_active_room_wait()
	Lan.local_name = Online.display_name if Online.display_name != "" else "Duelist"
	Lan.game = _selected_game
	if Lan.join(host_addr, port) != OK:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_duel_joining = true
	_joining_game = _selected_game
	_duel_room_status.text = _t("connecting")
	_set_hub_status(_t("connecting"))


# --- Tab 2: Players Directory ---

func _build_players_view() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_hub_content.add_child(bar)

	_search_input = LineEdit.new()
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.placeholder_text = _t("search_hint")
	_search_input.text_submitted.connect(func(_s: String) -> void: _load_players())
	_style_input(_search_input)
	bar.add_child(_search_input)

	var s_btn := Button.new()
	s_btn.text = _t("search_btn")
	s_btn.pressed.connect(_load_players)
	bar.add_child(s_btn)

	var id_btn := Button.new()
	id_btn.text = _t("open_id_btn")
	id_btn.pressed.connect(func() -> void:
		var q: String = _search_input.text.strip_edges().trim_prefix("#")
		if q != "":
			_open_profile_by_id(q))
	bar.add_child(id_btn)

	_online_only_cb = CheckBox.new()
	_online_only_cb.text = _t("online_only")
	_online_only_cb.toggled.connect(func(_v: bool) -> void: _load_players())
	bar.add_child(_online_only_cb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hub_content.add_child(scroll)

	_players_list = VBoxContainer.new()
	_players_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_players_list)


func _load_players() -> void:
	if _players_list == null or not is_instance_valid(_players_list):
		return
	_set_hub_status(_t("connecting"))
	var q: String = _search_input.text.strip_edges() if is_instance_valid(_search_input) else ""
	var online_only: bool = _online_only_cb.button_pressed if is_instance_valid(_online_only_cb) else false
	var res: Dictionary = await Online.fetch_players(q, online_only)
	if _hub_tab != "players" or not is_instance_valid(_players_list):
		return
	for c in _players_list.get_children():
		c.queue_free()
	if not bool(res.get("ok", false)):
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_set_hub_status("")
	var list_val: Variant = res.get("players", [])
	var list: Array = list_val if list_val is Array else []
	_players_cache = list
	if list.is_empty():
		var empty := Label.new()
		empty.text = _t("no_players")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_players_list.add_child(empty)
		return
	for item_val: Variant in list:
		if item_val is Dictionary:
			_players_list.add_child(_make_player_row(item_val as Dictionary))


func _make_player_row(p: Dictionary) -> Control:
	var pid: String = str(p.get("playerId", ""))
	var pname: String = str(p.get("displayName", "Duelist"))
	var is_on: bool = bool(p.get("online", false))
	var fstatus: String = str(p.get("friendStatus", "none"))
	var st_val: Variant = p.get("stats", {})
	var st: Dictionary = st_val if st_val is Dictionary else {}
	var ucards: int = int(st.get("unique_cards", 0))
	var wins: int = int(st.get("wins", 0))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_box(DialogTheme.SURFACE, Color(DialogTheme.CYAN, 0.38), 8, 1, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_color_override("font_color", Color(0.32, 0.95, 0.45) if is_on else Color(0.55, 0.52, 0.58))
	row.add_child(dot)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s   (#%s)" % [pname, pid]
	name_lbl.add_theme_font_override("font", Assets.ui_font(700))
	name_lbl.add_theme_font_size_override("font_size", 15)
	info.add_child(name_lbl)

	var meta := Label.new()
	var sandbox_suffix: String = (" · " + _t("pool_badge_sandbox")) if bool(p.get("allCardsUnlocked", false)) else ""
	meta.text = "%s · %s: %d/%d · %s: %d%s" % [
		_t("online") if is_on else _t("offline"),
		_t("cards_lbl"), ucards, _catalog_total_cards(),
		_t("wins_lbl"), wins,
		sandbox_suffix
	]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.84, 0.78, 0.66))
	info.add_child(meta)

	var prof_btn := Button.new()
	prof_btn.text = _t("view_profile")
	prof_btn.pressed.connect(func() -> void: _open_profile_by_id(pid))
	row.add_child(prof_btn)

	if fstatus == "none":
		var add_btn := Button.new()
		add_btn.text = _t("add_friend")
		add_btn.pressed.connect(func() -> void: _send_friend_request_ui(pid))
		row.add_child(add_btn)
	elif fstatus == "incoming":
		var acc_btn := Button.new()
		acc_btn.text = _t("accept")
		acc_btn.pressed.connect(func() -> void: _respond_request_ui(pid, true))
		row.add_child(acc_btn)
		var rej_btn := Button.new()
		rej_btn.text = _t("reject")
		rej_btn.pressed.connect(func() -> void: _respond_request_ui(pid, false))
		row.add_child(rej_btn)
	elif fstatus == "outgoing":
		var tag := Label.new()
		tag.text = _t("pending_out")
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", DialogTheme.GOLD)
		row.add_child(tag)
	elif fstatus == "friend":
		var dm_btn := Button.new()
		var unread: int = int(Online.dm_unread.get(pid, 0))
		dm_btn.text = "%s (%d)" % [_t("friend_chat_btn"), unread] if unread > 0 else _t("friend_chat_btn")
		_style_accent_button(dm_btn, Color(0.16, 0.28, 0.52, 0.96), Color(0.22, 0.36, 0.65, 1.0), DialogTheme.GOLD)
		dm_btn.pressed.connect(func() -> void: _open_dm_modal(pid, pname, is_on))
		row.add_child(dm_btn)
		if is_on:
			var ch_btn := Button.new()
			ch_btn.text = "%s (%s)" % [_t("challenge"), _game_short(_selected_game)]
			ch_btn.pressed.connect(func() -> void: _start_challenge(pid, pname))
			row.add_child(ch_btn)
		if _hub_tab == "friends":
			var rm_btn := Button.new()
			rm_btn.text = _t("remove_friend")
			rm_btn.pressed.connect(func() -> void: _remove_friend_ui(pid))
			row.add_child(rm_btn)
	if fstatus != "self" and fstatus != "friend" and is_on:
		var ch2 := Button.new()
		ch2.text = "%s (%s)" % [_t("challenge"), _game_short(_selected_game)]
		ch2.pressed.connect(func() -> void: _start_challenge(pid, pname))
		row.add_child(ch2)

	return card


# --- Tab 3: Friends ---

func _build_friends_view() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_hub_content.add_child(bar)

	_friends_search_input = LineEdit.new()
	_friends_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_search_input.placeholder_text = _t("search_hint")
	_friends_search_input.text_submitted.connect(func(_s: String) -> void: _search_in_friends_tab())
	_style_input(_friends_search_input)
	bar.add_child(_friends_search_input)

	var s_btn := Button.new()
	s_btn.text = _t("search_btn")
	_style_accent_button(s_btn, Color(0.14, 0.34, 0.64, 0.98), Color(0.20, 0.44, 0.80, 1.0), DialogTheme.CYAN)
	s_btn.pressed.connect(_search_in_friends_tab)
	bar.add_child(s_btn)

	var add_id_btn := Button.new()
	add_id_btn.text = _t("add_friend")
	_style_accent_button(add_id_btn, Color(0.12, 0.42, 0.26, 0.98), Color(0.16, 0.54, 0.34, 1.0), DialogTheme.GOLD)
	add_id_btn.pressed.connect(_add_friend_by_query_in_friends_tab)
	bar.add_child(add_id_btn)

	var ref_btn := Button.new()
	ref_btn.text = _t("refresh")
	ref_btn.pressed.connect(func() -> void:
		if is_instance_valid(_friends_search_results):
			for c in _friends_search_results.get_children():
				c.queue_free()
		_load_friends())
	bar.add_child(ref_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hub_content.add_child(scroll)

	var scroll_body := VBoxContainer.new()
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_theme_constant_override("separation", 8)
	scroll.add_child(scroll_body)

	_friends_search_results = VBoxContainer.new()
	_friends_search_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_search_results.add_theme_constant_override("separation", 6)
	scroll_body.add_child(_friends_search_results)

	_friends_list = VBoxContainer.new()
	_friends_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_list.add_theme_constant_override("separation", 6)
	scroll_body.add_child(_friends_list)


func _search_in_friends_tab() -> void:
	if not is_instance_valid(_friends_search_input) or not is_instance_valid(_friends_search_results):
		return
	var q: String = _friends_search_input.text.strip_edges().trim_prefix("#")
	for c in _friends_search_results.get_children():
		c.queue_free()
	if q == "":
		_load_friends()
		return
	_set_hub_status(_t("connecting"))
	var res: Dictionary = await Online.fetch_players(q, false)
	if _hub_tab != "friends" or not is_instance_valid(_friends_search_results):
		return
	for c in _friends_search_results.get_children():
		c.queue_free()
	if not bool(res.get("ok", false)):
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_set_hub_status("")
	var list_val: Variant = res.get("players", [])
	var list: Array = list_val if list_val is Array else []
	var hdr := Label.new()
	hdr.text = "%s (%d):" % [_t("search_btn"), list.size()]
	hdr.add_theme_font_override("font", Assets.ui_font(700))
	hdr.add_theme_color_override("font_color", DialogTheme.CYAN)
	_friends_search_results.add_child(hdr)
	if list.is_empty():
		var emp := Label.new()
		emp.text = _t("no_players")
		emp.add_theme_font_size_override("font_size", 13)
		_friends_search_results.add_child(emp)
	else:
		for item_val: Variant in list:
			if item_val is Dictionary:
				_friends_search_results.add_child(_make_player_row(item_val as Dictionary))
	var sep := HSeparator.new()
	_friends_search_results.add_child(sep)


func _add_friend_by_query_in_friends_tab() -> void:
	if not is_instance_valid(_friends_search_input):
		return
	var q: String = _friends_search_input.text.strip_edges().trim_prefix("#")
	if q == "":
		_search_in_friends_tab()
		return
	_set_hub_status(_t("connecting"))
	var direct_res: Dictionary = await Online.send_friend_request(q)
	if bool(direct_res.get("ok", false)):
		var st: String = str(direct_res.get("status", ""))
		_set_hub_status(_t("now_friends") if st == "friend" else _t("req_sent"), Color(0.65, 0.95, 0.65))
		_load_friends()
		return
	# If q was a name instead of an exact ID, search players by name/ID and display results
	await _search_in_friends_tab()


func _load_friends() -> void:
	if _friends_list == null or not is_instance_valid(_friends_list):
		return
	_set_hub_status(_t("connecting"))
	var res: Dictionary = await Online.fetch_friends()
	if _hub_tab != "friends" or not is_instance_valid(_friends_list):
		return
	for c in _friends_list.get_children():
		c.queue_free()
	if not bool(res.get("ok", false)):
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_set_hub_status("")
	_refresh_hub_header()
	var inc_val: Variant = res.get("incoming", [])
	var fr_val: Variant = res.get("friends", [])
	var out_val: Variant = res.get("outgoing", [])
	var inc: Array = inc_val if inc_val is Array else []
	var fr: Array = fr_val if fr_val is Array else []
	var out_req: Array = out_val if out_val is Array else []

	if not inc.is_empty():
		var h1 := Label.new()
		h1.text = _t("incoming_title")
		h1.add_theme_color_override("font_color", DialogTheme.GOLD)
		_friends_list.add_child(h1)
		for item: Variant in inc:
			if item is Dictionary:
				_friends_list.add_child(_make_player_row(item as Dictionary))

	var h2 := Label.new()
	h2.text = _t("friends_title")
	h2.add_theme_color_override("font_color", DialogTheme.GOLD)
	_friends_list.add_child(h2)
	if fr.is_empty():
		var emp := Label.new()
		emp.text = _t("no_friends")
		emp.add_theme_font_size_override("font_size", 13)
		_friends_list.add_child(emp)
	else:
		for item: Variant in fr:
			if item is Dictionary:
				_friends_list.add_child(_make_player_row(item as Dictionary))

	if not out_req.is_empty():
		var h3 := Label.new()
		h3.text = _t("outgoing_title")
		h3.add_theme_color_override("font_color", Color(0.84, 0.78, 0.66))
		_friends_list.add_child(h3)
		for item: Variant in out_req:
			if item is Dictionary:
				_friends_list.add_child(_make_player_row(item as Dictionary))


func _send_friend_request_ui(target_id: String) -> void:
	var res: Dictionary = await Online.send_friend_request(target_id)
	if bool(res.get("ok", false)):
		var st: String = str(res.get("status", ""))
		_set_hub_status(_t("now_friends") if st == "friend" else _t("req_sent"), Color(0.65, 0.95, 0.65))
		if _hub_tab == "players":
			_load_players()
		elif _hub_tab == "friends":
			if is_instance_valid(_friends_search_input) and _friends_search_input.text.strip_edges() != "":
				_search_in_friends_tab()
			_load_friends()
		elif _hub_tab == "profile":
			_open_profile_by_id(target_id)
	else:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))


func _respond_request_ui(from_id: String, accept: bool) -> void:
	var res: Dictionary = await Online.respond_friend_request(from_id, accept)
	if bool(res.get("ok", false)):
		if accept:
			_set_hub_status(_t("now_friends"), Color(0.65, 0.95, 0.65))
		if _hub_tab == "friends":
			if is_instance_valid(_friends_search_input) and _friends_search_input.text.strip_edges() != "":
				_search_in_friends_tab()
			_load_friends()
		elif _hub_tab == "players":
			_load_players()
		elif _hub_tab == "profile":
			_open_profile_by_id(from_id)


func _remove_friend_ui(target_id: String) -> void:
	var res: Dictionary = await Online.remove_friend(target_id)
	if bool(res.get("ok", false)):
		if _hub_tab == "friends":
			if is_instance_valid(_friends_search_input) and _friends_search_input.text.strip_edges() != "":
				_search_in_friends_tab()
			_load_friends()
		elif _hub_tab == "profile":
			_open_profile_by_id(target_id)


# --- Tab 4: Profile & Full Card Collection Showcase ---

func _local_self_profile_snapshot() -> Dictionary:
	var col_out: Dictionary = {}
	var wins_total: int = 0
	var losses_total: int = 0
	var draws_total: int = 0
	var unique_cards: int = 0
	var total_cards: int = 0
	if is_instance_valid(SaveData) and SaveData.data is Dictionary:
		var raw_col: Variant = SaveData.data.get("collection", {})
		if raw_col is Dictionary:
			for k: Variant in (raw_col as Dictionary).keys():
				var id: int = int(k)
				var cnt: int = int((raw_col as Dictionary)[k])
				if id > 0 and cnt > 0:
					col_out[str(id)] = cnt
					unique_cards += 1
					total_cards += cnt
		var raw_stats: Variant = SaveData.data.get("stats", {})
		if raw_stats is Dictionary:
			for g: String in ["yugi", "kaiba", "joey"]:
				var gs: Variant = (raw_stats as Dictionary).get(g, {})
				if gs is Dictionary:
					wins_total += int((gs as Dictionary).get("win", 0))
					losses_total += int((gs as Dictionary).get("lose", 0))
					draws_total += int((gs as Dictionary).get("draw", 0))
	return {
		"playerId": Online.player_id,
		"displayName": Online.display_name if Online.display_name != "" else "Duelist",
		"online": true,
		"friendStatus": "self",
		"collection": col_out,
		"stats": {
			"unique_cards": unique_cards,
			"total_cards": total_cards,
			"wins": wins_total,
			"losses": losses_total,
			"draws": draws_total
		}
	}


func _merge_self_profile_with_local(remote_prof: Dictionary) -> Dictionary:
	var local_snap: Dictionary = _local_self_profile_snapshot()
	var merged: Dictionary = remote_prof.duplicate(true)
	var r_st_val: Variant = merged.get("stats", {})
	var r_st: Dictionary = (r_st_val as Dictionary).duplicate() if r_st_val is Dictionary else {}
	var l_st: Dictionary = local_snap["stats"]
	r_st["wins"] = maxi(int(r_st.get("wins", 0)), int(l_st.get("wins", 0)))
	r_st["losses"] = maxi(int(r_st.get("losses", 0)), int(l_st.get("losses", 0)))
	r_st["draws"] = maxi(int(r_st.get("draws", 0)), int(l_st.get("draws", 0)))
	r_st["unique_cards"] = maxi(int(r_st.get("unique_cards", 0)), int(l_st.get("unique_cards", 0)))
	r_st["total_cards"] = maxi(int(r_st.get("total_cards", 0)), int(l_st.get("total_cards", 0)))
	merged["stats"] = r_st
	var r_col_val: Variant = merged.get("collection", {})
	var r_col: Dictionary = (r_col_val as Dictionary).duplicate() if r_col_val is Dictionary else {}
	var l_col: Dictionary = local_snap["collection"]
	for k: String in l_col.keys():
		r_col[k] = maxi(int(r_col.get(k, 0)), int(l_col[k]))
	merged["collection"] = r_col
	return merged


func _open_profile_by_id(target_id: String) -> void:
	var is_self_target: bool = target_id == "" or target_id == Online.player_id
	if is_self_target:
		_viewing_profile = _local_self_profile_snapshot()
		_profile_filter = "all"
		_profile_page = 0
		_switch_tab("profile")
		Online.sync_collection_now()
	_set_hub_status(_t("connecting"))
	var res: Dictionary = await Online.fetch_player_profile(target_id if target_id != "" else Online.player_id)
	if not bool(res.get("ok", false)):
		if is_self_target:
			_set_hub_status("")
			return
		var err_code: String = str(res.get("error", ""))
		_set_hub_status(_t("not_found_id") if err_code == "player_not_found" else _t("err_net"), Color(1.0, 0.52, 0.45))
		return
	var p_val: Variant = res.get("player", {})
	if not (p_val is Dictionary):
		return
	var fetched: Dictionary = p_val as Dictionary
	if is_self_target or str(fetched.get("playerId", "")) == Online.player_id:
		_viewing_profile = _merge_self_profile_with_local(fetched)
	else:
		_viewing_profile = fetched
		_profile_filter = "all"
		_profile_page = 0
	_set_hub_status("")
	if _hub_tab == "profile":
		_render_profile_contents()
	else:
		_switch_tab("profile")


func _build_profile_view() -> void:
	if _viewing_profile.is_empty() or str(_viewing_profile.get("playerId", Online.player_id)) == Online.player_id:
		_viewing_profile = _merge_self_profile_with_local(_viewing_profile)
	_profile_container = VBoxContainer.new()
	_profile_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_profile_container.add_theme_constant_override("separation", 8)
	_hub_content.add_child(_profile_container)
	_render_profile_contents()


func _catalog_total_cards() -> int:
	if is_instance_valid(CardDB) and CardDB.cards.size() >= 1400:
		return CardDB.cards.size()
	return 1400


func _classify_collection(col: Dictionary) -> Dictionary:
	var counts: Dictionary = {
		"total_copies": 0, "unique": 0,
		"normal": 0, "effect": 0, "fusion": 0, "ritual": 0, "spell": 0, "trap": 0
	}
	for k: Variant in col.keys():
		var id: int = int(str(k))
		var copies: int = int(col[k])
		if id <= 0 or copies <= 0:
			continue
		counts["total_copies"] = int(counts["total_copies"]) + copies
		counts["unique"] = int(counts["unique"]) + 1
		var card: Dictionary = CardDB.by_id(id)
		if card.is_empty():
			continue
		match CardDB.group_of(card):
			CardDB.Group.NORMAL: counts["normal"] = int(counts["normal"]) + 1
			CardDB.Group.EFFECT: counts["effect"] = int(counts["effect"]) + 1
			CardDB.Group.FUSION: counts["fusion"] = int(counts["fusion"]) + 1
			CardDB.Group.RITUAL: counts["ritual"] = int(counts["ritual"]) + 1
			CardDB.Group.SPELL: counts["spell"] = int(counts["spell"]) + 1
			CardDB.Group.TRAP: counts["trap"] = int(counts["trap"]) + 1
	return counts


func _filter_card_ids(col: Dictionary, flt: String) -> Array[int]:
	var ids: Array[int] = []
	for k: Variant in col.keys():
		var id: int = int(str(k))
		if id <= 0 or int(col[k]) <= 0:
			continue
		if flt != "all":
			var card: Dictionary = CardDB.by_id(id)
			if card.is_empty():
				continue
			var grp: int = CardDB.group_of(card)
			if flt == "normal" and grp != CardDB.Group.NORMAL: continue
			if flt == "effect" and grp != CardDB.Group.EFFECT: continue
			if flt == "fusion" and grp != CardDB.Group.FUSION: continue
			if flt == "ritual" and grp != CardDB.Group.RITUAL: continue
			if flt == "spell" and grp != CardDB.Group.SPELL: continue
			if flt == "trap" and grp != CardDB.Group.TRAP: continue
		ids.append(id)
	ids.sort()
	return ids


func _render_profile_contents() -> void:
	if _profile_container == null or not is_instance_valid(_profile_container):
		return
	for c in _profile_container.get_children():
		c.queue_free()
	var p: Dictionary = _viewing_profile
	var pid: String = str(p.get("playerId", Online.player_id))
	var pname: String = str(p.get("displayName", Online.display_name))
	var is_self: bool = pid == Online.player_id
	var is_on: bool = bool(p.get("online", is_self))
	var fstatus: String = str(p.get("friendStatus", "self" if is_self else "none"))
	var st_val: Variant = p.get("stats", {})
	var st: Dictionary = st_val if st_val is Dictionary else {}
	var col_val: Variant = p.get("collection", {})
	var col: Dictionary = col_val if col_val is Dictionary else {}
	var breakdown: Dictionary = _classify_collection(col)

	var hdr_box := PanelContainer.new()
	hdr_box.add_theme_stylebox_override("panel", _make_box(DialogTheme.SURFACE, Color(DialogTheme.CYAN, 0.45), 10, 1, 10))
	_profile_container.add_child(hdr_box)
	var hdr_v := VBoxContainer.new()
	hdr_v.add_theme_constant_override("separation", 6)
	hdr_box.add_child(hdr_v)

	var top_r := HBoxContainer.new()
	top_r.add_theme_constant_override("separation", 6)
	hdr_v.add_child(top_r)

	var title_lbl := Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.text = "%s %s  ·  ID: #%s  ·  %s: %d  ·  %s: %d" % [
		"●" if is_on else "○", pname, pid,
		_t("wins_lbl"), int(st.get("wins", 0)),
		_t("losses_lbl"), int(st.get("losses", 0))
	]
	title_lbl.add_theme_font_override("font", Assets.ui_font(700))
	title_lbl.add_theme_font_size_override("font_size", 15)
	top_r.add_child(title_lbl)

	var cp_btn := Button.new()
	cp_btn.text = _t("copy_id")
	cp_btn.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(pid)
		_set_hub_status(_t("copied_id") % pid, Color(0.65, 0.95, 0.65)))
	top_r.add_child(cp_btn)

	if is_self:
		var sync_btn := Button.new()
		sync_btn.text = _t("sync_now")
		sync_btn.pressed.connect(func() -> void:
			_set_hub_status(_t("connecting"))
			var r: Dictionary = await Online.sync_collection_now()
			if bool(r.get("ok", false)):
				_set_hub_status(_t("synced_ok"), Color(0.65, 0.95, 0.65))
				_open_profile_by_id(Online.player_id))
		top_r.add_child(sync_btn)

		var out_btn := Button.new()
		out_btn.text = _t("logout_btn")
		out_btn.pressed.connect(func() -> void:
			Online.logout()
			open_login(""))
		top_r.add_child(out_btn)
	else:
		if fstatus == "none":
			var af := Button.new()
			af.text = _t("add_friend")
			af.pressed.connect(func() -> void: _send_friend_request_ui(pid))
			top_r.add_child(af)
		elif fstatus == "incoming":
			var ac := Button.new()
			ac.text = _t("accept")
			ac.pressed.connect(func() -> void: _respond_request_ui(pid, true))
			top_r.add_child(ac)
		elif fstatus == "friend":
			var dm_pbtn := Button.new()
			dm_pbtn.text = _t("friend_chat_btn")
			dm_pbtn.pressed.connect(func() -> void: _open_dm_modal(pid, pname, is_on))
			top_r.add_child(dm_pbtn)
			var rm := Button.new()
			rm.text = _t("remove_friend")
			rm.pressed.connect(func() -> void: _remove_friend_ui(pid))
			top_r.add_child(rm)
		if is_on:
			var ch := Button.new()
			ch.text = "%s (%s)" % [_t("challenge"), _game_short(_selected_game)]
			ch.pressed.connect(func() -> void: _start_challenge(pid, pname))
			top_r.add_child(ch)

	var sum_lbl := Label.new()
	sum_lbl.text = "%s: %d/%d  |  %s: %d  |  %s: %d  ·  %s: %d  ·  %s: %d  ·  %s: %d  ·  %s: %d  ·  %s: %d" % [
		_t("unique_cards"), int(breakdown["unique"]), _catalog_total_cards(),
		_t("total_copies"), int(breakdown["total_copies"]),
		_t("f_normal"), int(breakdown["normal"]),
		_t("f_effect"), int(breakdown["effect"]),
		_t("f_fusion"), int(breakdown["fusion"]),
		_t("f_ritual"), int(breakdown["ritual"]),
		_t("f_spell"), int(breakdown["spell"]),
		_t("f_trap"), int(breakdown["trap"])
	]
	sum_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sum_lbl.add_theme_font_size_override("font_size", 12)
	sum_lbl.add_theme_color_override("font_color", Color(0.95, 0.87, 0.65))
	hdr_v.add_child(sum_lbl)

	if is_self:
		var rn_row := HBoxContainer.new()
		rn_row.add_theme_constant_override("separation", 6)
		hdr_v.add_child(rn_row)
		var rn_edit := LineEdit.new()
		rn_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rn_edit.max_length = 24
		rn_edit.text = pname
		_style_input(rn_edit)
		rn_row.add_child(rn_edit)
		var rn_btn := Button.new()
		rn_btn.text = _t("rename_btn")
		rn_btn.pressed.connect(func() -> void:
			var nv: String = rn_edit.text.strip_edges()
			if nv.length() < 2:
				return
			var rr: Dictionary = await Online.update_display_name(nv)
			if bool(rr.get("ok", false)):
				_open_profile_by_id(Online.player_id))
		rn_row.add_child(rn_btn)

	var flt_row := HBoxContainer.new()
	flt_row.add_theme_constant_override("separation", 5)
	_profile_container.add_child(flt_row)
	var filters: Array[Array] = [
		["all", _t("f_all")], ["normal", _t("f_normal")], ["effect", _t("f_effect")],
		["fusion", _t("f_fusion")], ["ritual", _t("f_ritual")], ["spell", _t("f_spell")], ["trap", _t("f_trap")]
	]
	for pair: Array in filters:
		var fkey: String = str(pair[0])
		var b := Button.new()
		b.text = str(pair[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = _profile_filter == fkey
		b.pressed.connect(func() -> void:
			_profile_filter = fkey
			_profile_page = 0
			_render_profile_contents())
		flt_row.add_child(b)

	_profile_card_ids = _filter_card_ids(col, _profile_filter)
	var total_pages: int = maxi(1, int(ceil(float(_profile_card_ids.size()) / float(CARDS_PER_PAGE))))
	_profile_page = clampi(_profile_page, 0, total_pages - 1)
	var start_idx: int = _profile_page * CARDS_PER_PAGE
	var end_idx: int = mini(start_idx + CARDS_PER_PAGE, _profile_card_ids.size())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_profile_container.add_child(scroll)

	if _profile_card_ids.is_empty():
		var emp := Label.new()
		emp.text = _t("no_cards_yet")
		emp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scroll.add_child(emp)
	else:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(grid)
		for i in range(start_idx, end_idx):
			var cid: int = _profile_card_ids[i]
			var copies: int = int(col.get(str(cid), 1))
			grid.add_child(_make_card_tile(cid, copies))

	if total_pages > 1:
		var pager := HBoxContainer.new()
		pager.alignment = BoxContainer.ALIGNMENT_CENTER
		pager.add_theme_constant_override("separation", 12)
		_profile_container.add_child(pager)
		var prev := Button.new()
		prev.text = _t("prev_page")
		prev.disabled = _profile_page <= 0
		prev.pressed.connect(func() -> void:
			_profile_page -= 1
			_render_profile_contents())
		pager.add_child(prev)
		var pg_lbl := Label.new()
		pg_lbl.text = "%d / %d" % [_profile_page + 1, total_pages]
		pager.add_child(pg_lbl)
		var nxt := Button.new()
		nxt.text = _t("next_page")
		nxt.disabled = _profile_page + 1 >= total_pages
		nxt.pressed.connect(func() -> void:
			_profile_page += 1
			_render_profile_contents())
		pager.add_child(nxt)


func _make_card_tile(card_id: int, copies: int) -> Control:
	var card: Dictionary = CardDB.by_id(card_id)
	var cname: String = CardDB.name_of(card_id)
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col: Color = Color(DialogTheme.GOLD, 0.35)
	if not card.is_empty():
		match CardDB.group_of(card):
			CardDB.Group.SPELL: border_col = Color(0.25, 0.80, 0.55, 0.65)
			CardDB.Group.TRAP: border_col = Color(0.85, 0.35, 0.65, 0.65)
			CardDB.Group.FUSION: border_col = Color(0.65, 0.42, 0.92, 0.70)
			CardDB.Group.RITUAL: border_col = Color(0.35, 0.65, 0.95, 0.70)
			CardDB.Group.EFFECT: border_col = Color(0.92, 0.55, 0.25, 0.65)
	tile.add_theme_stylebox_override("panel", _make_box(Color(0.055, 0.068, 0.145, 0.95), border_col, 7, 1, 6))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	tile.add_child(h)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(36, 50)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if is_instance_valid(CardDB):
		thumb.texture = CardDB.card_texture(card_id, true)
	h.add_child(thumb)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)

	var nl := Label.new()
	nl.text = cname
	nl.clip_text = true
	nl.add_theme_font_override("font", Assets.ui_font(700))
	nl.add_theme_font_size_override("font_size", 12)
	v.add_child(nl)

	var sub_txt := "×%d" % copies
	if not card.is_empty():
		var cat: String = str(card.get("category", "monster"))
		if cat == "monster":
			var atk: int = int(card.get("atk", 0))
			var def_v: int = int(card.get("def", 0))
			var tname: String = CardDB.type_name(int(card.get("type_id", 0)))
			sub_txt = "%s · %d/%d · ×%d" % [tname, atk, def_v, copies]
		elif cat == "spell":
			sub_txt = "%s · ×%d" % [_t("f_spell"), copies]
		else:
			sub_txt = "%s · ×%d" % [_t("f_trap"), copies]
	var sl := Label.new()
	sl.text = sub_txt
	sl.clip_text = true
	sl.add_theme_font_size_override("font_size", 11)
	sl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.66))
	v.add_child(sl)

	return tile


# --- Matchmaking Handlers ---

func _start_matchmaking() -> void:
	if not Paths.has_game(_selected_game):
		_set_hub_status(_t("need_game") % _game_name(_selected_game), Color(1.0, 0.52, 0.45))
		return
	_stop_active_room_wait()
	if not Online.start_matchmaking(_selected_game, Online.effective_pool()):
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_matchmaking = true
	_matchmaking_elapsed = 0.0
	_matchmaking_game = _selected_game
	if is_instance_valid(_matchmaking_timer_lbl):
		_matchmaking_timer_lbl.text = "00:00"
	if is_instance_valid(_matchmaking_btn):
		_matchmaking_btn.disabled = true
	if is_instance_valid(_matchmaking_cancel_btn):
		_matchmaking_cancel_btn.show()
	if is_instance_valid(_matchmaking_status):
		_matchmaking_status.text = _t("connecting")
	_set_hub_status(_t("connecting"))


func _cancel_matchmaking() -> void:
	_matchmaking = false
	_matchmaking_elapsed = 0.0
	Online.cancel_matchmaking()
	if is_instance_valid(_matchmaking_timer_lbl):
		_matchmaking_timer_lbl.text = "00:00"
	if is_instance_valid(_matchmaking_btn):
		_matchmaking_btn.disabled = false
	if is_instance_valid(_matchmaking_cancel_btn):
		_matchmaking_cancel_btn.hide()
	if is_instance_valid(_matchmaking_status):
		_matchmaking_status.text = ""
	_set_hub_status("")


func _on_matchmaking_queued(game_id: String, queue_size: int) -> void:
	if not _matchmaking or game_id != _matchmaking_game:
		return
	var msg: String = "%s · %s" % [_t("mm_searching") % [_game_short(game_id), queue_size], Online.pool_label(Online.effective_pool())]
	if is_instance_valid(_matchmaking_status):
		_matchmaking_status.text = msg
	_set_hub_status(msg)


func _on_matchmaking_found(game_id: String, room_code: String, is_host: bool, opp_id: String, opp_name: String) -> void:
	_matchmaking = false
	_matchmaking_elapsed = 0.0
	if is_instance_valid(_matchmaking_timer_lbl):
		_matchmaking_timer_lbl.text = "00:00"
	if is_instance_valid(_matchmaking_btn):
		_matchmaking_btn.disabled = false
	if is_instance_valid(_matchmaking_cancel_btn):
		_matchmaking_cancel_btn.hide()
	var mg: String = game_id if game_id in Game.GAMES else _selected_game
	var found_msg: String = _t("mm_found") % [opp_name, opp_id]
	if is_instance_valid(_matchmaking_status):
		_matchmaking_status.text = found_msg
	_set_hub_status(found_msg, Color(0.65, 0.95, 0.65))
	if Online.join_matchmaking_room(room_code, is_host, mg, Online.effective_pool()) != OK:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_duel_joining = true
	_joining_game = mg


func _on_matchmaking_left() -> void:
	if not _matchmaking:
		return
	_matchmaking = false
	_matchmaking_elapsed = 0.0
	if is_instance_valid(_matchmaking_timer_lbl):
		_matchmaking_timer_lbl.text = "00:00"
	if is_instance_valid(_matchmaking_btn):
		_matchmaking_btn.disabled = false
	if is_instance_valid(_matchmaking_cancel_btn):
		_matchmaking_cancel_btn.hide()
	if is_instance_valid(_matchmaking_status):
		_matchmaking_status.text = ""


func _on_matchmaking_error_received(code: String) -> void:
	_cancel_matchmaking()
	if code == "unlocked_account_sandbox_only":
		_refresh_hub_header()
		_refresh_pool_selector_ui()
		_set_hub_status(_t("err_sandbox_only"), Color(1.0, 0.62, 0.40))
	else:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))


# --- Tab 5: Global World Chat & Private Friend DM Modal ---

func _build_chat_view() -> void:
	_global_chat_scroll = ScrollContainer.new()
	_global_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_global_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hub_content.add_child(_global_chat_scroll)

	_global_chat_list = VBoxContainer.new()
	_global_chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_global_chat_list.add_theme_constant_override("separation", 6)
	_global_chat_scroll.add_child(_global_chat_list)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	_hub_content.add_child(bar)

	_global_chat_input = LineEdit.new()
	_global_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_global_chat_input.max_length = 400
	_global_chat_input.placeholder_text = _t("chat_hint")
	_global_chat_input.text_submitted.connect(func(_s: String) -> void: _on_send_global_chat())
	_style_input(_global_chat_input)
	bar.add_child(_global_chat_input)

	_global_chat_send_btn = Button.new()
	_global_chat_send_btn.text = _t("chat_send")
	_global_chat_send_btn.custom_minimum_size = Vector2(108, 38)
	_style_accent_button(_global_chat_send_btn, Color(0.14, 0.38, 0.68, 0.98), Color(0.20, 0.48, 0.82, 1.0), DialogTheme.GOLD)
	_global_chat_send_btn.pressed.connect(_on_send_global_chat)
	bar.add_child(_global_chat_send_btn)


func _load_global_chat() -> void:
	if _global_chat_list == null or not is_instance_valid(_global_chat_list):
		return
	_set_hub_status(_t("connecting"))
	var res: Dictionary = await Online.fetch_global_chat()
	if _hub_tab != "chat" or not is_instance_valid(_global_chat_list):
		return
	for c in _global_chat_list.get_children():
		c.queue_free()
	if not bool(res.get("ok", false)):
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_set_hub_status("")
	_global_chat_messages.clear()
	var msgs_val: Variant = res.get("messages", [])
	var msgs: Array = msgs_val if msgs_val is Array else []
	if msgs.is_empty():
		var emp := Label.new()
		emp.text = _t("chat_empty")
		emp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emp.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62))
		_global_chat_list.add_child(emp)
		return
	for m_val: Variant in msgs:
		if m_val is Dictionary:
			var msg: Dictionary = m_val as Dictionary
			_global_chat_messages.append(msg)
			_global_chat_list.add_child(_make_chat_bubble(msg, true))
	_scroll_to_bottom.call_deferred(_global_chat_scroll)


func _scroll_to_bottom(scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll):
		return
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	if vbar != null:
		scroll.scroll_vertical = int(vbar.max_value)


func _format_chat_time(ts_val: Variant) -> String:
	if ts_val is int or ts_val is float:
		var unix_sec: int = int(float(ts_val) / 1000.0)
		if unix_sec > 0:
			var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix_sec)
			return "%02d:%02d" % [int(d.get("hour", 0)), int(d.get("minute", 0))]
	var iso_ts: String = str(ts_val)
	if iso_ts.is_valid_int():
		var unix_sec2: int = int(int(iso_ts) / 1000)
		if unix_sec2 > 0:
			var d2: Dictionary = Time.get_datetime_dict_from_unix_time(unix_sec2)
			return "%02d:%02d" % [int(d2.get("hour", 0)), int(d2.get("minute", 0))]
	var t_idx: int = iso_ts.find("T")
	if t_idx >= 0 and iso_ts.length() >= t_idx + 6:
		return iso_ts.substr(t_idx + 1, 5)
	return ""


func _make_chat_bubble(msg: Dictionary, clickable_profile: bool) -> Control:
	var from_id: String = str(msg.get("fromId", msg.get("senderId", "")))
	var from_name: String = str(msg.get("senderName", msg.get("fromName", "Duelist")))
	var body: String = str(msg.get("body", ""))
	var ts_txt: String = _format_chat_time(msg.get("createdAt", 0))
	var is_self: bool = from_id == Online.player_id

	var card := PanelContainer.new()
	var bg_col: Color = Color(0.08, 0.16, 0.24, 0.95) if is_self else Color(0.06, 0.075, 0.155, 0.95)
	var bdr_col: Color = Color(DialogTheme.GOLD, 0.55) if is_self else Color(DialogTheme.CYAN, 0.4)
	card.add_theme_stylebox_override("panel", _make_box(bg_col, bdr_col, 8, 1, 8))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)

	if clickable_profile and not is_self and from_id != "":
		var who_btn := Button.new()
		who_btn.flat = true
		who_btn.text = "%s (#%s)" % [from_name, from_id]
		who_btn.add_theme_font_override("font", Assets.ui_font(700))
		who_btn.add_theme_font_size_override("font_size", 12)
		who_btn.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
		who_btn.pressed.connect(func() -> void: _open_profile_by_id(from_id))
		top.add_child(who_btn)
	else:
		var who_lbl := Label.new()
		who_lbl.text = "%s (#%s)" % [from_name, from_id]
		who_lbl.add_theme_font_override("font", Assets.ui_font(700))
		who_lbl.add_theme_font_size_override("font_size", 12)
		who_lbl.add_theme_color_override("font_color", Color(0.62, 0.96, 0.68) if is_self else DialogTheme.GOLD_LIGHT)
		top.add_child(who_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	if ts_txt != "":
		var tl := Label.new()
		tl.text = ts_txt
		tl.add_theme_font_size_override("font_size", 11)
		tl.add_theme_color_override("font_color", Color(0.68, 0.65, 0.58))
		top.add_child(tl)

	var bl := Label.new()
	bl.text = body
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.add_theme_font_size_override("font_size", 13)
	bl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	v.add_child(bl)
	return card


func _on_send_global_chat() -> void:
	if not is_instance_valid(_global_chat_input):
		return
	var text: String = _global_chat_input.text.strip_edges()
	if text == "":
		return
	if not Online.send_global_chat(text):
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_global_chat_input.text = ""


func _on_global_chat_received(msg: Dictionary) -> void:
	_global_chat_messages.append(msg)
	if _global_chat_messages.size() > 100:
		_global_chat_messages.remove_at(0)
	if _mode == "hub" and _hub_tab == "chat" and is_instance_valid(_global_chat_list):
		if _global_chat_messages.size() == 1:
			for c in _global_chat_list.get_children():
				if c is Label:
					c.queue_free()
		_global_chat_list.add_child(_make_chat_bubble(msg, true))
		_scroll_to_bottom.call_deferred(_global_chat_scroll)


func _build_dm_panel() -> void:
	_dm_panel.theme = DialogTheme.theme()
	_dm_panel.add_theme_stylebox_override("panel", _make_box(DialogTheme.BACKGROUND, DialogTheme.CYAN.lerp(DialogTheme.GOLD, 0.5), 12, 2, 14))
	_dm_panel.custom_minimum_size = Vector2(500, 420)
	_dm_panel.hide()
	add_child(_dm_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_dm_panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)

	_dm_title_lbl = Label.new()
	_dm_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dm_title_lbl.clip_text = true
	_dm_title_lbl.add_theme_font_override("font", Assets.ui_font(700))
	_dm_title_lbl.add_theme_font_size_override("font_size", 15)
	_dm_title_lbl.add_theme_color_override("font_color", DialogTheme.GOLD)
	top.add_child(_dm_title_lbl)

	_dm_challenge_btn = Button.new()
	_dm_challenge_btn.text = _t("challenge")
	_dm_challenge_btn.pressed.connect(func() -> void:
		var tid: String = _dm_friend_id
		var tname: String = _dm_friend_name
		_close_dm_modal()
		if tid != "":
			_start_challenge(tid, tname))
	top.add_child(_dm_challenge_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(34, 30)
	close_btn.pressed.connect(_close_dm_modal)
	top.add_child(close_btn)

	_dm_scroll = ScrollContainer.new()
	_dm_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dm_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_dm_scroll)

	_dm_list = VBoxContainer.new()
	_dm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dm_list.add_theme_constant_override("separation", 6)
	_dm_scroll.add_child(_dm_list)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	v.add_child(bar)

	_dm_input = LineEdit.new()
	_dm_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dm_input.max_length = 400
	_dm_input.placeholder_text = _t("dm_hint")
	_dm_input.text_submitted.connect(func(_s: String) -> void: _on_send_dm())
	_style_input(_dm_input)
	bar.add_child(_dm_input)

	_dm_send_btn = Button.new()
	_dm_send_btn.text = _t("chat_send")
	_dm_send_btn.custom_minimum_size = Vector2(96, 36)
	_style_accent_button(_dm_send_btn, Color(0.14, 0.38, 0.68, 0.98), Color(0.20, 0.48, 0.82, 1.0), DialogTheme.GOLD)
	_dm_send_btn.pressed.connect(_on_send_dm)
	bar.add_child(_dm_send_btn)


func _open_dm_modal(pid: String, pname: String, is_on: bool) -> void:
	_dm_friend_id = pid
	_dm_friend_name = pname
	_dm_friend_online = is_on
	Online.active_dm_friend_id = pid
	Online.mark_dm_read(pid)
	_refresh_hub_header()
	_dm_title_lbl.text = "%s %s" % ["●" if is_on else "○", _t("dm_title") % [pname, pid]]
	_dm_challenge_btn.visible = is_on
	_dm_challenge_btn.text = "%s (%s)" % [_t("challenge"), _game_short(_selected_game)]
	for c in _dm_list.get_children():
		c.queue_free()
	var loading := Label.new()
	loading.text = _t("connecting")
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dm_list.add_child(loading)
	var vp: Rect2 = get_viewport().get_visible_rect()
	_dm_panel.show()
	_dm_panel.position = vp.get_center() - _dm_panel.size * 0.5
	var res: Dictionary = await Online.fetch_dm_history(pid)
	if not _dm_panel.visible or _dm_friend_id != pid:
		return
	for c in _dm_list.get_children():
		c.queue_free()
	if not bool(res.get("ok", false)):
		var err_l := Label.new()
		err_l.text = _t("err_net")
		err_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dm_list.add_child(err_l)
		return
	var msgs_val: Variant = res.get("messages", [])
	var msgs: Array = msgs_val if msgs_val is Array else []
	if msgs.is_empty():
		var emp := Label.new()
		emp.text = _t("dm_empty")
		emp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emp.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62))
		_dm_list.add_child(emp)
	else:
		for m_val: Variant in msgs:
			if m_val is Dictionary:
				_dm_list.add_child(_make_chat_bubble(m_val as Dictionary, false))
		_scroll_to_bottom.call_deferred(_dm_scroll)
	_dm_input.grab_focus()


func _close_dm_modal() -> void:
	_dm_friend_id = ""
	Online.active_dm_friend_id = ""
	if is_instance_valid(_dm_panel):
		_dm_panel.hide()


func _on_send_dm() -> void:
	if _dm_friend_id == "" or not is_instance_valid(_dm_input):
		return
	var text: String = _dm_input.text.strip_edges()
	if text == "":
		return
	if not Online.send_dm(_dm_friend_id, text):
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_dm_input.text = ""


func _on_dm_received(msg: Dictionary) -> void:
	var from_id: String = str(msg.get("fromId", ""))
	var to_id: String = str(msg.get("toId", ""))
	_refresh_hub_header()
	if _mode == "pick_game":
		_refresh_picker_cards()
	if _dm_panel.visible and (from_id == _dm_friend_id or to_id == _dm_friend_id):
		for c in _dm_list.get_children():
			if c is Label:
				c.queue_free()
		_dm_list.add_child(_make_chat_bubble(msg, false))
		Online.mark_dm_read(_dm_friend_id)
		_refresh_hub_header()
		_scroll_to_bottom.call_deferred(_dm_scroll)
	elif _mode == "hub" and _hub_tab == "friends":
		_load_friends()


func _on_chat_error_received(code: String) -> void:
	var msg: String = _t("rate_limited") if code == "rate_limited" else _t("err_net")
	_set_hub_status(msg, Color(1.0, 0.58, 0.45))


# --- 4. Direct Challenge & Live Invite Modal ---

func _build_invite_panel() -> void:
	_invite_panel.theme = DialogTheme.theme()
	_invite_panel.add_theme_stylebox_override("panel", _make_box(DialogTheme.BACKGROUND, DialogTheme.GOLD, 12, 2, 16))
	_invite_panel.custom_minimum_size = Vector2(460, 180)
	_invite_panel.hide()
	add_child(_invite_panel)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(424, 0)
	v.add_theme_constant_override("separation", 12)
	_invite_panel.add_child(v)

	var t := Label.new()
	t.text = _t("invite_title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Assets.ui_font(700))
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", DialogTheme.GOLD)
	v.add_child(t)

	_invite_text = Label.new()
	_invite_text.custom_minimum_size = Vector2(420, 52)
	_invite_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_invite_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_invite_text)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	v.add_child(btns)

	var acc := Button.new()
	acc.text = _t("invite_accept")
	acc.custom_minimum_size = Vector2(180, 40)
	_style_accent_button(acc, Color(0.11, 0.42, 0.25, 0.98), Color(0.16, 0.52, 0.32, 1.0), DialogTheme.GOLD)
	acc.pressed.connect(_on_accept_invite)
	btns.add_child(acc)

	var dec := Button.new()
	dec.text = _t("invite_decline")
	dec.custom_minimum_size = Vector2(110, 40)
	dec.pressed.connect(_on_decline_invite)
	btns.add_child(dec)


func _start_challenge(target_id: String, target_name: String) -> void:
	if not Paths.has_game(_selected_game):
		_set_hub_status(_t("need_game") % _game_name(_selected_game), Color(1.0, 0.52, 0.45))
		return
	_stop_active_room_wait()
	var err: int = Online.challenge_player(target_id, _selected_game)
	if err != OK:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_waiting_challenge = true
	_challenge_target_name = target_name
	_challenge_game = _selected_game
	_joining_game = _selected_game
	_challenge_label.text = _t("challenge_wait") % [target_name, _game_short(_challenge_game), "..."]
	_challenge_banner.show()


func _cancel_challenge() -> void:
	_waiting_challenge = false
	_challenge_banner.hide()
	Online.cancel_challenge()


func _center_invite_panel() -> void:
	if not is_instance_valid(_invite_panel) or not _invite_panel.visible:
		return
	var vp: Rect2 = get_viewport().get_visible_rect()
	var w: float = minf(460.0, vp.size.x - 24.0)
	_invite_text.custom_minimum_size = Vector2(maxf(240.0, w - 40.0), 52.0)
	_invite_panel.custom_minimum_size = Vector2(w, 180.0)
	_invite_panel.reset_size()
	var sz: Vector2 = _invite_panel.get_combined_minimum_size()
	sz.x = clampf(sz.x, 300.0, vp.size.x - 24.0)
	sz.y = clampf(sz.y, 170.0, vp.size.y - 24.0)
	_invite_panel.size = sz
	_invite_panel.position = Vector2(
		maxf(12.0, vp.get_center().x - sz.x * 0.5),
		maxf(12.0, vp.get_center().y - sz.y * 0.5)
	).floor()


func _on_duel_invite_received(from_id: String, from_name: String, room_code: String, game_id: String, pool := "competitive") -> void:
	Online.hide_global_invite_toast()
	var g: String = game_id if game_id in Game.GAMES else "joey"
	var inv_pool: String = "sandbox" if pool == "sandbox" else "competitive"
	var clean_name: String = from_name.strip_edges() if from_name.strip_edges() != "" else "Duelist"
	_incoming_invite = {"from_id": from_id, "from_name": clean_name, "room_code": room_code, "game_id": g, "pool": inv_pool}
	_invite_text.text = "%s\n%s" % [_t("invite_body") % [clean_name, from_id, _game_name(g)], Online.pool_label(inv_pool)]
	_invite_panel.show()
	_center_invite_panel()
	_center_invite_panel.call_deferred()


func _on_accept_invite() -> void:
	Online.hide_global_invite_toast()
	var inv: Dictionary = _incoming_invite
	_incoming_invite = {}
	_invite_panel.hide()
	var game_id: String = str(inv.get("game_id", "joey"))
	var inv_pool: String = str(inv.get("pool", "competitive"))
	if not Paths.has_game(game_id):
		if _mode == "hub":
			_set_hub_status(_t("need_game") % _game_name(game_id), Color(1.0, 0.52, 0.45))
		elif _mode == "pick_game":
			_picker_status.text = _t("need_game") % _game_name(game_id)
		return
	var code: String = str(inv.get("room_code", ""))
	_close_dm_modal()
	_stop_active_room_wait()
	if not Online.all_cards_unlocked and inv_pool in ["competitive", "sandbox"]:
		Online.set_online_pool(inv_pool)
	open_hub("duel", game_id)
	if Online.accept_duel_invite(code, game_id, inv_pool) != OK:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))
		return
	_duel_joining = true
	_joining_game = game_id
	_set_hub_status(_t("connecting"))
	if is_instance_valid(_duel_room_status):
		_duel_room_status.text = _t("connecting")


func _on_decline_invite() -> void:
	Online.hide_global_invite_toast()
	if not _incoming_invite.is_empty():
		Online.decline_duel_invite(str(_incoming_invite.get("from_id", "")), str(_incoming_invite.get("room_code", "")))
	_incoming_invite = {}
	_invite_panel.hide()


func _on_invite_declined_received(_by_id: String, by_name: String, _room_code: String) -> void:
	if _waiting_challenge:
		_waiting_challenge = false
		_challenge_banner.hide()
		_set_hub_status(_t("invite_declined") % by_name, Color(1.0, 0.65, 0.45))


func _on_invite_status_received(_target_id: String, room_code: String, delivered: bool) -> void:
	if not _waiting_challenge:
		return
	if delivered:
		_challenge_label.text = _t("challenge_wait") % [_challenge_target_name, _game_short(_challenge_game), room_code]
	else:
		_set_hub_status(_t("invite_offline") % room_code, Color(1.0, 0.85, 0.45))


func _on_invite_error_received(code: String, _target_id: String) -> void:
	if _waiting_challenge:
		_waiting_challenge = false
		_challenge_banner.hide()
	_refresh_hub_header()
	_refresh_pool_selector_ui()
	if code == "target_sandbox_only":
		_set_hub_status(_t("err_target_sandbox_only"), Color(1.0, 0.65, 0.40))
	elif code == "unlocked_account_sandbox_only":
		_set_hub_status(_t("err_sandbox_only"), Color(1.0, 0.65, 0.40))
	else:
		_set_hub_status(_t("err_net"), Color(1.0, 0.52, 0.45))


func _on_session_changed() -> void:
	if _mode == "hub":
		_refresh_hub_header()
		if _hub_tab == "duel":
			_refresh_pool_selector_ui()
	elif _mode == "pick_game":
		_refresh_picker_cards()


func _on_friend_request_received(_from_id: String, from_name: String) -> void:
	_refresh_hub_header()
	if _mode == "pick_game":
		_refresh_picker_cards()
	elif _mode == "hub":
		_set_hub_status("%s: %s" % [_t("incoming_title"), from_name], Color(0.65, 0.95, 0.65))
		if _hub_tab == "friends":
			_load_friends()


func _on_friend_accepted_received(_pid: String, dname: String) -> void:
	_refresh_hub_header()
	if _mode == "hub":
		_set_hub_status("%s (%s)" % [_t("now_friends"), dname], Color(0.65, 0.95, 0.65))
		if _hub_tab == "friends":
			_load_friends()


func _lan_error_text(code: String) -> String:
	match code:
		"not_found": return _t("room_not_found")
		"room_full": return _t("room_full")
		"game_mismatch":
			if Lan.status_detail != "":
				return _t("room_game_mismatch") % _game_name(Lan.status_detail)
			return _t("room_not_found")
		"unlocked_account_sandbox_only":
			Online.mark_all_cards_unlocked()
			_refresh_hub_header()
			_refresh_pool_selector_ui()
			return _t("err_sandbox_only")
		"pool_mismatch":
			if Lan.status_detail == "sandbox":
				return _t("err_pool_mismatch_sandbox")
			return _t("err_pool_mismatch_comp")
		"expired": return _t("room_expired")
		"timeout": return _t("room_timeout")
		_: return _t("err_net")


func _launch_matched_duel(game_id: String) -> void:
	_waiting_challenge = false
	_duel_hosting = false
	_duel_joining = false
	_matchmaking = false
	_matchmaking_elapsed = 0.0
	_challenge_banner.hide()
	_close_dm_modal()
	_mode = ""
	_backdrop.hide()
	_picker_panel.hide()
	_hub_panel.hide()
	_login_panel.hide()
	launch_online_duel.emit(game_id)


func _process(delta: float) -> void:
	if _dm_panel.visible:
		var vp2: Rect2 = get_viewport().get_visible_rect()
		var dsz: Vector2 = _dm_panel.size
		_dm_panel.position = Vector2(
			maxf(12.0, vp2.get_center().x - dsz.x * 0.5),
			maxf(12.0, vp2.get_center().y - dsz.y * 0.5)
		).floor()
	if _matchmaking:
		_matchmaking_elapsed += delta
		var secs: int = int(_matchmaking_elapsed)
		if is_instance_valid(_matchmaking_timer_lbl):
			_matchmaking_timer_lbl.text = "%02d:%02d" % [secs / 60, secs % 60]
	if _waiting_challenge:
		if Lan.room_code != "" and _challenge_banner.visible:
			_challenge_label.text = _t("challenge_wait") % [_challenge_target_name, _game_short(_challenge_game), Lan.room_code]
		if Lan.players() == 2:
			_launch_matched_duel(_challenge_game)
		elif Lan.terminated:
			_waiting_challenge = false
			_challenge_banner.hide()
			_set_hub_status(_lan_error_text(Lan.status_error), Color(1.0, 0.52, 0.45))
		return
	if _duel_hosting or _duel_joining:
		if _duel_hosting and Lan.room_code != "" and is_instance_valid(_duel_room_code_label):
			if _duel_room_code_label.text != Lan.room_code:
				_duel_room_code_label.text = Lan.room_code
				_duel_copy_code_btn.disabled = false
				_duel_room_status.text = _t("waiting_room") % Lan.room_code
				_set_hub_status(_t("waiting_room") % Lan.room_code, Color(0.65, 0.95, 0.65))
		if Lan.players() == 2:
			_launch_matched_duel(_joining_game)
		elif Lan.terminated:
			var err_msg: String = _lan_error_text(Lan.status_error)
			_on_duel_cancel_pressed()
			_set_hub_status(err_msg, Color(1.0, 0.52, 0.45))
			if is_instance_valid(_duel_room_status):
				_duel_room_status.text = err_msg


func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _dm_panel.visible:
			_close_dm_modal()
		else:
			close_all()
