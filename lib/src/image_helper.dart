import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

img.Image decodeFileSync(File file) {
  return decodeBytes(file.readAsBytesSync(), ext: path.extension(file.path));
}

Future<img.Image> decodeFileAsync(File file) async {
  var bytes = await file.readAsBytes();
  return decodeBytes(bytes, ext: path.extension(file.path));
}

img.Image decodeBytes(List<int> bytes, {String ext}) {
  img.Image result;
  if (ext != null && ext.isNotEmpty) {
    try {
      result = img.decodeNamedImage(bytes, ext);
    } catch (e) {}
  }
  return result ?? img.decodeImage(bytes);
}

Future<img.Image> decodeFileIsolate(File file) async {
  return compute(decodeFileSync, file);
}

List<img.Image> decodeFileToPieces(File file, int pieceCount) {
  var image = decodeFileSync(file);
  if (image == null) throw AssertionError("$file cannot decode as an image");
  return splitImageVertical(image, pieceCount);
}

Stream<img.Image> decodeFileToPiecesStream(File file, int pieceCount) async* {
  var image = await decodeFileIsolate(file);
  if (image == null) throw AssertionError("$file cannot decode as an image");
  final w = image.width;
  final h = (image.height / pieceCount).round();

  for (var i = 0; i < pieceCount; i++) {
    yield img.copyCrop(image, 0, i * h, w, h);
  }
}

List<img.Image> splitImageVertical(img.Image inputImage, int pieceCount) {
  final w = inputImage.width;
  final h = (inputImage.height / pieceCount).round();
  final pieceList = List<img.Image>(pieceCount);

  for (var i = 0; i < pieceCount; i++) {
    pieceList[i] = img.copyCrop(inputImage, 0, i * h, w, h);
  }

  return pieceList;
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

List<img.Image> _decodeFileToPieces(_DecodeParams params) {
  return decodeFileToPieces(params.file, params.pieceCount);
}

Future<List<img.Image>> decodeFileToPiecesIsolate(
    File file, int pieceCount) async {
  return compute(_decodeFileToPieces, _DecodeParams(file, pieceCount));
}

class _DecodeParams {
  final File file;
  final int pieceCount;

  _DecodeParams(this.file, this.pieceCount);
}
