import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Görsel kırpma yardımcısı — bounding box koordinatlarına göre
/// görselden yemek fotoğrafını kırpar ve base64 PNG olarak döndürür.
class ImageCropUtil {
  ImageCropUtil._();

  /// [imageBytes] ham görsel, [region] 0-1 arası normalize koordinatlar
  /// (top, left, right, bottom). Başarısız olursa null döner.
  static Future<String?> cropAndEncode(
      Uint8List imageBytes, Map<String, double> region) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final fullImage = frame.image;

    final imgW = fullImage.width.toDouble();
    final imgH = fullImage.height.toDouble();

    final left = (region['left']! * imgW).round();
    final top = (region['top']! * imgH).round();
    final right = (region['right']! * imgW).round();
    final bottom = (region['bottom']! * imgH).round();

    final cropW = (right - left).clamp(1, fullImage.width);
    final cropH = (bottom - top).clamp(1, fullImage.height);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      fullImage,
      ui.Rect.fromLTWH(
          left.toDouble(), top.toDouble(), cropW.toDouble(), cropH.toDouble()),
      ui.Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(cropW.toInt(), cropH.toInt());
    fullImage.dispose();

    final byteData =
        await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    croppedImage.dispose();
    if (byteData == null) return null;

    final pngBytes = byteData.buffer.asUint8List();
    return base64Encode(pngBytes);
  }
}
