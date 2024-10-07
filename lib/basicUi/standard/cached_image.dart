import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';

class CachedImage extends StatefulWidget {
  final String imageUrl;
  final String? placeholder;

  const CachedImage({super.key, required this.imageUrl, this.placeholder});

  @override
  CachedImageState createState() => CachedImageState();
}

class CachedImageState extends State<CachedImage> {
  Uint8List? imageBytes;

  @override
  void initState() {
    super.initState();
    loadImage();
  }

  Future<void> loadImage() async {
    var cacheDir = await getApplicationCacheDirectory();
    var url = Uri.parse(widget.imageUrl);
    var fileName = url.pathSegments.last;
    var file = File('${cacheDir.path}/$fileName');
    if (file.existsSync()) {
      imageBytes = file.readAsBytesSync();
    } else {
      var res = await get(url);
      if (res.statusCode == 200) {
        imageBytes = res.bodyBytes;
        file.writeAsBytes(imageBytes!);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return imageBytes != null
        ? Image.memory(
            imageBytes!,
            fit: BoxFit.cover,
          )
        : Text(widget.placeholder ?? '');
  }
}
