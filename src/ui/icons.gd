class_name Icons
extends RefCounted
## UI icons from free icon sets, stored as white SVGs in res://assets/icons/<name>.svg and
## tinted when drawn. Sources and licences: ASSETS.md and assets/licenses/THIRD_PARTY.txt;
## tools/fetch_icons.ps1 downloads and normalises them.
## System icons: Google Material Symbols Rounded (Apache 2.0).
## Game icons: game-icons.net by Lorc, Delapouite and Sbed (CC BY 3.0).

const DIR := "res://assets/icons/"


## The icon's texture, or null if there is no such icon. Cached for the session.
static func texture(name: String) -> Texture2D:
	var cache := UiKit.cache("icons")
	if cache.has(name):
		return cache[name]
	var path := DIR + name + ".svg"
	var tex: Texture2D = load(path) if name != "" and ResourceLoader.exists(path) else null
	cache[name] = tex
	return tex


static func exists(name: String) -> bool:
	return texture(name) != null


## Draws an icon centred on `c`, filling a box of half-size `r`, tinted `col`.
static func draw(ci: CanvasItem, name: String, c: Vector2, r: float, col: Color) -> void:
	var tex := texture(name)
	if tex == null or r <= 0.0:
		return
	ci.draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
