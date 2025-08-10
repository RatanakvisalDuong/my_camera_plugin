import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:my_camera_plugin/my_camera_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int? textureId;
  bool isCameraStarted = false;
  String? capturedImageBase64;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {}
  }

  // Method to show captured image
  void _showCapturedImage(BuildContext context, String base64String) {
    // Add debug logging

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoDisplayScreen(base64String: base64String),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder:
            (BuildContext context) => Scaffold(
              appBar: AppBar(title: const Text("My Camera Plugin Test")),
              body: Stack(
                children: [
                  Center(
                    child:
                        textureId == null
                            ? const Text("Camera is off")
                            : SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: Texture(textureId: textureId!),
                            ),
                  ),
                  if (isCameraStarted)
                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: InkWell(
                          onTap: () async {
                            try {
                              String? result = await MyCameraPlugin.takePhoto();

                              if (result != null && result.isNotEmpty) {
                                // Navigate to photo display screen
                                _showCapturedImage(context, result);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('No photo data received'),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to take photo: $e'),
                                ),
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey, width: 3),
                            ),
                            width: 80,
                            height: 80,
                            child: Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              floatingActionButton: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    onPressed: () async {
                      if (textureId == null) {
                        if ((await Permission.camera.request()).isGranted) {
                          dynamic result = await MyCameraPlugin.startCamera();
                          setState(() {
                            isCameraStarted = true;
                            if (result is int) {
                              textureId = result;
                            } else if (result is Map) {
                              textureId = result["textureId"];
                            }
                          });
                        }
                      } else {
                        setState(() {
                          isCameraStarted = false;
                          textureId = null;
                        });
                        await MyCameraPlugin.stopCamera();
                      }
                    },
                    heroTag: 'main',
                    child: Icon(textureId == null ? Icons.camera : Icons.stop),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    onPressed: () async {
                      if (textureId != null) {
                        try {
                          dynamic result = await MyCameraPlugin.switchCamera();
                          if (result is Map<dynamic, dynamic>) {
                            setState(() {
                              textureId = result["textureId"];
                            });
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to switch camera: $e'),
                            ),
                          );
                        }
                      }
                    },
                    heroTag: 'switch',
                    tooltip: 'Switch Camera',
                    child: const Icon(Icons.switch_camera),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

// Enhanced photo display screen with better debugging
class PhotoDisplayScreen extends StatelessWidget {
  final String base64String;

  const PhotoDisplayScreen({super.key, required this.base64String});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Captured Photo'),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              // Show debug info
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text('Debug Info'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Base64 length: ${base64String.length}'),
                          SizedBox(height: 8),
                          Text(
                            'Starts with: ${base64String.substring(0, base64String.length > 50 ? 50 : base64String.length)}...',
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Contains data URL: ${base64String.contains("data:")}',
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('OK'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: displayImageWithDebug(base64String),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              heroTag: 'backBtn',
              child: Icon(Icons.arrow_back),
            ),
            FloatingActionButton(
              onPressed: () {
                //TODO: Implement forward button action
              },
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              heroTag: 'forwardBtn',
              child: Icon(Icons.check),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

Widget displayImageWithDebug(String base64String) {
  try {
    String cleanBase64 = base64String;
    if (base64String.contains(',')) {
      cleanBase64 = base64String.split(',').last;
    }
    cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
    if (cleanBase64.isEmpty) {
      return _buildErrorWidget("Base64 string is empty");
    }
    if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(cleanBase64)) {
      return _buildErrorWidget("Invalid base64 format");
    }
    Uint8List imageBytes = base64Decode(cleanBase64);
    if (imageBytes.isEmpty) {
      return _buildErrorWidget("No image data");
    }
    if (imageBytes.length >= 2) {
      bool isJPEG = imageBytes[0] == 0xFF && imageBytes[1] == 0xD8;
      if (!isJPEG) {}
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame == null) {
            return SizedBox(
              width: 200,
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget("Image loading failed: $error");
        },
      ),
    );
  } catch (e) {
    return _buildErrorWidget("Exception: $e");
  }
}

Widget _buildErrorWidget(String errorMessage) {
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.red, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error, size: 50, color: Colors.red),
        SizedBox(height: 10),
        Text(
          'Failed to load image',
          style: TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          errorMessage,
          style: TextStyle(color: Colors.white, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget displayImage(String base64String) {
  try {
    String cleanBase64 = base64String;
    if (base64String.contains(',')) {
      cleanBase64 = base64String.split(',').last;
    }

    Uint8List imageBytes = base64Decode(cleanBase64);
    return Image.memory(imageBytes, fit: BoxFit.contain);
  } catch (e) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 50, color: Colors.red),
          SizedBox(height: 10),
          Text('Invalid image data', style: TextStyle(color: Colors.red)),
          Text('Error: $e', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
