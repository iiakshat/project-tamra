# Generates Hindi/Sanskrit voice lines with Gemini TTS into audio/voice/<id>.wav.
# Lines come from config/story.json ("hi" or "sa" text) and config/voice_lines.json (calls).
# Reads GOOGLE_API_KEY from .env and never prints it. Existing files are skipped, so a
# re-run only requests what is missing; delete a wav to regenerate it.
#
#   powershell -ExecutionPolicy Bypass -File tools\tts_gemini.ps1 [-Only c1_intro_00] [-Model name]

param([string]$Only = "", [string]$Model = "")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "audio\voice"
New-Item -ItemType Directory -Force $outDir | Out-Null

$keyLine = Get-Content (Join-Path $root ".env") | Where-Object { $_ -match '^\s*GOOGLE_API_KEY\s*=' } | Select-Object -First 1
if (-not $keyLine) { throw "GOOGLE_API_KEY missing in .env" }
$key = ($keyLine -split '=', 2)[1].Trim().Trim('"').Trim("'")

$cfg = Get-Content (Join-Path $root "config\voice_lines.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$story = Get-Content (Join-Path $root "config\story.json") -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Model -eq "") { $Model = $cfg.model }

$jobs = New-Object System.Collections.ArrayList
# Walks story beats, including the replies inside choices. The speaker picks the voice;
# "echo" beats (visions) use the speaker's whisper voice when one exists.
function Add-Beats($beats) {
	foreach ($b in $beats) {
		if ($b.options) { foreach ($o in $b.options) { Add-Beats $o.reply }; continue }
		if (-not $b.voice) { continue }
		$role = if ($b.sa) { "chant" } elseif ($b.speaker) { $b.speaker } else { "narrator" }
		if ($b.echo -and $cfg.voices.("$($role)_echo")) { $role = "$($role)_echo" }
		if (-not $cfg.voices.$role) { $role = "narrator" }
		$text = if ($b.sa) { $b.sa } else { $b.hi }
		[void]$jobs.Add(@{ id = $b.voice; text = $text; role = $role })
	}
}
foreach ($story_id in $story.PSObject.Properties) {
	if ($story_id.Name.StartsWith("_")) { continue }
	foreach ($item in $story_id.Value) {
		if ($item.beats) { Add-Beats $item.beats } else { Add-Beats @($item) }
	}
}
foreach ($call in $cfg.calls.PSObject.Properties) {
	$jobs += @{ id = $call.Name; text = $call.Value; role = "hero" }
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

$made = 0
foreach ($job in $jobs) {
	if ($Only -ne "" -and $job.id -ne $Only) { continue }
	$path = Join-Path $outDir "$($job.id).wav"
	if (Test-Path $path) { continue }
	$voice = $cfg.voices.($job.role)
	# A short "Say ...:" prefix is the style cue TTS models are trained on. Longer
	# instructions get read aloud, and system instructions are rejected.
	$body = @{
		contents = @(@{ parts = @(@{ text = "$($voice.style) $($job.text)" }) })
		generationConfig = @{
			responseModalities = @("AUDIO")
			speechConfig = @{ voiceConfig = @{ prebuiltVoiceConfig = @{ voiceName = $voice.voice } } }
		}
	} | ConvertTo-Json -Depth 10
	$uri = "https://generativelanguage.googleapis.com/v1beta/models/$($Model):generateContent"
	$ok = $false
	for ($attempt = 1; $attempt -le 3 -and -not $ok; $attempt++) {
		try {
			$r = Invoke-RestMethod -Method Post -Uri $uri -Headers @{ "x-goog-api-key" = $key } `
				-ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))
			$part = $r.candidates[0].content.parts | Where-Object { $_.inlineData } | Select-Object -First 1
			if (-not $part) { throw "no audio in response" }
			$rate = 24000
			if ($part.inlineData.mimeType -match 'rate=(\d+)') { $rate = [int]$Matches[1] }
			Write-Wav $path ([Convert]::FromBase64String($part.inlineData.data)) $rate
			"made $($job.id) ($($job.role), $rate Hz, $([math]::Round((Get-Item $path).Length / 1KB)) KB)"
			$made++
			$ok = $true
		} catch {
			$code = $null
			if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
			"failed $($job.id) attempt $attempt (HTTP $code): $($_.Exception.Message)"
			if ($code -eq 429) { Start-Sleep -Seconds (20 * $attempt) } elseif ($code -ge 400 -and $code -lt 500) { break } else { Start-Sleep -Seconds 5 }
		}
	}
	Start-Sleep -Seconds 2  # stay gentle with the API
}
"done: $made new file(s)"
