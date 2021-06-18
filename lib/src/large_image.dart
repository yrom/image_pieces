import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:raw_image_provider/raw_image_provider.dart';

import 'large_image_decoder.dart';

/// A simple widget that support the very large image
class LargeImage extends StatefulWidget {
  final File file;
  const LargeImage({Key key, this.file}) : super(key: key);

  @override
  _LargeImageState createState() => _LargeImageState();
}

const pieceHeight = 1024;

class _LargeImageState extends State<LargeImage> {
  StreamSubscription _subscription;
  List<RawImageData> _chunks = [];
  List<RawImageData> _full;
  dynamic _imageStreamError;
  @override
  void initState() {
    super.initState();
    _listenImageStream();
  }

  @override
  void didUpdateWidget(covariant LargeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) {
      _listenImageStream();
    }
  }

  void _listenImageStream() {
    if (_subscription != null) {
      _subscription.cancel();
    }
    _imageStreamError = null;
    _full = null;
    if (_chunks.isNotEmpty) _chunks.clear();
    var imageStream = LargeImageDecoder(widget.file, pieceHeight: pieceHeight)
        .decodeToPiecesStream();
    _subscription = imageStream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: true,
    );
  }

  void _onData(RawImageData piece) {
    debugPrint(
        'receive piece: ${piece.width}x${piece.height}, len: ${piece.pixels.length}');
    _chunks.add(piece);
    setState(() {});
  }

  void _onDone() {
    setState(() {
      _full = _chunks;
      _chunks = [];
      _subscription = null;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_imageStreamError != null) {
      // use Image directly
      if (_imageStreamError is RetryException) {
        if (_imageStreamError.bytes != null) {
          return Image.memory(_imageStreamError.bytes);
        }
        return Image.file(widget.file);
      }
      // rethrow
      if (kDebugMode) {
        throw _imageStreamError;
      }
      return SizedBox.shrink();
    }
    var children = <Widget>[];

    var pieces = _full ?? _chunks;
    if (pieces.isEmpty) {
      return CircularProgressIndicator();
    }
    for (final piece in pieces) {
      children.add(Image(
        image: RawImageProvider(piece),
      ));
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: children,
    );
  }

  void _onError(dynamic error) {
    debugPrint('Image stream error: $error');
    setState(() {
      _imageStreamError = error;
      _chunks = [];
    });
  }
}
