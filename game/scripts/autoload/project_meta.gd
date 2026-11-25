extends Node

const META_PATH := "res://data/project_meta.json"

var version: String = "0.0.0"
var godot_version: String = ""
var game_slug: String = ""
var game_name_zh: String = ""
var game_name_en: String = ""
var author: String = ""
var author_email: String = ""
var repo_url: String = ""
var web_url: String = ""
var cloudflare_pages_project: String = ""
var cloudflare_pages_domain: String = ""
var bundle_identifier: String = ""
var icon_path: String = ""
var copyright_notice: String = ""
var loaded_from_file: bool = false


func _ready() -> void:
	reload()


func reload() -> void:
	version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	game_name_zh = str(ProjectSettings.get_setting("application/config/name", ""))
	icon_path = str(ProjectSettings.get_setting("application/config/icon", ""))
	godot_version = ""
	game_slug = ""
	game_name_en = ""
	author = ""
	author_email = ""
	repo_url = ""
	web_url = ""
	cloudflare_pages_project = ""
	cloudflare_pages_domain = ""
	bundle_identifier = ""
	copyright_notice = ""
	loaded_from_file = false

	var metadata := _read_metadata()
	if metadata.is_empty():
		return
	loaded_from_file = true
	var app: Dictionary = metadata.get("app", {}) as Dictionary
	version = str(app.get("version", version))
	godot_version = str(app.get("godot_version", ""))
	game_slug = str(app.get("slug", ""))
	bundle_identifier = str(app.get("bundle_identifier", ""))
	icon_path = str(app.get("icon", icon_path))
	var names: Dictionary = app.get("names", {}) as Dictionary
	game_name_zh = str(names.get("zh", game_name_zh))
	game_name_en = str(names.get("en", ""))
	var author_data: Dictionary = metadata.get("author", {}) as Dictionary
	author = str(author_data.get("name", ""))
	author_email = str(author_data.get("email", ""))
	var links: Dictionary = metadata.get("links", {}) as Dictionary
	repo_url = str(links.get("repository", ""))
	web_url = str(links.get("web", ""))
	var pages: Dictionary = metadata.get("cloudflare_pages", {}) as Dictionary
	cloudflare_pages_project = str(pages.get("project", ""))
	cloudflare_pages_domain = str(pages.get("domain", ""))
	var legal: Dictionary = metadata.get("legal", {}) as Dictionary
	copyright_notice = str(legal.get("copyright_notice", ""))


func localized_name(code: String) -> String:
	if code.begins_with("en") and not game_name_en.is_empty():
		return game_name_en
	return game_name_zh


func _read_metadata() -> Dictionary:
	if not FileAccess.file_exists(META_PATH):
		push_error("Missing generated project metadata: %s" % META_PATH)
		return {}
	var file := FileAccess.open(META_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open generated project metadata: %s" % META_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("Invalid generated project metadata: %s" % META_PATH)
	return {}
