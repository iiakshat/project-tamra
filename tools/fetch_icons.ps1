# Downloads the UI icons into assets/icons/<name>.svg and normalises them for Godot:
# white fill (recoloured in game with modulate), no background square, 128 px canvas.
# Sources (both free for commercial use; see ASSETS.md and the in-game Credits):
#   ms = Google Material Symbols Rounded, Apache License 2.0
#   gi = game-icons.net, CC BY 3.0 (attribution to the author folder is required)
# Usage (from the project folder):  powershell -File tools/fetch_icons.ps1
# After running, re-import:          godot --headless --path . --import

$ErrorActionPreference = "Stop"
$out = Join-Path $PSScriptRoot "..\assets\icons"
New-Item -ItemType Directory -Force $out | Out-Null

$msBase = "https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web"
$giBase = "https://raw.githubusercontent.com/game-icons/icons/master"

# name = set:source[:fill0]
$icons = [ordered]@{
	"play" = "ms:play_arrow"; "next" = "ms:skip_next"; "pause" = "ms:pause"; "restart" = "ms:replay"
	"home" = "ms:home"; "close" = "ms:close"; "check" = "ms:check"; "gear" = "ms:settings"
	"music" = "ms:music_note"; "music_off" = "ms:music_off"; "sound" = "ms:volume_up"; "sound_off" = "ms:volume_off"
	"vibration" = "ms:vibration"; "lock" = "ms:lock"; "star" = "ms:star"; "star_empty" = "ms:star:fill0"
	"clock" = "ms:schedule"; "hourglass" = "ms:hourglass_bottom"; "question" = "ms:help"; "pen" = "ms:edit"
	"log" = "ms:content_copy"; "up" = "ms:arrow_upward"; "map" = "ms:map"; "info" = "ms:info"
	"shop" = "ms:storefront"; "heart" = "ms:favorite"; "back" = "ms:arrow_back"; "chevron" = "ms:chevron_right"
	"gift" = "gi:delapouite/present"; "book" = "gi:lorc/open-book"; "story" = "gi:lorc/scroll-unfurled"
	"vow" = "gi:lorc/tied-scroll"; "jyoti" = "gi:lorc/candlebright"; "prana" = "gi:lorc/lotus"
	"trial" = "gi:lorc/crossed-swords"; "skull" = "gi:sbed/death-skull"; "fire" = "gi:lorc/fireball"
	"cast" = "gi:lorc/magic-swirl"; "flag" = "gi:delapouite/level-end-flag"; "bridge" = "gi:delapouite/stone-bridge"
	"leap" = "gi:delapouite/jump-across"; "skin" = "gi:lorc/robe"
}

foreach ($name in $icons.Keys) {
	$spec = $icons[$name].Split(":")
	if ($spec[0] -eq "ms") {
		$file = if ($spec.Count -gt 2 -and $spec[2] -eq "fill0") { "$($spec[1])_48px.svg" } else { "$($spec[1])_fill1_48px.svg" }
		$url = "$msBase/$($spec[1])/materialsymbolsrounded/$file"
		$credit = "Material Symbols Rounded '$($spec[1])' by Google, Apache License 2.0"
	} else {
		$url = "$giBase/$($spec[1]).svg"
		$author = $spec[1].Split("/")[0]
		$credit = "game-icons.net '$($spec[1].Split('/')[1])' by $author, CC BY 3.0"
	}
	$svg = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content
	if ($svg -is [byte[]]) { $svg = [System.Text.Encoding]::UTF8.GetString($svg) }
	$svg = $svg.Replace('<path d="M0 0h512v512H0z"/>', "")
	# game-icons fill their whole box; pad them to Material's ~84% optical size.
	$svg = $svg.Replace('viewBox="0 0 512 512"', 'viewBox="-40 -40 592 592"')
	$svg = $svg -replace ' (width|height)="[^"]*"', ""
	$svg = $svg -replace "<svg ", '<svg width="128" height="128" fill="#ffffff" '
	$svg = $svg.Replace("<svg ", "<!-- $credit. Source: $url -->`n<svg ")
	[System.IO.File]::WriteAllText((Join-Path $out "$name.svg"), $svg, (New-Object System.Text.UTF8Encoding $false))
	Write-Output "$name <- $url"
}
