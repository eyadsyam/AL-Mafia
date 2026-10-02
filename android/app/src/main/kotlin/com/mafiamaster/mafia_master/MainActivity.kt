package com.mafiamaster.mafia_master

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setLanguage") {
                    result.success(requestLauncherLanguage(call.arguments as? String))
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Records the launcher label the player wants and applies it only if that
     * cannot close the running game.
     *
     * Disabling an activity-alias finishes every activity that was started
     * through it, DONT_KILL_APP or not: the task's root was launched as that
     * alias. Switching the label from inside the running game is what made a
     * language change "exit" the app. So a switch that would disable the alias
     * this activity came in through is left pending and applied from
     * [onDestroy], when no screen of ours is left to close.
     *
     * Returns "applied" when the label already matches or was switched safely,
     * "pending" when it will change after the game is closed, "failed" when
     * the platform refused. Cosmetic: never throws.
     */
    private fun requestLauncherLanguage(code: String?): String {
        val wanted = if (code == "en") "en" else "ar"
        return try {
            prefs().edit().putString(PENDING_KEY, wanted).apply()
            val (target, other) = aliases(wanted)
            val pm = packageManager
            if (isEnabled(pm, target) && !isEnabled(pm, other)) {
                prefs().edit().remove(PENDING_KEY).apply()
                return "applied"
            }
            if (launchedThrough(other)) return "pending"
            applyAliases(pm, target, other)
            prefs().edit().remove(PENDING_KEY).apply()
            "applied"
        } catch (e: Exception) {
            "failed"
        }
    }

    override fun onDestroy() {
        // A configuration change recreates this activity at once; the task is
        // still on screen, so nothing may be disabled yet.
        val closing = !isChangingConfigurations
        super.onDestroy()
        if (closing) applyPending()
    }

    private fun applyPending() {
        try {
            val wanted = prefs().getString(PENDING_KEY, null) ?: return
            val (target, other) = aliases(wanted)
            applyAliases(packageManager, target, other)
            prefs().edit().remove(PENDING_KEY).apply()
        } catch (e: Exception) {
            // Kept pending; the next safe moment tries again.
        }
    }

    /**
     * The new alias is enabled before the old one is disabled, so an
     * interruption leaves two launcher entries rather than none.
     */
    private fun applyAliases(pm: PackageManager, target: ComponentName, other: ComponentName) {
        if (!isEnabled(pm, target)) {
            pm.setComponentEnabledSetting(
                target,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        if (isEnabled(pm, other)) {
            pm.setComponentEnabledSetting(
                other,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    // Alias names come from the namespace, which is not the package name in
    // the `.adstest` build.
    private fun aliases(code: String): Pair<ComponentName, ComponentName> {
        val arabic = ComponentName(packageName, "$NAMESPACE.LauncherArabic")
        val english = ComponentName(packageName, "$NAMESPACE.LauncherEnglish")
        return if (code == "en") english to arabic else arabic to english
    }

    private fun launchedThrough(alias: ComponentName): Boolean =
        intent?.component?.className == alias.className

    private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun isEnabled(pm: PackageManager, component: ComponentName): Boolean =
        when (pm.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT ->
                // Manifest default: Arabic enabled, English disabled.
                component.className.endsWith(".LauncherArabic")
            else -> false
        }

    companion object {
        private const val CHANNEL = "mafia_master/launcher"
        private const val NAMESPACE = "com.mafiamaster.mafia_master"
        private const val PREFS = "launcher_label"
        private const val PENDING_KEY = "pending_language"
    }
}
