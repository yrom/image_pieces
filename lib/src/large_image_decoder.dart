import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:executor/executor.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image/image.dart';
import 'package:path/path.dart' as path;

import 'package:raw_image_provider/raw_image_provider.dart';

/// Decode large image (which height > [maxHeight]) to pieces
/// Support: jpg, png, webp
class LargeImageDecoder {
  final File file;
  final int maxHeight;
  final int pieceHeight;
  const LargeImageDecoder(
    this.file, {
    this.maxHeight = 2500,
    this.pieceHeight = 1024,
  }) : assert(pieceHeight < maxHeight);

  img.Image decodeSync() {
    return _decodeBytes(file.readAsBytesSync());
  }

  Future<img.Image> decodeInIsolate() {
    return cachedExecutor
        .run(_decodeFileInIsolate, this)
        .catchError((e) => debugPrint('$e'));
  }

  Future<img.Image> decodeAsync() async {
    var bytes = await file.readAsBytes();
    return _decodeBytes(bytes);
  }

  /// Decode large image in dart side.
  /// Support: jpg, png, webp
  img.Image _decodeBytes(Uint8List bytes) {
    var ext = path.extension(file.path);
    debugPrint('Decoding bytes: ${bytes.length}, ext: $ext');
    var decoder = _findDecoder(bytes, ext: ext);
    if (decoder == null) {
      throw RetryException(bytes, message: 'unsupported image type?');
    }
    var imageInfo = decoder.startDecode(bytes);
    if (imageInfo.numFrames == 0) {
      // invalid file?
      throw RetryException(bytes, message: 'no frames?');
    }
    if (imageInfo.height <= maxHeight) {
      // this is not 'large image', you can decode it by Flutter directly
      throw RetryException(bytes,
          message: 'not a large image, ${imageInfo.height}<=${maxHeight}');
    }
    debugPrint(
        '${decoder.runtimeType}: ${imageInfo.width}x${imageInfo.height}');

    return decoder.decodeFrame(0);
  }

  Stream<RawImageData> decodeToPiecesStream() async* {
    var image = file.lengthSync() > 2 * 1024 * 1024
        ? await decodeInIsolate()
        : await decodeAsync();
    if (image == null) {
      throw RetryException(null, message: '$file cannot decode as an image');
    }
    final w = image.width;
    if (pieceHeight >= image.height) {
      yield _raw(image);
      return;
    }
    final pieces = image.height ~/ pieceHeight + 1;

    for (var i = 0; i < pieces; i++) {
      yield _raw(img.copyCrop(image, 0, i * pieceHeight, w, pieceHeight));
    }
  }

  img.Decoder _findDecoder(Uint8List bytes, {String ext}) {
    if (ext != null && ext.isNotEmpty) {
      var decoder = _findDecoderByExt(ext);
      if (decoder.isValidFile(bytes)) return decoder;
    }

    var jpg = JpegDecoder();
    if (jpg.isValidFile(bytes)) {
      return jpg;
    }

    var png = PngDecoder();
    if (png.isValidFile(bytes)) {
      return png;
    }
    var webp = WebPDecoder();
    if (webp.isValidFile(bytes)) {
      return webp;
    }
    return null;
  }

  img.Decoder _findDecoderByExt(String ext) {
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) {
      return JpegDecoder();
    }
    if (ext.endsWith('.png')) {
      return PngDecoder();
    }

    if (ext.endsWith('.webp')) {
      return WebPDecoder();
    }
    return null;
  }
}

img.Image _decodeFileInIsolate(LargeImageDecoder decoder) {
  debugPrint(
      'Deocoding file "${decoder.file.path}" in isolate: ${Isolate.current.debugName}');
  return decoder.decodeSync();
}

List<img.Image> splitImageVertical(img.Image inputImage, int pieceHeight) {
  if (pieceHeight >= inputImage.height) {
    return [inputImage];
  }
  final w = inputImage.width;
  final pieces = inputImage.height ~/ pieceHeight + 1;
  final pieceList = List<img.Image>(pieces);

  for (var i = 0; i < pieces; i++) {
    pieceList[i] = img.copyCrop(inputImage, 0, i * pieceHeight, w, pieceHeight);
  }

  return pieceList;
}

RawImageData _raw(img.Image image) {
  return RawImageData(
    image.getBytes(format: img.Format.rgba),
    image.width,
    image.height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
}

Future<ui.Image> convertImage(img.Image inputImage) {
  var completer = Completer<ui.Image>();

  runZonedGuarded(() {
    ui.decodeImageFromPixels(
      inputImage.getBytes(format: img.Format.rgba),
      inputImage.width,
      inputImage.height,
      ui.PixelFormat.rgba8888,
      (image) {
        completer.complete(image);
      },
    );
  }, completer.completeError);

  return completer.future;
}

/// You can try Flutter Image.memory(bytes)
class RetryException implements Exception {
  final Uint8List bytes;
  final String message;
  RetryException(this.bytes, {this.message});
  @override
  String toString() {
    return message;
  }
}
