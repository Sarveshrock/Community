package com.communeo.app.community_app

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Backs Settings > Appearance > App Icon. Android has no runtime API to
 * change one launcher icon's *image* — only to enable/disable which of
 * several manifest-declared components (MainActivity + the activity-alias
 * entries in AndroidManifest.xml, each with its own `android:icon`) is
 * currently the app's active launcher entry point. Exactly one is ever
 * enabled at a time; switching styles disables all the others and enables
 * the chosen one via [PackageManager.setComponentEnabledSetting].
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.communeo.app/app_icon"

    // Keys match `kAppIconStyles` on the Dart side exactly.
    private val aliasByStyle = mapOf(
        "classic" to "com.communeo.app.community_app.MainActivity",
        "dark" to "com.communeo.app.community_app.AppIconDark",
        "minimal" to "com.communeo.app.community_app.AppIconMinimal",
        "neon" to "com.communeo.app.community_app.AppIconNeon",
        "gradient" to "com.communeo.app.community_app.AppIconGradient",
        "glass" to "com.communeo.app.community_app.AppIconGlass",
        "developer" to "com.communeo.app.community_app.AppIconDeveloper",
        "gaming" to "com.communeo.app.community_app.AppIconGaming",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAppIcon" -> {
                    val style = call.argument<String>("style")
                    val target = aliasByStyle[style]
                    if (target == null) {
                        result.error("UNKNOWN_STYLE", "No such app icon style: $style", null)
                    } else {
                        applyIcon(target)
                        result.success(true)
                    }
                }
                "getActiveAppIcon" -> result.success(currentActiveStyle())
                else -> result.notImplemented()
            }
        }
    }

    private fun applyIcon(targetComponent: String) {
        val pm = packageManager
        for ((_, component) in aliasByStyle) {
            val state = if (component == targetComponent) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            // DONT_KILL_APP: this runs while the app is in the foreground
            // switching its own icon — restarting the process would be a
            // jarring, unnecessary UX regression for what should feel instant.
            pm.setComponentEnabledSetting(ComponentName(packageName, component), state, PackageManager.DONT_KILL_APP)
        }
    }

    private fun currentActiveStyle(): String? {
        val pm = packageManager
        for ((style, component) in aliasByStyle) {
            val setting = pm.getComponentEnabledSetting(ComponentName(packageName, component))
            val isEnabled = setting == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                (setting == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && component.endsWith("MainActivity"))
            if (isEnabled) return style
        }
        return "classic"
    }
}
