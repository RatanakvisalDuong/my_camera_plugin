package com.example.my_camera_plugin

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.os.Handler
import android.os.HandlerThread
import android.util.Range
import android.util.Size
import android.util.Log
import android.view.Surface
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.view.TextureRegistry
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.math.abs

/** Enhanced MyCameraPlugin with better image quality */
class MyCameraPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var context : Context
  private lateinit var textures: TextureRegistry
  private var cameraDevice: CameraDevice? = null
  private var captureSession: CameraCaptureSession? = null
  private var previewSurface: Surface? = null
  private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
  private var backgroundThread: HandlerThread? = null
  private var backgroundHandler: Handler? = null
  private var isBackCamera = true
  private var cameraCharacteristics: CameraCharacteristics? = null

  companion object {
    private const val TAG = "MyCameraPlugin"
    // Target resolution for high quality preview
    private val TARGET_RESOLUTION = Size(1920, 1080) // 1080p
    private val FALLBACK_RESOLUTION = Size(1280, 720) // 720p
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    textures = flutterPluginBinding.textureRegistry
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "my_camera_plugin")
    channel.setMethodCallHandler(this)
    startBackgroundThread()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method){
      "startCamera" -> startCamera(result)
      "stopCamera" -> stopCamera(result)
      "switchCamera" -> switchCamera(result)
      "takePhoto" -> takePhoto(result)
      else -> result.notImplemented()
    }
  }

  private fun startBackgroundThread() {
    backgroundThread = HandlerThread("CameraBackground").also { it.start() }
    backgroundHandler = Handler(backgroundThread!!.looper)
  }

  private fun stopBackgroundThread() {
    backgroundThread?.quitSafely()
    try {
      backgroundThread?.join()
      backgroundThread = null
      backgroundHandler = null
    } catch (e: InterruptedException) {
      e.printStackTrace()
    }
  }

  private fun startCamera(result: MethodChannel.Result){
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) 
        != PackageManager.PERMISSION_GRANTED) {
      result.error("PERMISSION_DENIED", "Camera permission not granted", null)
      return
    }

    val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    try {
      val cameraId = manager.cameraIdList.firstOrNull { id ->
          val chars = manager.getCameraCharacteristics(id)
          chars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
      }

      if (cameraId == null) {
        result.error("NO_CAMERA", "No back camera found", null)
        return
      }

      openCameraWithEnhancedQuality(cameraId, manager, result, true)
      
    } catch (e: Exception) {
      result.error("CAMERA_ERROR", "Unexpected error: ${e.message}", null)
    }
  }

  private fun switchCamera(result: MethodChannel.Result){
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) 
        != PackageManager.PERMISSION_GRANTED) {
      result.error("PERMISSION_DENIED", "Camera permission not granted", null)
      return
    }

    val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    try {
      val targetLensFacing = if (isBackCamera) {
        CameraCharacteristics.LENS_FACING_FRONT
      } else {
        CameraCharacteristics.LENS_FACING_BACK
      }
      
      val cameraId = manager.cameraIdList.firstOrNull { id ->
        val chars = manager.getCameraCharacteristics(id)
        chars.get(CameraCharacteristics.LENS_FACING) == targetLensFacing
      }

      if (cameraId == null) {
        val cameraType = if (targetLensFacing == CameraCharacteristics.LENS_FACING_FRONT) "front" else "back"
        result.error("NO_CAMERA", "No $cameraType camera found", null)
        return
      }

      openCameraWithEnhancedQuality(cameraId, manager, result, !isBackCamera)
      
    } catch (e: Exception) {
      result.error("CAMERA_ERROR", "Unexpected error: ${e.message}", null)
    }
  }

  private fun openCameraWithEnhancedQuality(cameraId: String, manager: CameraManager, result: MethodChannel.Result, isBack: Boolean) {
    try {
      stopCameraInternal()

      // Get camera characteristics for quality optimization
      cameraCharacteristics = manager.getCameraCharacteristics(cameraId)
      val map = cameraCharacteristics!!.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
      
      // Choose optimal preview size for high quality
      val outputSizes = map?.getOutputSizes(android.graphics.SurfaceTexture::class.java)
      val previewSize = chooseOptimalSize(outputSizes, TARGET_RESOLUTION)
      
      Log.d(TAG, "Selected preview size: ${previewSize.width}x${previewSize.height}")

      // Create surface texture with optimal settings
      textureEntry = textures.createSurfaceTexture()
      val surfaceTexture = textureEntry!!.surfaceTexture()
      
      // ENHANCEMENT 1: Set high-quality buffer size
      surfaceTexture.setDefaultBufferSize(previewSize.width, previewSize.height)
      previewSurface = Surface(surfaceTexture)

      manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
          cameraDevice = camera
          createEnhancedCaptureSession(camera, previewSize, result, isBack)
        }
        
        override fun onDisconnected(camera: CameraDevice) {
          camera.close()
          cameraDevice = null
        }
        
        override fun onError(camera: CameraDevice, error: Int) {
          camera.close()
          cameraDevice = null
          val errorMessage = when (error) {
            CameraDevice.StateCallback.ERROR_CAMERA_IN_USE -> "Camera in use"
            CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE -> "Max cameras in use"
            CameraDevice.StateCallback.ERROR_CAMERA_DISABLED -> "Camera disabled"
            CameraDevice.StateCallback.ERROR_CAMERA_DEVICE -> "Camera device error"
            CameraDevice.StateCallback.ERROR_CAMERA_SERVICE -> "Camera service error"
            else -> "Unknown camera error"
          }
          result.error("CAMERA_ERROR", errorMessage, null)
        }
      }, backgroundHandler)
      
    } catch (e: Exception) {
      result.error("CAMERA_ERROR", "Failed to open camera: ${e.message}", null)
    }
  }

  private fun createEnhancedCaptureSession(camera: CameraDevice, previewSize: Size, result: MethodChannel.Result, isBack: Boolean) {
    try {
      // ENHANCEMENT 2: Create optimized capture request
      val requestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
      requestBuilder.addTarget(previewSurface!!)
      
      // ENHANCEMENT 3: Set high-quality capture parameters
      applyEnhancedCameraSettings(requestBuilder, isBack)
      
      camera.createCaptureSession(
        listOf(previewSurface), 
        object : CameraCaptureSession.StateCallback() {
          override fun onConfigured(session: CameraCaptureSession) {
            captureSession = session
            try {
              // ENHANCEMENT 4: Start capture with quality monitoring
              session.setRepeatingRequest(
                requestBuilder.build(), 
                object : CameraCaptureSession.CaptureCallback() {
                  override fun onCaptureCompleted(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    result: TotalCaptureResult
                  ) {
                    super.onCaptureCompleted(session, request, result)
                    // Monitor image quality metrics
                    logImageQualityMetrics(result)
                  }
                  
                  override fun onCaptureFailed(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    failure: CaptureFailure
                  ) {
                    super.onCaptureFailed(session, request, failure)
                    Log.e(TAG, "Capture failed: ${failure.reason}")
                  }
                }, 
                backgroundHandler
              )
              
              isBackCamera = isBack
              result.success(mapOf(
                "textureId" to textureEntry!!.id(),
                "isBackCamera" to isBackCamera,
                "width" to previewSize.width,
                "height" to previewSize.height,
                "quality" to "enhanced"
              ))
            } catch (e: CameraAccessException) {
              result.error("CAPTURE_ERROR", "Failed to start capture: ${e.message}", null)
            }
          }
          
          override fun onConfigureFailed(session: CameraCaptureSession) {
            result.error("CONFIG_FAILED", "Camera session config failed", null)
          }
        }, 
        backgroundHandler
      )
    } catch (e: CameraAccessException) {
      result.error("CAMERA_ERROR", "Failed to create capture request: ${e.message}", null)
    }
  }

  // ENHANCEMENT 5: Apply advanced camera settings for better image quality
  private fun applyEnhancedCameraSettings(requestBuilder: CaptureRequest.Builder, isBack: Boolean) {
    try {
      // Auto-focus settings for sharpness
      if (isAutoFocusSupported(CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)) {
        requestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
      }
      
      // Auto-exposure for optimal brightness
      requestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
      
      // Auto white balance for accurate colors
      requestBuilder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
      
      // Image stabilization (if available)
      if (isImageStabilizationSupported()) {
        if (isBack) {
          requestBuilder.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_ON)
        } else {
          requestBuilder.set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_ON)
        }
      }
      
      // Noise reduction for cleaner image
      requestBuilder.set(CaptureRequest.NOISE_REDUCTION_MODE, CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY)
      
      // Edge enhancement for sharper details
      requestBuilder.set(CaptureRequest.EDGE_MODE, CaptureRequest.EDGE_MODE_HIGH_QUALITY)
      
      // Color correction for better colors
      requestBuilder.set(CaptureRequest.COLOR_CORRECTION_MODE, CaptureRequest.COLOR_CORRECTION_MODE_HIGH_QUALITY)
      
      // Tone mapping for better dynamic range
      requestBuilder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_HIGH_QUALITY)
      
      // Set optimal FPS range for smooth preview
      val fpsRange = getOptimalFpsRange()
      if (fpsRange != null) {
        requestBuilder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fpsRange)
      }
      
      // Face detection for better focus (if supported)
      if (isFaceDetectionSupported()) {
        requestBuilder.set(CaptureRequest.STATISTICS_FACE_DETECT_MODE, CaptureRequest.STATISTICS_FACE_DETECT_MODE_FULL)
      }
      
      Log.d(TAG, "Applied enhanced camera settings for ${if (isBack) "back" else "front"} camera")
      
    } catch (e: Exception) {
      Log.w(TAG, "Some camera settings not supported: ${e.message}")
    }
  }

  // ENHANCEMENT 6: Smart resolution selection
  private fun chooseOptimalSize(choices: Array<Size>?, targetSize: Size): Size {
    if (choices == null || choices.isEmpty()) {
      return FALLBACK_RESOLUTION
    }
    
    // Sort by resolution (highest first)
    val sortedSizes = choices.sortedByDescending { it.width * it.height }
    
    // Try to find exact match first
    for (size in sortedSizes) {
      if (size.width == targetSize.width && size.height == targetSize.height) {
        return size
      }
    }
    
    // Find closest aspect ratio
    val targetRatio = targetSize.width.toDouble() / targetSize.height
    var bestSize = sortedSizes[0]
    var minRatioDiff = Double.MAX_VALUE
    
    for (size in sortedSizes) {
      val ratio = size.width.toDouble() / size.height
      val ratioDiff = abs(ratio - targetRatio)
      
      if (ratioDiff < minRatioDiff && size.width >= 1280) { // Minimum quality threshold
        minRatioDiff = ratioDiff
        bestSize = size
      }
    }
    
    Log.d(TAG, "Available sizes: ${choices.map { "${it.width}x${it.height}" }}")
    Log.d(TAG, "Selected optimal size: ${bestSize.width}x${bestSize.height}")
    
    return bestSize
  }

  // Helper methods for capability checking
  private fun isAutoFocusSupported(mode: Int): Boolean {
    val modes = cameraCharacteristics?.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)
    return modes?.contains(mode) == true
  }

  private fun isImageStabilizationSupported(): Boolean {
    val videoStab = cameraCharacteristics?.get(CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES)
    val opticalStab = cameraCharacteristics?.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)
    return (videoStab?.contains(CameraCharacteristics.CONTROL_VIDEO_STABILIZATION_MODE_ON) == true) ||
           (opticalStab?.contains(CameraCharacteristics.LENS_OPTICAL_STABILIZATION_MODE_ON) == true)
  }

  private fun isFaceDetectionSupported(): Boolean {
    val modes = cameraCharacteristics?.get(CameraCharacteristics.STATISTICS_INFO_AVAILABLE_FACE_DETECT_MODES)
    return modes?.contains(CameraCharacteristics.STATISTICS_FACE_DETECT_MODE_FULL) == true
  }

  private fun getOptimalFpsRange(): Range<Int>? {
    val fpsRanges = cameraCharacteristics?.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
    
    // Prefer 30 FPS for smooth preview
    fpsRanges?.forEach { range ->
      if (range.lower <= 30 && range.upper >= 30) {
        return Range(30, 30)
      }
    }
    
    // Fallback to highest available
    return fpsRanges?.maxByOrNull { it.upper }
  }

  private fun logImageQualityMetrics(result: TotalCaptureResult) {
    // Log quality metrics for debugging (only in debug builds)
    try {
      val focusState = result.get(CaptureResult.CONTROL_AF_STATE)
      val exposureState = result.get(CaptureResult.CONTROL_AE_STATE)
      val whiteBalanceState = result.get(CaptureResult.CONTROL_AWB_STATE)
      
      Log.v(TAG, "Quality metrics - Focus: $focusState, Exposure: $exposureState, WB: $whiteBalanceState")
    } catch (e: Exception) {
      // Ignore logging errors
    }
  }

  private fun takePhoto(result: MethodChannel.Result) {
    if (cameraDevice == null || captureSession == null) {
      result.error("CAMERA_NOT_READY", "Camera not initialized", null)
      return
    }

    try {
      val characteristics = cameraCharacteristics!!
      val jpegSizes = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        ?.getOutputSizes(ImageFormat.JPEG)
      
      // Choose high-quality photo size
      val photoSize = jpegSizes?.maxByOrNull { it.width * it.height } ?: Size(1920, 1080)
      
      // Create ImageReader for capturing photo
      val imageReader = android.media.ImageReader.newInstance(
        photoSize.width, 
        photoSize.height, 
        ImageFormat.JPEG, 
        1
      )
      
      // Set up image available listener
      imageReader.setOnImageAvailableListener({ reader ->
        val image = reader.acquireLatestImage()
        try {
          val buffer = image.planes[0].buffer
          val bytes = ByteArray(buffer.remaining())
          buffer.get(bytes)
          
          // Convert to base64 and return just the string
          val base64String = android.util.Base64.encodeToString(bytes, android.util.Base64.DEFAULT)
          
          result.success(base64String)
        } catch (e: Exception) {
          result.error("PHOTO_CAPTURE_ERROR", "Failed to process photo: ${e.message}", null)
        } finally {
          image.close()
          imageReader.close()
        }
      }, backgroundHandler)
      
      // FIX: Create new capture session with both preview and photo surfaces
      val surfaces = listOf(previewSurface!!, imageReader.surface)
      
      cameraDevice!!.createCaptureSession(
        surfaces,
        object : CameraCaptureSession.StateCallback() {
          override fun onConfigured(session: CameraCaptureSession) {
            try {
              // Create capture request for photo
              val captureRequestBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
              captureRequestBuilder.addTarget(imageReader.surface)
              
              // Apply photo capture settings
              captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
              captureRequestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
              captureRequestBuilder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
              captureRequestBuilder.set(CaptureRequest.JPEG_QUALITY, 95.toByte())
              
              // Set orientation based on camera facing
              val rotation = if (isBackCamera) 90 else 270
              captureRequestBuilder.set(CaptureRequest.JPEG_ORIENTATION, rotation)
              
              // Capture the photo
              session.capture(
                captureRequestBuilder.build(),
                object : CameraCaptureSession.CaptureCallback() {
                  override fun onCaptureCompleted(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    captureResult: TotalCaptureResult
                  ) {
                    Log.d(TAG, "Photo capture completed")
                    
                    // Restart preview after photo capture
                    try {
                      val previewRequestBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                      previewRequestBuilder.addTarget(previewSurface!!)
                      applyEnhancedCameraSettings(previewRequestBuilder, isBackCamera)
                      
                      session.setRepeatingRequest(previewRequestBuilder.build(), null, backgroundHandler)
                    } catch (e: Exception) {
                      Log.e(TAG, "Failed to restart preview: ${e.message}")
                    }
                  }
                  
                  override fun onCaptureFailed(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    failure: CaptureFailure
                  ) {
                    result.error("PHOTO_CAPTURE_FAILED", "Photo capture failed: ${failure.reason}", null)
                    imageReader.close()
                  }
                },
                backgroundHandler
              )
            } catch (e: Exception) {
              result.error("PHOTO_ERROR", "Failed to capture photo: ${e.message}", null)
              imageReader.close()
            }
          }
          
          override fun onConfigureFailed(session: CameraCaptureSession) {
            result.error("PHOTO_CONFIG_FAILED", "Failed to configure photo session", null)
            imageReader.close()
          }
        },
        backgroundHandler
      )
      
    } catch (e: Exception) {
      result.error("PHOTO_ERROR", "Failed to take photo: ${e.message}", null)
    }
  }

  private fun stopCamera(result: MethodChannel.Result) {
    stopCameraInternal()
    result.success(null)
  }

  private fun stopCameraInternal() {
    try {
      captureSession?.close()
      captureSession = null
      
      cameraDevice?.close()
      cameraDevice = null
      
      previewSurface?.release()
      previewSurface = null
      
      textureEntry?.release()
      textureEntry = null
      
      cameraCharacteristics = null
    } catch (e: Exception) {
      Log.e(TAG, "Error stopping camera: ${e.message}")
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    stopCameraInternal()
    stopBackgroundThread()
  }
}