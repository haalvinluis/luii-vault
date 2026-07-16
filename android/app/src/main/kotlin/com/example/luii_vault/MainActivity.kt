package com.example.luii_vault

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.MediaStore
import android.content.ContentResolver
import android.database.Cursor
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.luii_vault/media_query"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "queryAudioFiles") {
                val audioList = queryAudioFiles()
                result.success(audioList)
            } else if (call.method == "getSDKVersion") {
                result.success(android.os.Build.VERSION.SDK_INT)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun queryAudioFiles(): List<Map<String, Any>> {
        val audioList = mutableListOf<Map<String, Any>>()
        val contentResolver: ContentResolver = contentResolver
        val uri: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATA
        )

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val cursor: Cursor? = contentResolver.query(uri, projection, selection, null, null)

        if (cursor != null) {
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val title = cursor.getString(titleColumn) ?: "Unknown Title"
                val artist = cursor.getString(artistColumn) ?: "Unknown Artist"
                val album = cursor.getString(albumColumn) ?: "Unknown Album"
                val duration = cursor.getLong(durationColumn)
                val size = cursor.getLong(sizeColumn)
                val data = cursor.getString(dataColumn) ?: ""

                val lowerData = data.lowercase()
                if (lowerData.endsWith(".mp3") || lowerData.endsWith(".wav") || 
                    lowerData.endsWith(".m4a") || lowerData.endsWith(".ogg") || 
                    lowerData.endsWith(".aac") || lowerData.endsWith(".flac")) {
                    
                    val audioMap = mapOf(
                        "id" to id.toString(),
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "duration" to duration,
                        "size" to size,
                        "path" to data
                    )
                    audioList.add(audioMap)
                }
            }
            cursor.close()
        }
        return audioList
    }
}
