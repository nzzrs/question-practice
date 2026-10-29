package link.nzrs.questionpractice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ankiBridge: AnkiBridge? = null
    private var soundBridge: SoundBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ankiBridge = AnkiBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        soundBridge = SoundBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        ankiBridge?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        ankiBridge?.dispose()
        ankiBridge = null
        soundBridge?.dispose()
        soundBridge = null
        super.onDestroy()
    }
}
