import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageProcessor {
  /// Decodes, compresses, and generates a thumbnail using native Flutter Canvas.
  static Future<void> processImage({
    required File inputFile,
    required File outputFile,
    required File thumbnailFile,
    required int maxDimension,
    required int thumbnailDimension,
  }) async {
    final bytes = await inputFile.readAsBytes();
    
    // Decode image metadata/dimensions natively
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image originalImage = frameInfo.image;
    
    final int w = originalImage.width;
    final int h = originalImage.height;
    
    // Calculate resize scale for main compressed image
    double scale = 1.0;
    if (w > maxDimension || h > maxDimension) {
      if (w > h) {
        scale = maxDimension / w;
      } else {
        scale = maxDimension / h;
      }
    }
    
    final int newW = (w * scale).round();
    final int newH = (h * scale).round();
    
    // Render compressed image
    final compressedBytes = await _resizeImage(originalImage, newW, newH);
    await outputFile.writeAsBytes(compressedBytes);
    
    // Calculate resize scale for thumbnail
    double thumbScale = 1.0;
    if (w > thumbnailDimension || h > thumbnailDimension) {
      if (w > h) {
        thumbScale = thumbnailDimension / w;
      } else {
        thumbScale = thumbnailDimension / h;
      }
    }
    final int thumbW = (w * thumbScale).round();
    final int thumbH = (h * thumbScale).round();
    
    // Render thumbnail image
    final thumbBytes = await _resizeImage(originalImage, thumbW, thumbH);
    await thumbnailFile.writeAsBytes(thumbBytes);
  }
  
  static Future<Uint8List> _resizeImage(ui.Image image, int width, int height) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    
    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = ui.FilterQuality.medium);
    
    final picture = pictureRecorder.endRecording();
    final resizedImage = await picture.toImage(width, height);
    final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
