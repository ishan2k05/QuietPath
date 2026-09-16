package com.example.quietpath_flutter

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import kotlin.math.log10
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val COMPASS_CHANNEL = "com.quietpath/compass"
    private val NOISE_METER_CHANNEL = "com.quietpath/noise_meter"

    private var sensorManager: SensorManager? = null
    private var rotationSensor: Sensor? = null
    private var sensorListener: SensorEventListener? = null

    private var isRecording = false
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Compass Azimuth Channel
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        rotationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensorManager?.getDefaultSensor(Sensor.TYPE_ORIENTATION)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, COMPASS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (sensorManager == null || rotationSensor == null) {
                        events?.success(0.0)
                        return
                    }

                    var lastAzimuth = -1.0
                    var lastCompassEmitMs = 0L

                    sensorListener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent?) {
                            if (event == null) return
                            var azimuth = 0.0
                            if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
                                val rotationMatrix = FloatArray(9)
                                SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                                val orientation = FloatArray(3)
                                SensorManager.getOrientation(rotationMatrix, orientation)
                                azimuth = Math.toDegrees(orientation[0].toDouble())
                                if (azimuth < 0) azimuth += 360.0
                            } else if (event.sensor.type == Sensor.TYPE_ORIENTATION) {
                                azimuth = event.values[0].toDouble()
                                if (azimuth < 0) azimuth += 360.0
                            }

                            val now = System.currentTimeMillis()
                            if (now - lastCompassEmitMs >= 100 && (lastAzimuth < 0.0 || kotlin.math.abs(azimuth - lastAzimuth) >= 1.0)) {
                                lastCompassEmitMs = now
                                lastAzimuth = azimuth
                                events?.success(azimuth)
                            }
                        }

                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                    }

                    sensorManager?.registerListener(
                        sensorListener,
                        rotationSensor,
                        SensorManager.SENSOR_DELAY_UI
                    )
                }

                override fun onCancel(arguments: Any?) {
                    sensorListener?.let {
                        sensorManager?.unregisterListener(it)
                        sensorListener = null
                    }
                }
            })

        // 2. Hardware Microphone Ambient Decibel Stream Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOISE_METER_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (ContextCompat.checkSelfPermission(this@MainActivity, android.Manifest.permission.RECORD_AUDIO)
                        != PackageManager.PERMISSION_GRANTED) {
                        events?.success(38.0)
                        return
                    }

                    val sampleRate = 44100
                    val channelConfig = AudioFormat.CHANNEL_IN_MONO
                    val audioFormat = AudioFormat.ENCODING_PCM_16BIT
                    val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
                    val bufferSize = if (minBufferSize > 0) minBufferSize else 2048

                    try {
                        audioRecord = AudioRecord(
                            MediaRecorder.AudioSource.MIC,
                            sampleRate,
                            channelConfig,
                            audioFormat,
                            bufferSize
                        )

                        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                            events?.success(38.0)
                            return
                        }

                        audioRecord?.startRecording()
                        isRecording = true

                        val mainHandler = Handler(Looper.getMainLooper())

                        recordingThread = Thread {
                            val buffer = ShortArray(bufferSize)
                            var lastDb = -1.0
                            var lastNoiseEmitMs = 0L

                            while (isRecording) {
                                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                                if (read > 0) {
                                    var sum = 0.0
                                    for (i in 0 until read) {
                                        sum += (buffer[i] * buffer[i]).toDouble()
                                    }
                                    val mean = sum / read
                                    val rms = sqrt(mean)
                                    val db = if (rms > 0.0) {
                                        (20.0 * log10(rms / 1.0) + 12.0).coerceIn(30.0, 95.0)
                                    } else {
                                        35.0
                                    }

                                    val now = System.currentTimeMillis()
                                    if (now - lastNoiseEmitMs >= 300 && (lastDb < 0.0 || kotlin.math.abs(db - lastDb) >= 0.8 || now - lastNoiseEmitMs >= 1000)) {
                                        lastNoiseEmitMs = now
                                        lastDb = db
                                        mainHandler.post {
                                            events?.success(db)
                                        }
                                    }
                                }
                                try {
                                    Thread.sleep(250)
                                } catch (e: InterruptedException) {
                                    break
                                }
                            }
                        }
                        recordingThread?.start()
                    } catch (e: Exception) {
                        events?.success(38.0)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    isRecording = false
                    try {
                        recordingThread?.interrupt()
                        recordingThread = null
                        audioRecord?.stop()
                        audioRecord?.release()
                        audioRecord = null
                    } catch (e: Exception) {}
                }
            })
    }
}
