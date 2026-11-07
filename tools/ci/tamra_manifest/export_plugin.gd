@tool
extends EditorPlugin
## Release-build only (installed by tools/ci/install_firebase.sh). Firebase Analytics pulls in the
## advertising ID permissions; Tamra never reads the advertising ID and denies ad storage, so the
## permissions are removed from the final manifest. That lets the Play Console "Advertising ID"
## question be answered No, and matches the privacy policy.

var _export_plugin: TamraManifestExport


func _enter_tree() -> void:
	_export_plugin = TamraManifestExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin:
		remove_export_plugin(_export_plugin)
		_export_plugin = null


class TamraManifestExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "Tamra manifest"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_manifest_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		print("[Tamra] Removing advertising ID permissions from the manifest")
		return '<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />\n<uses-permission android:name="android.permission.ACCESS_ADSERVICES_AD_ID" tools:node="remove" />\n'
