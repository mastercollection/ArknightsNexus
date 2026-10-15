import 'package:flutter/widgets.dart';

/// The web build resolves images to bytes, never to files.
ImageProvider fileImageProvider(String path) =>
    throw UnsupportedError('No file images on the web: $path');
