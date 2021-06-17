import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
/// Decodes the given [image] ('package:image/image.dart') as an image ('dart:ui')
class RawImageProvider extends ImageProvider<_RawImageKey>{
  final img.Image image;
  //TODO: scale
  RawImageProvider(this.image);

  @override
  ImageStreamCompleter load(_RawImageKey key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: 1.0,
      debugLabel: 'RawImageProvider(${describeIdentity(key)})',
    );
  }

  @override
  Future<_RawImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(_RawImageKey(image.width, image.height, image.channels.index, hashList(image.data)));
  }
  /// see [ui.decodeImageFromPixels]
  Future<ui.Codec> _loadAsync(_RawImageKey key) async {
    assert(key.dataHash == hashList(image.data));
    // rgba8888 pixels
    var pixels = image.getBytes(format: img.Format.rgba);
    var buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
   
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: image.width,
        height: image.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
    //TODO: scale
    return descriptor.instantiateCodec(); 
  }
}

class _RawImageKey {
  final int w;
  final int h;
  final int channels;
  final int dataHash;
  _RawImageKey(this.w, this.h, this.channels, this.dataHash);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is _RawImageKey &&
      other.w == w &&
      other.h == h &&
      other.channels == channels &&
      other.dataHash == dataHash;
  }

  @override
  int get hashCode {
    return hashValues(w, h, channels, dataHash);
  }
}
