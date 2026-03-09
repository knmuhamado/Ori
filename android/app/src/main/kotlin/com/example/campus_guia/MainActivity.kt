// Implementa el MethodChannel para solicitar permisos nativos

package com.example.campus_guia

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Debe coincidir exactamente con el nombre en permission_service.dart
    private val CHANNEL = "campus_guia/permissions"

    // Mapa de nombre → permiso Android
    private val permissionMap = mapOf(
        "location" to Manifest.permission.ACCESS_FINE_LOCATION,
        "microphone" to Manifest.permission.RECORD_AUDIO
    )

    // Guardamos el result pendiente mientras esperamos el callback
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPermission: String? = null

    // Código de request para el callback onRequestPermissionsResult
    private val REQUEST_CODE = 100

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // ── Solicitar un permiso ──
                "requestPermission" -> {
                    val permissionKey = call.argument<String>("permission")
                        ?: return@setMethodCallHandler result.error(
                            "INVALID_ARG",
                            "Falta el argumento 'permission'",
                            null
                        )

                    val androidPermission = permissionMap[permissionKey]
                        ?: return@setMethodCallHandler result.error(
                            "UNKNOWN_PERMISSION",
                            "Permiso desconocido: $permissionKey",
                            null
                        )

                    // Si ya fue concedido, responder inmediatamente
                    if (ContextCompat.checkSelfPermission(this, androidPermission)
                        == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success("granted")
                        return@setMethodCallHandler
                    }

                    // Guardar resultado pendiente y solicitar al sistema
                    pendingResult = result
                    pendingPermission = permissionKey
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(androidPermission),
                        REQUEST_CODE
                    )
                }

                // ── Verificar estado sin pedir ──
                "checkPermission" -> {
                    val permissionKey = call.argument<String>("permission")
                        ?: return@setMethodCallHandler result.error(
                            "INVALID_ARG",
                            "Falta el argumento 'permission'",
                            null
                        )

                    val androidPermission = permissionMap[permissionKey]
                        ?: return@setMethodCallHandler result.error(
                            "UNKNOWN_PERMISSION",
                            "Permiso desconocido: $permissionKey",
                            null
                        )

                    val status = if (
                        ContextCompat.checkSelfPermission(this, androidPermission)
                        == PackageManager.PERMISSION_GRANTED
                    ) "granted" else "denied"

                    result.success(status)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── Callback del sistema cuando el usuario responde al diálogo ──
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != REQUEST_CODE) return

        val result = pendingResult ?: return
        val permissionKey = pendingPermission ?: return

        // Limpiar estado pendiente
        pendingResult = null
        pendingPermission = null

        if (grantResults.isEmpty()) {
            result.success("denied")
            return
        }

        when (grantResults[0]) {
            PackageManager.PERMISSION_GRANTED -> {
                result.success("granted")
            }
            else -> {
                // Verificar si fue "no preguntar de nuevo" (denegación permanente)
                // shouldShowRequestPermissionRationale devuelve false en ese caso
                val androidPermission = permissionMap[permissionKey] ?: ""
                val isPermanent = !ActivityCompat
                    .shouldShowRequestPermissionRationale(this, androidPermission)

                result.success(
                    if (isPermanent) "permanently_denied" else "denied"
                )
            }
        }
    }
}