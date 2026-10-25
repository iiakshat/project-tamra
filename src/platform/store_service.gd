class_name StoreService
extends RefCounted
## In-app purchase interface. The base class sells nothing and reports the store as
## unavailable, so premium items show as "coming soon". A Google Play Billing subclass
## replaces it later without touching game code. Cosmetics only: power is never sold.

signal purchase_finished(product_id: String, ok: bool)


func is_available() -> bool:
	return false


func buy(product_id: String) -> void:
	purchase_finished.emit(product_id, false)
