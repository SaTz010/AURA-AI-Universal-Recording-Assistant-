import 'package:flutter/services.dart';

class PdfSafService {
  static const MethodChannel _channel = MethodChannel('com.aura.files/pdf');

  static Future<String?> createPdfDocument({required String suggestedName}) {
    return _channel.invokeMethod<String>('createPdfDocument', {
      'suggestedName': suggestedName,
    });
  }

  static Future<bool> writeBytesToUri({
    required String uri,
    required Uint8List bytes,
  }) async {
    final ok = await _channel.invokeMethod<bool>('writeBytesToUri', {
      'uri': uri,
      'bytes': bytes,
    });
    return ok ?? false;
  }

  static Future<bool> openPdfUri({required String uri}) async {
    final ok = await _channel.invokeMethod<bool>('openPdfUri', {
      'uri': uri,
    });
    return ok ?? false;
  }
}
