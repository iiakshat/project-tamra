# Quality check for generated voice: has Gemini transcribe each audio/voice/*.wav and
# compares it with the intended text, so bad takes are caught without listening.
# Flags spoken English (a sign the style instruction was read aloud) and missing words.
#
#   powershell -ExecutionPolicy Bypass -File tools\tts_check.ps1 [-Only c1_intro_00]

param([string]$Only = "", [string]$Model = "gemini-3.8-flash")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$keyLine = Get-Content (Join-Path $root ".env") | Where-Object { $_ -match '^\s*GOOGLE_API_KEY\s*=' } | Select-Object -First 1
$key = ($keyLine -split '=', 2)[1].Trim().Trim('"').Trim("'")

$expected = @{}
$story = Get-Content (Join-Path $root "config\story.json") -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($chapter in $story.PSObject.Properties) {
	foreach ($line in $chapter.Value) {
		if ($line.voice) { $expected[$line.voice] = if ($line.sa) { $line.sa } else { $line.hi } }
	}
}
$cfg = Get-Content (Join-Path $root "config\voice_lines.json") -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($call in $cfg.calls.PSObject.Properties) { $expected[$call.Name] = $call.Value }

foreach ($file in Get-ChildItem (Join-Path $root "audio\voice") -Filter *.wav) {
	$id = $file.BaseName
	if ($Only -ne "" -and $id -ne $Only) { continue }
	$bytes = [IO.File]::ReadAllBytes($file.FullName)
	$prompt = "The intended line is: `"$($expected[$id])`". Transcribe exactly what is spoken, in Devanagari for Hindi/Sanskrit. " +
		"Answer in exactly 3 lines: TRANSCRIPT: <text> / ENGLISH_SPOKEN: yes or no / MATCH: yes or no (does it say the intended line and nothing else?)"
	$body = @{ contents = @(@{ parts = @(
		@{ inlineData = @{ mimeType = "audio/wav"; data = [Convert]::ToBase64String($bytes) } },
		@{ text = $prompt }) }) } | ConvertTo-Json -Depth 10
	$r = Invoke-RestMethod -Method Post -Uri "https://generativelanguage.googleapis.com/v1beta/models/$($Model):generateContent" `
		-Headers @{ "x-goog-api-key" = $key } -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))
	$text = ($r.candidates[0].content.parts | ForEach-Object { $_.text }) -join " "
	$secs = [math]::Round(($bytes.Length - 44) / 48000.0, 1)
	$bad = ($text -match 'ENGLISH_SPOKEN:\s*yes') -or ($text -match 'MATCH:\s*no')
	"$(if ($bad) { 'BAD ' } else { 'ok  ' }) $id  ${secs}s  $($text -replace '\s+', ' ')"
	Start-Sleep -Seconds 1
}
