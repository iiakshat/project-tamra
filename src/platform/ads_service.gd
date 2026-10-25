class_name AdsService
extends RefCounted
## Rewarded-ads interface. Opt-in only: the player chooses to watch for a bonus.
## The base class has no ads and always reports them unavailable, so every part of
## the game must work without them.

signal rewarded_finished(placement: String, rewarded: bool)


func is_rewarded_ready(_placement: String) -> bool:
	return false


func show_rewarded(placement: String) -> void:
	rewarded_finished.emit(placement, false)
