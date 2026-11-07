class_name AgeGate
extends RefCounted
## A neutral age screen (Google Play's Families guidance): ask for a birth year without
## hinting at the answer that unlocks something, keep only "13 or older: ok/under", and
## never share play data unless the age is ok and the player agreed.
## The year alone cannot tell whether someone has had their birthday, so it leans cautious:
## only a birth year of at least 14 years ago counts as certainly 13 or older.

const MIN_YEAR := 1920
const START_YEAR := 2000  # where the picker opens; deliberately not near the cut-off


static func clamp_year(year: int, current_year: int) -> int:
	return clampi(year, MIN_YEAR, current_year)


static func is_13_or_older(birth_year: int, current_year: int) -> bool:
	return birth_year <= current_year - 14


## The state that is stored: "ok" or "under". The birth year itself is never kept.
static func state_for(birth_year: int, current_year: int) -> String:
	return "ok" if is_13_or_older(clamp_year(birth_year, current_year), current_year) else "under"


## Play data may be shared only when the age is ok and the player said yes.
## `age_state` is "ask", "ok" or "under"; `consent` is "ask", "yes" or "no".
static func sharing_allowed(age_state: String, consent: String) -> bool:
	return age_state == "ok" and consent == "yes"
