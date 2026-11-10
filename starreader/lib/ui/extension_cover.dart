import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/extensions.dart';
import '../core/library.dart';
import '../core/models.dart';

class ExtensionCover extends StatefulWidget {
  final Manga manga;
  const ExtensionCover({required this.manga, super.key});
  @override
  State<ExtensionCover> createState() => _ExtensionCoverState();
}

class _ExtensionCoverState extends State<ExtensionCover> {
  late Future<Uint8List> future = load();
  Future<Uint8List> load() => context.read<Library>().covers.get(
    '${widget.manga.source}:${widget.manga.cover}',
    () => Library.fetchImage(
      ExtensionBridge.imageToken({
        'source': widget.manga.source.substring(4),
        'url': widget.manga.cover,
        'cover': true,
      }),
    ),
  );
  @override
  void didUpdateWidget(ExtensionCover old) {
    super.didUpdateWidget(old);
    if (old.manga.cover != widget.manga.cover ||
        old.manga.source != widget.manga.source) {
      future = load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: future,
    builder: (c, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          cacheWidth: 400,
          errorBuilder: (_, _, _) => placeholder(c, false),
        );
      }
      return placeholder(c, !snapshot.hasError);
    },
  );
  Widget placeholder(BuildContext context, bool loading) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Center(
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.image_outlined),
    ),
  );
}
