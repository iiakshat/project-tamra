extends Node
## Platform services. Game code calls these interfaces and never touches an SDK
## directly, so analytics, ads and storage can be swapped or disabled in one place.

var storage: StorageService
var analytics: AnalyticsService
var ads: AdsService
var store: StoreService


func _init() -> void:
	storage = FileStorage.new("user://")
	# Local log always; Firebase only when the release build carries the plugin (and the
	# player has agreed, see Game.set_analytics_consent).
	analytics = FirebaseAnalytics.create(DebugAnalytics.new())
	ads = AdsService.new()  # No ads until a real SDK is added behind this interface.
	store = StoreService.new()  # No purchases until Play Billing is added behind this.
