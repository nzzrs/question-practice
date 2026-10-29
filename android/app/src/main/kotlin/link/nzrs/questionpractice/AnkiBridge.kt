package link.nzrs.questionpractice

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.ichi2.anki.FlashCardsContract
import com.ichi2.anki.api.AddContentApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService

class AnkiBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "link.nzrs.questionpractice/anki"
        private const val PERMISSION_REQUEST = 4107
        private const val ANKI_PACKAGE = "com.ichi2.anki"
        private const val ERROR_MODEL = "Question Practice: Error"
        private const val BASIC_MODEL = "Question Practice Basic"
        private val ERROR_FIELDS = arrayOf(
            "Problem",
            "Wrong Solution",
            "Correct Solution",
            "Mental Trap",
            "Vaccine",
            "Explanation",
        )
        private const val ERROR_QUESTION_FORMAT = """
            <div class="field-container">
              <div class="field-label">Problem:</div>
              <div class="field-content">{{Problem}}</div>
            </div>

            <div class="field-container wrong">
              <div class="field-label">Wrong answer chosen:</div>
              <div class="field-content">{{Wrong Solution}}</div>
            </div>

            <div class="prompt-action">
              What was the <strong>flawed assumption</strong>?
            </div>
        """
        private const val ERROR_ANSWER_FORMAT = """
            {{FrontSide}}

            <hr id="answer">

            {{#Mental Trap}}
            <div class="field-container trap">
              <div class="field-label">Flawed Assumption (Bias):</div>
              <div class="field-content">{{Mental Trap}}</div>
            </div>
            {{/Mental Trap}}

            <div class="reference-box">
              {{#Vaccine}}
              <div class="field-container vaccine">
                <div class="field-label">Vaccine (Rule / Protocol):</div>
                <div class="field-content">{{Vaccine}}</div>
              </div>
              {{/Vaccine}}

              <div class="field-container correct">
                <div class="field-label">Correct solution:</div>
                <div class="field-content">{{Correct Solution}}</div>
              </div>

              {{#Explanation}}
              <div class="field-container explanation">
                <div class="field-label">Distractor analysis / Explanation:</div>
                <div class="field-content">{{Explanation}}</div>
              </div>
              {{/Explanation}}
            </div>
        """
        private const val ERROR_CSS = """
            .card {
              font-family: "Cascadia Code", "Consolas", "Segoe UI", monospace, sans-serif;
              text-align: center;
              color: #E0E0E0;
              background-color: #0D1117;
              display: flex;
              flex-direction: column;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              margin: 0;
              padding: 30px 15px;
              box-sizing: border-box;
            }

            .field-container {
              margin: 12px auto 0 auto;
              text-align: left;
              width: 100%;
              max-width: 650px;
              border-radius: 6px;
              padding: 14px 18px;
              border: 1px solid #30363d;
              background-color: #161b22;
              box-sizing: border-box;
            }

            .field-label {
              font-size: 11px;
              font-weight: 700;
              letter-spacing: 1px;
              margin-bottom: 6px;
              text-transform: uppercase;
            }

            .field-content {
              font-size: 16px;
              line-height: 1.5;
            }

            .wrong {
              background-color: #211515;
              border-left: 4px solid #f85149;
            }
            .wrong .field-label { color: #f85149; }

            .trap {
              background-color: #261c14;
              border-left: 4px solid #db6d28;
            }
            .trap .field-label { color: #db6d28; }

            .reference-box {
              width: 100%;
              max-width: 650px;
              margin-top: 10px;
              opacity: 0.85;
            }

            .vaccine {
              background-color: #1c1427;
              border-left: 4px solid #ab47bc;
            }
            .vaccine .field-label { color: #ab47bc; }

            .correct {
              background-color: #132316;
              border-left: 4px solid #3fb950;
            }
            .correct .field-label { color: #3fb950; }

            .explanation {
              background-color: #161b22;
              border-left: 4px solid #58a6ff;
            }
            .explanation .field-label { color: #58a6ff; }
            .explanation .field-content { font-size: 14px; }

            .prompt-action {
              color: #8b949e;
              font-size: 14px;
              margin: 25px auto 5px auto;
              text-align: left;
              width: 100%;
              max-width: 650px;
              padding: 0 4px;
            }

            .prompt-action strong { color: #c9d1d9; }

            #answer {
              display: block;
              border: 0;
              border-top: 1px solid #30363d;
              width: 100%;
              max-width: 650px;
              margin: 25px auto 15px auto;
            }
        """
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(statusMap())
            "requestPermission" -> requestPermission(result)
            "deckNames" -> result.success(deckNames())
            "importNotes" -> importNotes(call, result)
            "triggerSync" -> {
                triggerSync()
                result.success(null)
            }
            "openAnkiDroid" -> result.success(openAnkiDroid())
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        val pending = pendingPermissionResult
        pendingPermissionResult = null
        pending?.success(statusMap())
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(statusMap())
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_pending", "A permission request is already open.", null)
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(
            arrayOf(AddContentApi.READ_WRITE_PERMISSION),
            PERMISSION_REQUEST,
        )
    }

    private fun importNotes(call: MethodCall, result: MethodChannel.Result) {
        val rawNotes = call.argument<List<Map<String, Any?>>>("notes") ?: emptyList()
        if (rawNotes.isEmpty()) {
            result.success(
                mapOf(
                    "added" to 0,
                    "failed" to 0,
                    "message" to "No cards selected.",
                ),
            )
            return
        }
        if (!hasPermission()) {
            result.success(
                mapOf(
                    "added" to 0,
                    "failed" to rawNotes.size,
                    "message" to "AnkiDroid database permission was not granted.",
                ),
            )
            return
        }
        executor.execute {
            val response = try {
                doImport(rawNotes)
            } catch (error: Exception) {
                mapOf(
                    "added" to 0,
                    "failed" to rawNotes.size,
                    "message" to (error.message ?: "AnkiDroid import failed."),
                )
            }
            activity.runOnUiThread { result.success(response) }
        }
    }

    private fun doImport(
        rawNotes: List<Map<String, Any?>>,
    ): Map<String, Any> {
        val api = AddContentApi(activity)

        val cloze = findClozeModel()
            ?: return mapOf(
                "added" to 0,
                "failed" to rawNotes.size,
                "message" to "AnkiDroid has no Cloze note type.",
            )
        val errorModel = ensureErrorModel(api)
            ?: return mapOf(
                "added" to 0,
                "failed" to rawNotes.size,
                "message" to "Could not create the error note type.",
            )
        val basicModel = ensureBasicModel(api)
            ?: return mapOf(
                "added" to 0,
                "failed" to rawNotes.size,
                "message" to "Could not create the basic note type.",
            )

        val byDeck = rawNotes.groupBy {
            (it["deckName"] as? String)?.trim().takeUnless { name -> name.isNullOrEmpty() }
                ?: "Question Practice"
        }
        var added = 0
        var failed = 0
        var firstError: String? = null

        for ((deckName, deckNotes) in byDeck) {
            val deckId = ensureDeck(api, deckName)
            if (deckId == null) {
                failed += deckNotes.size
                firstError = firstError ?: "Could not create the AnkiDroid deck \"$deckName\"."
                continue
            }
            val grouped = deckNotes.groupBy { (it["model"] as? String) ?: "basic" }
            for ((modelName, notes) in grouped) {
                val modelId: Long
                val fieldCount: Int
                when (modelName) {
                    "concept" -> {
                        modelId = cloze.id
                        fieldCount = cloze.fieldNames.size
                    }
                    "error" -> {
                        modelId = errorModel
                        fieldCount = ERROR_FIELDS.size
                    }
                    else -> {
                        modelId = basicModel
                        fieldCount = 2
                    }
                }
                val fieldsList = ArrayList<Array<String>>(notes.size)
                val tagsList = ArrayList<Set<String>>(notes.size)
                for (note in notes) {
                    val rawFields = (note["fields"] as? List<*>)?.map { it?.toString() ?: "" }
                        ?: emptyList()
                    val fields = Array(fieldCount) { index -> rawFields.getOrElse(index) { "" } }
                    val rawTags = (note["tags"] as? List<*>)?.mapNotNull { it?.toString() }
                        ?: emptyList()
                    fieldsList.add(fields)
                    tagsList.add(rawTags.toSet())
                }
                val count = try {
                    api.addNotes(modelId, deckId, fieldsList, tagsList)
                } catch (error: Exception) {
                    firstError = firstError ?: (error.message ?: "AnkiDroid rejected a note.")
                    -1
                }
                if (count < 0) {
                    failed += notes.size
                } else {
                    added += count
                    failed += (notes.size - count).coerceAtLeast(0)
                }
            }
        }

        return mapOf(
            "added" to added,
            "failed" to failed,
            "message" to when {
                added == 0 -> firstError ?: "AnkiDroid rejected the cards."
                failed == 0 -> "$added cards sent to AnkiDroid."
                else -> "$added cards added, $failed rejected."
            },
        )
    }

    private fun deckNames(): List<String> {
        if (!hasPermission()) return emptyList()
        return try {
            AddContentApi(activity).deckList?.values?.sorted() ?: emptyList()
        } catch (error: Exception) {
            emptyList()
        }
    }

    private fun ensureDeck(api: AddContentApi, deckName: String): Long? {
        val existing = api.deckList?.entries?.firstOrNull { it.value == deckName }
        if (existing != null) return existing.key
        return api.addNewDeck(deckName)
    }

    private fun ensureErrorModel(api: AddContentApi): Long? {
        val existing = api.modelList?.entries?.firstOrNull { it.value == ERROR_MODEL }
        if (existing != null) return existing.key
        return api.addNewCustomModel(
            ERROR_MODEL,
            ERROR_FIELDS,
            arrayOf("Card 1"),
            arrayOf(ERROR_QUESTION_FORMAT.trimIndent()),
            arrayOf(ERROR_ANSWER_FORMAT.trimIndent()),
            ERROR_CSS.trimIndent(),
            null,
            0,
        )
    }

    private fun ensureBasicModel(api: AddContentApi): Long? {
        val existing = api.modelList?.entries?.firstOrNull { it.value == BASIC_MODEL }
        if (existing != null) return existing.key
        return api.addNewBasicModel(BASIC_MODEL)
    }

    private fun findClozeModel(): ClozeModel? {
        val resolver = activity.contentResolver
        val projection = arrayOf(
            FlashCardsContract.Model._ID,
            FlashCardsContract.Model.NAME,
            FlashCardsContract.Model.TYPE,
            FlashCardsContract.Model.FIELD_NAMES,
        )
        val cursor = resolver.query(
            FlashCardsContract.Model.CONTENT_URI,
            projection,
            null,
            null,
            null,
        ) ?: return null
        return try {
            while (cursor.moveToNext()) {
                val type = cursor.getLong(cursor.getColumnIndexOrThrow(FlashCardsContract.Model.TYPE))
                if (type != 1L) continue
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(FlashCardsContract.Model._ID))
                val name = cursor.getString(cursor.getColumnIndexOrThrow(FlashCardsContract.Model.NAME))
                val fields = cursor.getString(
                    cursor.getColumnIndexOrThrow(FlashCardsContract.Model.FIELD_NAMES),
                )
                val fieldNames = if (fields.isNullOrEmpty()) {
                    arrayOf("Text")
                } else {
                    fields.split('\u001f').toTypedArray()
                }
                if (name.equals("Cloze", ignoreCase = true)) {
                    return ClozeModel(id, fieldNames)
                }
                if (fieldNames.isNotEmpty()) {
                    return ClozeModel(id, fieldNames)
                }
            }
            null
        } finally {
            cursor.close()
        }
    }

    private fun statusMap(): Map<String, Any> {
        val installed = isInstalled()
        val apiAvailable = try {
            installed &&
                AddContentApi.getAnkiDroidPackageName(activity) != null &&
                AddContentApi(activity).apiHostSpecVersion > 0
        } catch (error: Exception) {
            false
        }
        val permission = hasPermission()
        var deckExists = false
        var conceptModel = false
        var errorModel = false
        var basicModel = false
        if (installed && apiAvailable && permission) {
            try {
                val api = AddContentApi(activity)
                deckExists = api.deckList?.values?.any { it == "Question Practice" } == true
                conceptModel = findClozeModel() != null
                errorModel = api.modelList?.values?.any { it == ERROR_MODEL } == true
                basicModel = api.modelList?.values?.any { it == BASIC_MODEL } == true
            } catch (error: Exception) {
                // The status map reports what could be read; failures stay false.
            }
        }
        return mapOf(
            "installed" to installed,
            "apiAvailable" to apiAvailable,
            "permissionGranted" to permission,
            "deckExists" to deckExists,
            "conceptModelAvailable" to conceptModel,
            "errorModelAvailable" to errorModel,
            "basicModelAvailable" to basicModel,
        )
    }

    private fun isInstalled(): Boolean {
        return try {
            activity.packageManager.getPackageInfo(ANKI_PACKAGE, 0) != null
        } catch (error: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun hasPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            activity.checkSelfPermission(AddContentApi.READ_WRITE_PERMISSION) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun triggerSync() {
        val intent = Intent("com.ichi2.anki.DO_SYNC").apply {
            setPackage(ANKI_PACKAGE)
        }
        activity.sendBroadcast(intent)
    }

    private fun openAnkiDroid(): Boolean {
        val intent = activity.packageManager.getLaunchIntentForPackage(ANKI_PACKAGE) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
        return true
    }

    private data class ClozeModel(val id: Long, val fieldNames: Array<String>)
}
