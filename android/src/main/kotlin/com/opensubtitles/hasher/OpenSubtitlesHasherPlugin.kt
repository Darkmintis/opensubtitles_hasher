package com.opensubtitles.hasher

import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.opensubtitles.hasher.hash.HashCalculator
import com.opensubtitles.hasher.picker.MoviePicker
import com.opensubtitles.hasher.picker.MoviePickerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin entry: method channel + activity-aware movie picker.
 */
class OpenSubtitlesHasherPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: android.content.Context
    private val mainHandler = Handler(Looper.getMainLooper())

    private val moviePicker = MoviePicker { context }

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
    ) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "opensubtitles_hasher",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "pickMovie" -> {
                val options = MoviePickerOptions.fromChannelArgs(
                    call.arguments as? Map<*, *>,
                )
                moviePicker.pick(options, result)
            }
            "computeHash" -> {
                val uriString = call.argument<String>("uri")
                if (uriString.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "uri is required", null)
                    return
                }

                HashCalculator.computeAsync(
                    context = context,
                    uri = Uri.parse(uriString),
                    onSuccess = { payload ->
                        mainHandler.post { result.success(payload) }
                    },
                    onError = { code, message ->
                        mainHandler.post { result.error(code, message, null) }
                    },
                )
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(
        @NonNull binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        moviePicker.attachActivity(binding)
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding,
    ) {
        moviePicker.attachActivity(binding)
    }

    override fun onDetachedFromActivity() {
        moviePicker.detachActivity()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        moviePicker.detachActivity()
    }
}
