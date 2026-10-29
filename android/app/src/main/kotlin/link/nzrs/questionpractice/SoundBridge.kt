package link.nzrs.questionpractice

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SoundBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "link.nzrs.questionpractice/sounds"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val soundPool: SoundPool = SoundPool.Builder()
        .setMaxStreams(3)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        .build()
    private val sounds = mapOf(
        "correct" to soundPool.load(context, R.raw.practice_correct, 1),
        "wrong" to soundPool.load(context, R.raw.practice_wrong, 1),
        "finished" to soundPool.load(context, R.raw.practice_finished, 1),
    )

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "play") {
            result.notImplemented()
            return
        }
        val sound = call.argument<String>("sound")
        val id = sounds[sound]
        if (id == null) {
            result.success(false)
            return
        }
        soundPool.play(id, 0.85f, 0.85f, 1, 0, 1f)
        result.success(true)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        soundPool.release()
    }
}
