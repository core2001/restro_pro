
package com.xxxxx.restropro // CHANGE com.xxxxx to your package name

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import java.io.OutputStream
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.restropro.bluetooth"
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "scanBluetoothDevices" -> {
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                    val pairedDevices = adapter.bondedDevices
                    val list = pairedDevices.map { mapOf("name" to it.name, "mac" to it.address) }
                    result.success(list)
                }
                "connectToPrinter" -> {
                    val mac = call.argument<String>("mac")!!
                    val device: BluetoothDevice = BluetoothAdapter.getDefaultAdapter().getRemoteDevice(mac)
                    bluetoothSocket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                    bluetoothSocket!!.connect()
                    outputStream = bluetoothSocket!!.outputStream
                    result.success(true)
                }
                "disconnectPrinter" -> {
                    outputStream?.close()
                    bluetoothSocket?.close()
                    result.success(null)
                }
                "writeBytes" -> {
                    val bytes = call.argument<ByteArray>("bytes")!!
                    outputStream?.write(bytes)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}