# Generates the hero's non-verbal vocals (grunts, screams, panting) with Gemini TTS into
# audio/vocal/<id>.wav, and synthesizes the soft idle-breathing loop with ffmpeg.
# Reads GOOGLE_API_KEY from .env and never prints it. Existing files are skipped.
# Afterwards: trim with tools/trim_voice.gd (pass -- --dir=res://audio/vocal/) and convert.
#
#   powershell -ExecutionPolicy Bypass -File tools\tts_vocals.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "audio\vocal"
New-Item -ItemType Directory -Force $outDir | Out-Null
$ffmpeg = Join-Path (Split-Path -Parent $root) "_tools\ffmpeg\ffmpeg.exe"
$keyLine = Get-Content (Join-Path $root ".env") | Where-Object { $_ -match '^\s*GOOGLE_API_KEY\s*=' } | Select-Object -First 1
$key = ($keyLine -split '=', 2)[1].Trim().Trim('"').Trim("'")
$model = "gemini-2.5-flash-preview-tts"
$voice = "Orus"

# id = prompt. Short style cue + the sound itself, the form the TTS model treats as direction.
$takes = [ordered]@{
	"vo_jump_0" = "Grunt sharply with effort as you leap: Hup!"
	"vo_jump_1" = "Grunt sharply with effort as you leap: Hah!"
	"vo_jump_2" = "Grunt sharply with effort as you leap: Hyah!"
	"vo_fall_0" = "Scream in terror, fading as you fall away: Aaaaaaaaaah!"
	"vo_fall_1" = "Scream in panic, fading as you fall away: Waaaaaaaah!"
	"vo_hurt_0" = "Grunt in pain as if struck: Ugh!"
	"vo_hurt_1" = "Grunt in pain as if struck: Argh!"
	"vo_hurt_2" = "Grunt in pain as if struck: Oof!"
	"vo_death_0" = "Cry out weakly as you collapse: Aaagh..."
	"vo_pant_0" = "Pant once, exhausted, one heavy breath in and out: Haaah."
	"vo_pant_1" = "Pant once, exhausted, one heavy breath in and out: Huuuh."
	"vo_pant_2" = "Pant once, exhausted, one heavy breath out: Hhhaah."
}

function Write-Wav([string]$path, [byte[]]$pcm, [int]$rate) {
	$fs = [IO.File]::Create($path)
	$w = New-Object IO.BinaryWriter($fs)
	$w.Write([Text.Encoding]::ASCII.GetBytes("RIFF")); $w.Write([int](36 + $pcm.Length))
	$w.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt ")); $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1)
	$w.Write([int]$rate); $w.Write([int]($rate * 2)); $w.Write([int16]2); $w.Write([int16]16)
	$w.Write([Text.Encoding]::ASCII.GetBytes("data")); $w.Write([int]$pcm.Length); $w.Write($pcm)
	$w.Close()
}

foreach ($id in $takes.Keys) {
	$path = Join-Path $outDir "$id.wav"
	if ((Test-Path $path) -or (Test-Path ($path -replace "\.wav$", ".ogg"))) { continue }
	$body = @{
		contents = @(@{ parts = @(@{ text = $takes[$id] }) })
		generationConfig = @{ responseModalities = @("AUDIO"); speechConfig = @{ voiceConfig = @{ prebuiltVoiceConfig = @{ voiceName = $voice } } } }
	} | ConvertTo-Json -Depth 10
	for ($attempt = 1; $attempt -le 3; $attempt++) {
		try {
			$r = Invoke-RestMethod -Method Post -Uri "https://generativelanguage.googleapis.com/v1beta/models/$($model):generateContent" `
				-Headers @{ "x-goog-api-key" = $key } -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))
			$part = $r.candidates[0].content.parts | Where-Object { $_.inlineData } | Select-Object -First 1
			if (-not $part) { throw "no audio in response" }
			$rate = 24000
			if ($part.inlineData.mimeType -match 'rate=(\d+)') { $rate = [int]$Matches[1] }
			Write-Wav $path ([Convert]::FromBase64String($part.inlineData.data)) $rate
			"made $id"
			break
		} catch { "failed $id attempt $($attempt): $($_.Exception.Message)"; Start-Sleep -Seconds 4 }
	}
	Start-Sleep -Seconds 2
}

# Idle breathing: pink noise shaped into slow breaths (4 s, a whole number of cycles, so it loops).
$breath = Join-Path $outDir "breath_idle.wav"
if (-not (Test-Path $breath) -and -not (Test-Path ($breath -replace "\.wav$", ".ogg"))) {
	& $ffmpeg -hide_banner -loglevel error -f lavfi -i "anoisesrc=d=4:c=pink:a=0.5:r=22050" `
		-af "highpass=f=180,lowpass=f=1100,volume='0.06+0.94*pow(sin(PI*t/4),6)':eval=frame,volume=0.6" -ac 1 -ar 22050 $breath
	"made breath_idle (ffmpeg)"
}
"done"
