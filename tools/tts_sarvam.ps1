# Generates the hero's Hindi battle cries with Sarvam Bulbul TTS into audio/voice/<id>.wav.
# Lines and voice settings come from config/voice_lines.json ("calls" + "sarvam").
# Reads SARVAM_API_KEY from .env and never prints it. Existing files are skipped, so a
# re-run only requests what is missing; delete a wav to regenerate it.
#
# The key is shared with another project, so this script is deliberately slow and stingy:
# strictly sequential, at least 10 s between requests, no retries, at most -Max requests per
# run, and it stops calling Sarvam entirely on the first HTTP 429.
# Afterwards: run tools/trim_voice.gd, re-import, and verify with tools/tts_check.ps1.
#
#   powershell -ExecutionPolicy Bypass -File tools\tts_sarvam.ps1 [-Only call_kavach] [-Max 8] [-EnvFile path\to\.env]

param([string]$Only = "", [int]$Max = 8, [string]$EnvFile = "")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "audio\voice"
New-Item -ItemType Directory -Force $outDir | Out-Null

if ($EnvFile -eq "") { $EnvFile = Join-Path $root ".env" }
$keyLine = Get-Content $EnvFile | Where-Object { $_ -match '^\s*SARVAM_API_KEY\s*=' } | Select-Object -First 1
if (-not $keyLine) { throw "SARVAM_API_KEY missing in $EnvFile" }
$key = ($keyLine -split '=', 2)[1].Trim().Trim('"').Trim("'")

$cfg = Get-Content (Join-Path $root "config\voice_lines.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$sv = $cfg.sarvam

$sent = 0
$made = 0
foreach ($call in $cfg.calls.PSObject.Properties) {
	$id = $call.Name
	if ($Only -ne "" -and $id -ne $Only) { continue }
	$path = Join-Path $outDir "$id.wav"
	if ((Test-Path $path) -or (Test-Path ($path -replace ".wav$", ".ogg"))) { continue }
	if ($sent -ge $Max) { "request cap ($Max) reached; $id not generated"; break }
	if ($sent -gt 0) { Start-Sleep -Seconds $sv.min_gap_seconds }
	$body = @{
		text = $call.Value
		language_code = $sv.language_code
		model = $sv.model
		speaker = $sv.speaker
		pace = $sv.pace
		temperature = $sv.temperature
		speech_sample_rate = $sv.sample_rate
		output_audio_codec = "wav"
	} | ConvertTo-Json -Depth 5
	$sent++
	try {
		$r = Invoke-RestMethod -Method Post -Uri "https://api.sarvam.ai/text-to-speech" `
			-Headers @{ "api-subscription-key" = $key } -ContentType "application/json; charset=utf-8" `
			-Body ([Text.Encoding]::UTF8.GetBytes($body))
		if (-not $r.audios -or $r.audios.Count -lt 1) { throw "no audio in response" }
		[IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($r.audios[0]))
		"made $id ($($sv.model)/$($sv.speaker), $([math]::Round((Get-Item $path).Length / 1KB)) KB)"
		$made++
	} catch {
		$code = $null
		if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
		"failed $id (HTTP $code): $($_.Exception.Message)"
		if ($code -eq 429) { "HTTP 429: stopping all Sarvam requests for this run"; break }
		if ($code -eq 401 -or $code -eq 403) { "auth/permission error: stopping"; break }
	}
}
"done: $made new file(s), $sent request(s) sent"
