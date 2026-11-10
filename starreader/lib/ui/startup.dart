import 'package:flutter/material.dart';

import 'design.dart';

/// Keeps startup visible while the database and installed sources are prepared.
/// A failed initialization never clears or replaces the user's stored library.
class StarReaderStartup extends StatefulWidget {
  final Future<void> Function() initialize;
  final Widget child;
  const StarReaderStartup({
    required this.initialize,
    required this.child,
    super.key,
  });
  @override
  State<StarReaderStartup> createState() => _StarReaderStartupState();
}

class _StarReaderStartupState extends State<StarReaderStartup> {
  late Future<void> ready = Future<void>.sync(widget.initialize);
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: ready,
    builder: (_, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return widget.child;
      }
      return MaterialApp(
        title: 'StarReader',
        debugShowCheckedModeBanner: false,
        theme: StarTheme.build(Brightness.dark, accent: starMint),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const OrbitArt(size: 160),
                      const SizedBox(height: 24),
                      const Text(
                        'StarReader',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.hasError) ...[
                        const Text(
                          'Your reading room couldn’t open.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your files have not been reset. Check available storage, then try again.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => setState(() {
                            ready = Future<void>.sync(widget.initialize);
                          }),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          title: const Text('Error details'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(snapshot.error.toString()),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'Getting your library and sources ready…',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
