extends SceneTree
## Trims leading and trailing silence from every WAV in audio/voice/ and rewrites each as a
## plain mono 16-bit PCM file (44-byte header). Run after generating voice, then re-import:
##   godot --headless --path . --script res://tools/trim_voice.gd [-- --only=call_udaan --dry=1 --dir=res://audio/vocal/]
##   godot --headless --path . --import
##
## Silence = 10 ms windows whose RMS is below max(-55 dBFS, loudest window - 40 dB).
## 60 ms of the original audio is kept before the first and after the last voiced window,
## with a 5 ms fade at each new edge so the cut never clicks. Files whose .import loops
## (seamless loops such as breath_idle) are left untouched. Re-running is safe: an already
## trimmed file only loses whatever silence is beyond the pad.
##
## It also reports, per file, the voiced bursts separated by gaps of 250 ms or more. A battle
## cry ("call_*") must be one burst and at most 1.4 s long; anything else is flagged
## DOUBLE/LONG so it can be regenerated.

const DEFAULT_DIR := "res://audio/voice/"
const WINDOW_S := 0.010
const PAD_S := 0.060
const FADE_S := 0.005
const ABS_FLOOR_DB := -55.0
const REL_FLOOR_DB := -40.0
const GAP_S := 0.25
const CALL_MAX_S := 1.4

var _flagged := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var only := str(args.get("only", ""))
	var dry := str(args.get("dry", "0")) == "1"
	var dir := str(args.get("dir", DEFAULT_DIR))
	if not dir.ends_with("/"):
		dir += "/"
	var files := DirAccess.get_files_at(dir)
	var count := 0
	for f in files:
		if not f.ends_with(".wav"):
			continue
		if only != "" and f.get_basename() != only:
			continue
		_trim_file(dir + f, dry)
		count += 1
	print("trim_voice: %d file(s)%s, %d flagged" % [count, " (dry run)" if dry else "", _flagged])
	quit(0)


func _trim_file(path: String, dry: bool) -> void:
	var name := path.get_file().get_basename()
	if _is_loop(path):
		print("  %-16s loop, skipped" % name)
		return
	var wav := read_wav(ProjectSettings.globalize_path(path))
	if wav.is_empty():
		push_error("trim_voice: cannot read %s" % path)
		return
	var rate: int = wav["rate"]
	var s: PackedFloat32Array = wav["samples"]
	var before := float(s.size()) / rate
	var win := maxi(1, int(rate * WINDOW_S))
	var n := s.size() / win
	var db := PackedFloat32Array()
	db.resize(n)
	var loudest := -200.0
	for w in n:
		var acc := 0.0
		for i in range(w * win, (w + 1) * win):
			acc += s[i] * s[i]
		db[w] = 10.0 * log(acc / win + 1e-20) / log(10.0)
		loudest = maxf(loudest, db[w])
	var floor_db := maxf(ABS_FLOOR_DB, loudest + REL_FLOOR_DB)
	var first := -1
	var last := -1
	var bursts: Array = []
	var gap := 0
	for w in n:
		if db[w] >= floor_db:
			if first < 0:
				first = w
				bursts.append([w, w + 1])
			elif gap * WINDOW_S >= GAP_S:
				bursts.append([w, w + 1])
			else:
				bursts[-1][1] = w + 1
			last = w
			gap = 0
		else:
			gap += 1
	if first < 0:
		print("  %-16s silent?! left untouched" % name)
		_flagged += 1
		return
	var pad := int(rate * PAD_S)
	var a := maxi(0, first * win - pad)
	var b := mini(s.size(), (last + 1) * win + pad)
	var out := s.slice(a, b)
	var fade := int(rate * FADE_S)
	if a > 0:
		for i in mini(fade, out.size()):
			out[i] *= float(i) / fade
	if b < s.size():
		for i in mini(fade, out.size()):
			out[out.size() - 1 - i] *= float(i) / fade
	var after := float(out.size()) / rate
	var desc := PackedStringArray()
	for bu in bursts:
		desc.append("%.2f-%.2f" % [bu[0] * WINDOW_S, bu[1] * WINDOW_S])
	var flag := ""
	if name.begins_with("call_"):
		if bursts.size() > 1:
			flag += " DOUBLE"
		if after > CALL_MAX_S:
			flag += " LONG"
	if flag != "":
		_flagged += 1
	print("  %-16s %5.2f s -> %5.2f s  %d Hz  bursts %s%s" % [name, before, after, rate, " ".join(desc), flag])
	if not dry:
		write_wav(ProjectSettings.globalize_path(path), out, rate)


func _is_loop(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(ProjectSettings.globalize_path(path + ".import")) != OK:
		return false
	return int(cfg.get_value("params", "edit/loop_mode", 0)) != 0


## Reads any PCM WAV (8/16/24/32-bit int or 32-bit float, any channel count) as mono floats.
static func read_wav(abs_path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(abs_path)
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return {}
	var pos := 12
	var fmt := 0
	var channels := 1
	var rate := 0
	var bits := 16
	var data := PackedByteArray()
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		var body := pos + 8
		if id == "fmt ":
			fmt = bytes.decode_u16(body)
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
			if fmt == 0xFFFE:  # WAVE_FORMAT_EXTENSIBLE: real format is in the sub-format GUID
				fmt = bytes.decode_u16(body + 24)
		elif id == "data":
			# Streamed WAVs sometimes carry a placeholder size; clamp to what is there.
			data = bytes.slice(body, mini(bytes.size(), body + size))
		pos = body + size + (size & 1)
	if rate <= 0 or data.is_empty():
		return {}
	var step := bits / 8
	var frames := data.size() / (step * channels)
	var out := PackedFloat32Array()
	out.resize(frames)
	for f in frames:
		var acc := 0.0
		for c in channels:
			var o := (f * channels + c) * step
			if fmt == 3 and bits == 32:
				acc += data.decode_float(o)
			elif bits == 16:
				acc += data.decode_s16(o) / 32768.0
			elif bits == 24:
				var v := data[o] | (data[o + 1] << 8) | (data[o + 2] << 16)
				if v & 0x800000:
					v -= 0x1000000
				acc += v / 8388608.0
			elif bits == 32:
				acc += data.decode_s32(o) / 2147483648.0
			else:
				acc += (data[o] - 128) / 128.0
		out[f] = acc / channels
	return {"rate": rate, "samples": out}


static func write_wav(abs_path: String, s: PackedFloat32Array, rate: int) -> void:
	var pcm := PackedByteArray()
	pcm.resize(s.size() * 2)
	for i in s.size():
		pcm.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + pcm.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(rate)
	f.store_32(rate * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	f.close()
