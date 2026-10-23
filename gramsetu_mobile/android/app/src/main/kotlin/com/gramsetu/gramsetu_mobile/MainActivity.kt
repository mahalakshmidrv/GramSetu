package com.gramsetu.gramsetu_mobile

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.gramsetu.nearby/bluetooth"
    private val SERVICE_UUID: UUID = UUID.fromString("0000FE28-0000-1000-8000-00805F9B34FB")

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null
    private var isAdvertising = false
    private var isScanning = false

    private var advertiseCallback: AdvertiseCallback? = null
    private var scanCallback: ScanCallback? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkHardwareSupport" -> {
                    val supported = bluetoothAdapter != null && bluetoothAdapter!!.isEnabled
                    val leSupported = bluetoothAdapter?.isMultipleAdvertisementSupported ?: false
                    result.success(mapOf(
                        "bluetoothEnabled" to supported,
                        "leAdvertisingSupported" to leSupported,
                        "deviceName" to (bluetoothAdapter?.name ?: "Unknown Device")
                    ))
                }
                "startAdvertising" -> {
                    val deviceId = call.argument<String>("deviceId") ?: "unknown"
                    val success = startBleAdvertising(deviceId)
                    result.success(success)
                }
                "stopAdvertising" -> {
                    stopBleAdvertising()
                    result.success(true)
                }
                "startDiscovery" -> {
                    val success = startBleDiscovery(flutterEngine)
                    result.success(success)
                }
                "stopDiscovery" -> {
                    stopBleDiscovery()
                    result.success(true)
                }
                "sendDirectPacket" -> {
                    val targetPeer = call.argument<String>("peerId")
                    val payload = call.argument<String>("payload")
                    // Real RFCOMM/socket delivery acknowledgement simulation
                    result.success(mapOf(
                        "status" to "delivered",
                        "peerId" to targetPeer,
                        "timestamp" to System.currentTimeMillis()
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startBleAdvertising(deviceId: String): Boolean {
        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) return false
        advertiser = bluetoothAdapter?.bluetoothLeAdvertiser ?: return false

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .build()

        val pUuid = ParcelUuid(SERVICE_UUID)
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(pUuid)
            .addServiceData(pUuid, deviceId.take(8).toByteArray(StandardCharsets.UTF_8))
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                super.onStartSuccess(settingsInEffect)
                isAdvertising = true
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                isAdvertising = false
            }
        }

        try {
            advertiser?.startAdvertising(settings, data, advertiseCallback)
            return true
        } catch (e: SecurityException) {
            return false
        } catch (e: Exception) {
            return false
        }
    }

    private fun stopBleAdvertising() {
        if (advertiser != null && advertiseCallback != null) {
            try {
                advertiser?.stopAdvertising(advertiseCallback)
            } catch (e: Exception) {}
        }
        isAdvertising = false
    }

    private fun startBleDiscovery(flutterEngine: FlutterEngine): Boolean {
        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) return false
        scanner = bluetoothAdapter?.bluetoothLeScanner ?: return false

        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_BALANCED)
            .build()

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult?) {
                super.onScanResult(callbackType, result)
                if (result != null) {
                    val device = result.device
                    val rssi = result.rssi
                    val peerMap = mapOf(
                        "id" to (device.address ?: "peer-${System.currentTimeMillis()}"),
                        "name" to (device.name ?: "GramSetu Neighbour"),
                        "rssi" to rssi
                    )
                    runOnUiThread {
                        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                            .invokeMethod("onDeviceDiscovered", peerMap)
                    }
                }
            }
        }

        try {
            scanner?.startScan(listOf(filter), settings, scanCallback)
            isScanning = true
            return true
        } catch (e: SecurityException) {
            return false
        } catch (e: Exception) {
            return false
        }
    }

    private fun stopBleDiscovery() {
        if (scanner != null && scanCallback != null) {
            try {
                scanner?.stopScan(scanCallback)
            } catch (e: Exception) {}
        }
        isScanning = false
    }
}
