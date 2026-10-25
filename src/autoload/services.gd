extends Node
## Platform services. Game code calls these interfaces and never touches an SDK
## directly, so analytics, ads and storage can be swapped or disabled in one place.

var storage: StorageService
var analytics: AnalyticsService
var ads: AdsService


func _init() -> void:
	storage = FileStorage.new("user://")
	analytics = DebugAnalytics.new()
	ads = AdsService.new()  # No ads until a real SDK is added behind this interface.
