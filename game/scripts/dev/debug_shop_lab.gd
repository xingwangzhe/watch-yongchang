extends "res://scripts/dev/debug_room.gd"

const STARTING_COINS := 260
const REROLL_COST := 25

var _shop: ShopOverlay
var _rng := RandomNumberGenerator.new()
var _coins := STARTING_COINS
var _offers: Array[Dictionary] = []
var _reopen_button: Button


func _ready() -> void:
	room_title = "灯下军市 UI / 独立预览"
	super._ready()
	_rng.seed = 20261128
	_shop = ShopOverlay.new()
	_shop.name = "ShopOverlay"
	add_child(_shop)
	_shop.buy_requested.connect(_buy_offer)
	_shop.reroll_requested.connect(_reroll_offers)
	_shop.closed.connect(_close_shop)
	_reopen_button = Button.new()
	_reopen_button.name = "ReopenShopButton"
	_reopen_button.text = "打开灯下军市"
	_reopen_button.anchor_left = 1.0
	_reopen_button.anchor_right = 1.0
	_reopen_button.offset_left = -230.0
	_reopen_button.offset_top = 68.0
	_reopen_button.offset_right = -14.0
	_reopen_button.offset_bottom = 116.0
	_reopen_button.visible = false
	_reopen_button.pressed.connect(_show_shop)
	$DebugOverlay.add_child(_reopen_button)
	_show_shop()


func _show_shop() -> void:
	_reopen_button.visible = false
	$DebugOverlay.visible = false
	_coins = STARTING_COINS
	_offers = _build_offers()
	_shop.show_shop(_offers, _coins, REROLL_COST, _mercenary_info())
	_shop.show_message("调试预览 · Esc 返回调试目录")


func _close_shop() -> void:
	_shop.visible = false
	$DebugOverlay.visible = true
	_reopen_button.visible = true


func _buy_offer(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	var offer := _offers[index]
	if bool(offer.get("sold", false)):
		return
	var price := int(offer.get("price", 0))
	if _coins < price:
		_shop.show_message(Locale.t("shop.not_enough"), true)
		return
	_coins -= price
	offer["sold"] = true
	_offers[index] = offer
	_shop.refresh(_offers, _coins, REROLL_COST, _mercenary_info())
	_shop.show_message(Locale.t("shop.bought", {"name": str(offer.get("title", ""))}))


func _reroll_offers() -> void:
	if _coins < REROLL_COST:
		_shop.show_message(Locale.t("shop.not_enough"), true)
		return
	_coins -= REROLL_COST
	_offers = _build_offers()
	_shop.refresh(_offers, _coins, REROLL_COST, _mercenary_info())
	_shop.show_message(Locale.t("shop.rerolled"))


func _build_offers() -> Array[Dictionary]:
	var no_weapons: Array = []
	var no_passives: Dictionary = {}
	var no_mercenaries: Array[String] = []
	return ShopCatalog.build_offers(no_weapons, no_passives, no_mercenaries, _rng)


func _mercenary_info() -> Dictionary:
	return {"count": 0, "max": 3, "names": "暂无"}
