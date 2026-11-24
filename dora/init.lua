-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Minimal Dora SSR entry for the Godot 4 GDScript project.
local Dora = require("Dora")

-- Source-package layout produced by dora/build.py.
-- For the optional PCK flow, change only this value to e.g. "watch-yongchang.pck".
local PROJECT_PATH = "watch-yongchang"
local VIEW_WIDTH, VIEW_HEIGHT = 1280, 720

local reason = Dora.GodotNode.getUnsupportedReason()
assert(reason == "", reason)

local game = assert(
	Dora.GodotNode(PROJECT_PATH, "", VIEW_WIDTH, VIEW_HEIGHT, 3),
	"Could not create GodotNode. See the Dora log."
)
game:addTo(Dora.Director.ui)

local ready = false
game:schedule(function()
	local size = Dora.View.size
	local scale = math.min(size.width / VIEW_WIDTH, size.height / VIEW_HEIGHT)
	game.scaleX, game.scaleY = scale, scale

	if game.lastError ~= "" then
		print("Godot error: " .. game.lastError)
		game:removeFromParent()
		return true
	end

	if game.running and not ready then
		ready = true
		print("[Dora] Godot project ready")
	end
	return false
end)
