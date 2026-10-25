# Quality check for generated voice: has Gemini transcribe each audio/voice/*.wav and
# compares it with the intended text, so bad takes are caught without listening.
# Flags spoken English (a sign the style instruction was read aloud), a non-native (English)
# accent, missing words, a doubled take (the line said twice), and battle cries ("call_*")
# longer than 1.4 s. Durations are read from the WAV header, so after tools/trim_voice.gd
# they are the trimmed lengths. Vocal effects without text (vo_*, breath_*) are skipped.
#
#   powershell -ExecutionPolicy Bypass -File tools\tts_check.ps1 [-Only c1_intro_00] [-Prefix call_] [-EnvFile path\to\.env]

param([string]$Only = "", [string]$Prefix = "", [string]$Model = "gemini-3.8-flash", [string]$EnvFile = "")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ($EnvFile -eq "") { $EnvFile = Join-Path $root ".env" }
$keyLine = Get-Content $EnvFile | Where-Object { $_ -match '^\s*GOOGLE_API_KEY\s*=' } | Select-Object -First 1
$key = ($keyLine -split '=', 2)[1].Trim().Trim('"').Trim("'")

$expected = @{}
$story = Get-Content (Join-Path $root "config\story.json") -Raw -Encoding UTF8 | ConvertFrom-Json
function Add-Expected($beats) {
	foreach ($b in $beats) {
		if ($b.options) { foreach ($o in $b.options) { Add-Expected $o.reply }; continue }
		if ($b.voice) { $expected[$b.voice] = if ($b.sa) { $b.sa } else { $b.hi } }
	}
}
foreach ($story_id in $story.PSObject.Properties) {
	if ($story_id.Name.StartsWith("_")) { continue }
	foreach ($item in $story_id.Value) {
		if ($item.beats) { Add-Expected $item.beats } else { Add-Expected @($item) }
	}
}
$cfg = Get-Content (Join-Path $root "config\voice_lines.json") -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($call in $cfg.calls.PSObject.Properties) { $expected[$call.Name] = $call.Value }

# Duration from the RIFF chunks (any header layout, any sample format).
function Get-WavSeconds([byte[]]$b) {
	$pos = 12; $rate = 0; $align = 0; $dataLen = 0
	while ($pos + 8 -le $b.Length) {
		$id = [Text.Encoding]::ASCII.GetString($b, $pos, 4)
		$size = [BitConverter]::ToUInt32($b, $pos + 4)
		if ($id -eq "fmt ") { $rate = [BitConverter]::ToUInt32($b, $pos + 12); $align = [BitConverter]::ToUInt16($b, $pos + 20) }
		elseif ($id -eq "data") { $dataLen = [math]::Min($size, $b.Length - $pos - 8) }
		$pos += 8 + $size + ($size % 2)
	}
	if ($rate -eq 0 -or $align -eq 0) { return 0 }
	return $dataLen / $align / $rate
}

foreach ($file in Get-ChildItem (Join-Path $root "audio\voice") -Filter *.wav) {
	$id = $file.BaseName
	if ($Only -ne "" -and $id -ne $Only) { continue }
	if ($Prefix -ne "" -and -not $id.StartsWith($Prefix)) { continue }
	if (-not $expected.ContainsKey($id)) { continue }
	$bytes = [IO.File]::ReadAllBytes($file.FullName)
	$secs = [math]::Round((Get-WavSeconds $bytes), 2)
	$prompt = "The intended line is: `"$($expected[$id])`" (Hindi/Sanskrit). Transcribe exactly what is spoken, in Devanagari for Hindi/Sanskrit. " +
		"Answer in exactly 5 lines: TRANSCRIPT: <text> / ENGLISH_SPOKEN: yes or no / ACCENT: native or foreign (native = sounds like a native Hindi speaker; foreign = English or other non-native accent) / " +
		"REPEATED: yes or no (is the line, or any word of it, said more than once?) / MATCH: yes or no (does it say the intended line exactly once and nothing else?)"
	$body = @{ contents = @(@{ parts = @(
		@{ inlineData = @{ mimeType = "audio/wav"; data = [Convert]::ToBase64String($bytes) } },
		@{ text = $prompt }) }) } | ConvertTo-Json -Depth 10
	$r = Invoke-RestMethod -Method Post -Uri "https://generativelanguage.googleapis.com/v1beta/models/$($Model):generateContent" `
		-Headers @{ "x-goog-api-key" = $key } -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))
	$text = ($r.candidates[0].content.parts | ForEach-Object { $_.text }) -join " "
	$issues = @()
	if ($text -match 'ENGLISH_SPOKEN:\s*\**\s*yes') { $issues += "ENGLISH" }
	if ($text -match 'ACCENT:\s*\**\s*foreign') { $issues += "ACCENT" }
	if ($text -match 'REPEATED:\s*\**\s*yes') { $issues += "DOUBLE" }
	if ($text -match 'MATCH:\s*\**\s*no') { $issues += "MISMATCH" }
	if ($id.StartsWith("call_") -and $secs -gt 1.4) { $issues += "LONG" }
	$verdict = if ($issues.Count) { "BAD " + ($issues -join ",") } else { "ok" }
	"$verdict  $id  ${secs}s  $($text -replace '\s+', ' ')"
	Start-Sleep -Seconds 1
}
