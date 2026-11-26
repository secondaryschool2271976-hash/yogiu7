extends SceneTree
## Engine-only staged/exported project smoke; no original game data is needed.
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	await process_frame
	var paths := root.get_node("Paths")
	var game := root.get_node("Game")
	var report_path: String = paths.cmdline_value("report")
	var import_pack: String = paths.cmdline_value("boot-import-pack")
	var cache_check: bool = paths.cmdline_value("boot-cache-check") == "true"
	check(not paths.cmdline_value("storage").is_empty(), "Engine-only smoke requires isolated --storage")
	check(FileAccess.file_exists("res://translations/arabic-cards.json"), "arabic card translations JSON is bundled in APK")
	var card_translations := root.get_node("CardTranslations")
	check(card_translations != null and card_translations._arabic_cards.size() >= 1400, "arabic card translations loaded all 1400 cards")
	check(FileAccess.file_exists("res://assets/cards/arabic_cards.zip"), "arabic card artwork pack is bundled in APK")
	check(FileAccess.file_exists("res://assets/cards/extra_cards.json"), "extra 629 classic/god card definitions are bundled in APK")
	var assets_node := root.get_node("Assets")
	check(assets_node != null and assets_node.card_pack_count() >= 1350, "arabic card artwork pack indexed crisp arab-duelists images")
	if assets_node != null:
		var full_tex: Texture2D = assets_node.texture("common/card/ad_10000010.webp")
		var mini_tex: Texture2D = assets_node.texture("common/mini/ad_10000010.webp")
		check(full_tex != null and full_tex.get_size() == Vector2(200, 290), "full arabic Ra texture decodes at 200x290")
		check(mini_tex != null and mini_tex.get_size() == Vector2(50, 72), "mini arabic Ra texture decodes at 50x72")
	var card_db := root.get_node("CardDB")
	check(card_db != null and card_db.extra_cards.size() >= 629, "CardDB loaded all 629 extra classic/god/millennium cards")
	check(card_db != null and card_db.PACK_BITS["yugi"] == 7 and card_db.PACK_BITS["kaiba"] == 7 and card_db.PACK_BITS["joey"] == 7, "all 1400 cards are unified across Yugi, Kaiba, and Joey")
	if card_db != null:
		var obelisk_full: Texture2D = card_db.card_texture(2500, false, false)
		var obelisk_mini: Texture2D = card_db.card_texture(2500, true, false)
		var obelisk_defer: Texture2D = card_db.card_texture(2500, true, true)
		var fallback_face: Texture2D = card_db.card_texture(999999, false, false)
		var back_tex: Texture2D = card_db.card_texture(-1, false, false)
		check(obelisk_full != null and obelisk_full.get_size() == Vector2(200, 290), "CardDB.card_texture loads full card art")
		check(obelisk_mini != null and obelisk_mini.get_size() == Vector2(50, 72), "CardDB.card_texture loads mini card art")
		check(obelisk_defer != null and obelisk_defer.get_size() == Vector2(50, 72), "CardDB.card_texture deferred returns mini texture")
		check(fallback_face != null and fallback_face.get_size() == Vector2(200, 290), "CardDB.card_texture returns fallback card face when missing")
		check(back_tex != null, "CardDB.card_texture(-1) returns card back texture")
	check(not FileAccess.file_exists("res://bundled_data.pck"), "engine-only project has no bundled original resources")
	if not cache_check:
		check(not FileAccess.file_exists("res://data/inventory.json"), "engine-only project has no mounted original inventory")
		check(not paths.has_data(), "fresh engine-only install requests its user resource pack")
	# Exercise the configured production entry point, not an importer constructed by
	# the test. A missing boot->launcher route must fail this build smoke.
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	check(change_scene_to_file(main_scene) == OK, "configured main scene starts")
	for frame: int in range(8):
		await process_frame
	var actual: Node = game._screen
	var expected := "launcher_android.gd" if cache_check else "android_content_setup.gd"
	check(is_instance_valid(actual) and actual.get_script().resource_path.get_file() == expected,
		"actual boot reaches " + expected)
	if not cache_check and is_instance_valid(actual) and actual.get_script().resource_path.get_file() == expected:
		check(actual._picker.use_native_dialog and actual._picker.access == FileDialog.ACCESS_FILESYSTEM,
			"actual first-run screen exposes native Android file selection")
		actual._selection_cancelled()
		check(not actual._choose.disabled, "actual first-run cancellation keeps import available")
		if not import_pack.is_empty():
			await actual._import_selected(import_pack)
			for frame: int in range(4):
				await process_frame
			check(paths.has_data() and paths.content_pack_persistent, "real selected PCK persists and mounts")
			check(game._screen.get_script().resource_path.get_file() == "launcher_android.gd", "real first-run import reaches game launcher")
			check(root.get_node("CardDB").cards.size() >= 771, "real first-run import loads card database")
	if cache_check:
		check(paths.has_data() and paths.content_pack_persistent, "second boot reuses persisted PCK without importing")
		check(root.get_node("CardDB").cards.size() >= 771, "second boot has card database")
	var setup: Script = load("res://scenes/launcher/android_content_setup.gd")
	check(setup != null, "first-run importer is available in the public engine bundle")
	if setup != null:
		for lang: String in ["s", "e", "g", "f", "i", "j"]:
			var screen: Control = setup.new()
			screen._lang = lang
			root.add_child(screen)
			await process_frame
			check(screen._choose.text == load("res://scenes/launcher/import_texts.gd").text("pack_choose", lang), "import action is localized")
			check(screen._choose.custom_minimum_size.y >= 60, "import action has a touch-sized target")
			check(screen._picker.use_native_dialog and screen._picker.access == FileDialog.ACCESS_FILESYSTEM, "Android uses the native system file picker")
			check(screen._picker.file_mode == FileDialog.FILE_MODE_OPEN_FILE and not screen._picker.filters.is_empty(), "picker selects a single resource pack")
			var before := FileAccess.file_exists(paths.user_content_pack_path())
			screen._selection_cancelled()
			check(not screen._status.text.is_empty() and not screen._choose.disabled, "cancel selection leaves import available")
			check(FileAccess.file_exists(paths.user_content_pack_path()) == before, "cancel never creates or changes content")
			screen.free()
	var android_launcher_script: Script = load("res://scenes/launcher/launcher_android.gd")
	check(android_launcher_script != null and android_launcher_script.can_instantiate(), "Android launcher script compiles and instantiates")
	if android_launcher_script != null and android_launcher_script.can_instantiate():
		var android_launcher: Node = android_launcher_script.new()
		root.add_child(android_launcher)
		await process_frame
		await process_frame
		check(is_instance_valid(android_launcher.get("_controls")), "Android launcher controls initialize")
		check(is_instance_valid(android_launcher.get("_release_footer")), "Android launcher release footer initializes")
		android_launcher.free()
	var reward_script: Script = load("res://scenes/launcher/reward_modals.gd")
	check(reward_script != null and reward_script.can_instantiate(), "Reward modals script compiles and instantiates")
	if reward_script != null and reward_script.can_instantiate():
		var rewards: CanvasLayer = reward_script.new()
		root.add_child(rewards)
		await process_frame
		rewards.call("open_card_code")
		rewards.call("open_lucky_wheel")
		rewards.call("open_special_wheel")
		rewards.call("open_gift_admin")
		rewards.call("close_all")
		rewards.free()
	var hub_script: Script = load("res://scenes/launcher/online_hub.gd")
	check(hub_script != null and hub_script.can_instantiate(), "Online hub script compiles and instantiates")
	if hub_script != null and hub_script.can_instantiate():
		var hub: CanvasLayer = hub_script.new()
		root.add_child(hub)
		await process_frame
		hub.call("close_all")
		hub.free()
	var deck_editor_script: Script = load("res://scenes/deck_editor/deck_editor.gd")
	check(deck_editor_script != null and deck_editor_script.can_instantiate(), "Deck editor script compiles and instantiates")
	var card_list_script: Script = load("res://scenes/card_list/card_list.gd")
	check(card_list_script != null and card_list_script.can_instantiate(), "Card list script compiles and instantiates")
	var offline_modal_script: Script = load("res://scenes/title/offline_setup_modal.gd")
	check(offline_modal_script != null and offline_modal_script.can_instantiate(), "Offline setup modal script compiles and instantiates")
	if offline_modal_script != null and offline_modal_script.can_instantiate():
		var offline_modal: CanvasLayer = offline_modal_script.new()
		root.add_child(offline_modal)
		await process_frame
		offline_modal.call("setup", "joey")
		offline_modal.call("open_for_game", "joey")
		offline_modal.call("close_modal")
		offline_modal.free()
	var desktop_launcher_script: Script = load("res://scenes/launcher/launcher.gd")
	var desktop_setup_script: Script = load("res://scenes/launcher/content_setup.gd")
	check(desktop_launcher_script != null and desktop_launcher_script.can_instantiate(), "Desktop launcher script compiles")
	check(desktop_setup_script != null and desktop_setup_script.can_instantiate(), "Desktop content_setup script compiles")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			check(false, "engine-only smoke report is writable")
		else:
			file.store_string(JSON.stringify({"ok": failures.is_empty(), "message": "Production boot and engine-only import screen", "failures": failures, "data_dir": paths.data_dir, "main_scene": main_scene, "real_import": not import_pack.is_empty(), "second_boot": cache_check, "physical_device_tested": false}, "  "))
			file.close()
	root.get_node("Audio").stop_all()
	print("android_engine_bundle_test: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
