import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/reader_preferences.dart';
import 'design.dart';

class ReaderSettingsPanel extends StatefulWidget {
  final ReaderPreferences preferences;
  final ValueChanged<ReaderPreferences> onChanged;
  final Future<void> Function(ReaderPreferences) onDefault;
  final Future<ReaderPreferences> Function() onReset;
  final ValueChanged<double> onBrightness;
  final double brightness;
  const ReaderSettingsPanel({
    required this.preferences,
    required this.onChanged,
    required this.onDefault,
    required this.onReset,
    required this.onBrightness,
    required this.brightness,
    super.key,
  });
  @override
  State<ReaderSettingsPanel> createState() => _ReaderSettingsPanelState();
}

class _ReaderSettingsPanelState extends State<ReaderSettingsPanel> {
  late ReaderPreferences value = widget.preferences;
  late double brightness = widget.brightness;
  bool savedDefault = false;
  void change(ReaderPreferences next) {
    setState(() {
      value = next;
      savedDefault = false;
    });
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .83,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('MADE FOR THE WAY YOU READ'),
                        const SizedBox(height: 6),
                        Text(
                          'Your reading space',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close reader settings',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Changes are saved for this story.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 22),
                  const Eyebrow('READING MODE'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final mode in [
                        ('paged', 'Horizontal', Icons.view_carousel_outlined),
                        (
                          'vertical',
                          'Vertical pages',
                          Icons.view_agenda_outlined,
                        ),
                        ('webtoon', 'Continuous', Icons.view_day_outlined),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => change(
                                value.copyWith(
                                  mode: mode.$1,
                                  spread: mode.$1 == 'webtoon'
                                      ? false
                                      : value.spread,
                                ),
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: value.mode == mode.$1
                                      ? colors.primary.withValues(alpha: .15)
                                      : colors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: value.mode == mode.$1
                                        ? colors.primary
                                        : colors.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      mode.$3,
                                      color: value.mode == mode.$1
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      mode.$2,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Right to left'),
                    subtitle: const Text('For manga in its original direction'),
                    value: value.rtl,
                    onChanged: (v) => change(value.copyWith(rtl: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Double-page spread'),
                    subtitle: const Text(
                      'Two pages together, in reading order',
                    ),
                    value: value.spread,
                    onChanged: value.mode == 'webtoon'
                        ? null
                        : (v) => change(value.copyWith(spread: v)),
                  ),
                  const SizedBox(height: 20),
                  const Eyebrow('THE PAGE'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: value.fit,
                    decoration: const InputDecoration(labelText: 'Scaling'),
                    items: const [
                      DropdownMenuItem(
                        value: 'contain',
                        child: Text('Fit page'),
                      ),
                      DropdownMenuItem(
                        value: 'width',
                        child: Text('Fit width'),
                      ),
                      DropdownMenuItem(
                        value: 'height',
                        child: Text('Fit height'),
                      ),
                      DropdownMenuItem(
                        value: 'original',
                        child: Text('Original scale · pan to explore'),
                      ),
                    ],
                    onChanged: (v) => change(value.copyWith(fit: v)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: Text('Page margins')),
                      Text(
                        '${value.margin.round()} px',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Slider(
                    value: value.margin,
                    max: 40,
                    divisions: 20,
                    label: '${value.margin.round()} px',
                    onChanged: (v) => change(value.copyWith(margin: v)),
                  ),
                  const Text('Background'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      for (final entry in {
                        'black': Colors.black,
                        'charcoal': const Color(0xff202020),
                        'paper': const Color(0xffeee5d5),
                        'white': Colors.white,
                      }.entries)
                        Tooltip(
                          message: entry.key,
                          child: Semantics(
                            label: '${entry.key} background',
                            selected: value.background == entry.key,
                            child: InkWell(
                              onTap: () =>
                                  change(value.copyWith(background: entry.key)),
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: entry.value,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: value.background == entry.key
                                        ? colors.primary
                                        : colors.outlineVariant,
                                    width: value.background == entry.key
                                        ? 3
                                        : 1,
                                  ),
                                ),
                                child: value.background == entry.key
                                    ? Icon(
                                        Icons.check,
                                        color:
                                            entry.value.computeLuminance() > .5
                                            ? Colors.black
                                            : Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Eyebrow('GESTURES & CONTROLS'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: value.tapZones,
                    decoration: const InputDecoration(labelText: 'Tap zones'),
                    items: const [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('Edges turn pages · center opens controls'),
                      ),
                      DropdownMenuItem(
                        value: 'wideCenter',
                        child: Text('Narrow edges · larger center area'),
                      ),
                      DropdownMenuItem(
                        value: 'disabled',
                        child: Text('Tap anywhere for controls'),
                      ),
                    ],
                    isExpanded: true,
                    selectedItemBuilder: (c) => const [
                      Text('Standard edges'),
                      Text('Larger center'),
                      Text('Controls only'),
                    ],
                    onChanged: (v) => change(value.copyWith(tapZones: v)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Double-tap zoom')),
                      Text('${value.doubleTapScale.toStringAsFixed(1)}×'),
                    ],
                  ),
                  Slider(
                    value: value.doubleTapScale,
                    min: 1.5,
                    max: 4,
                    divisions: 5,
                    onChanged: (v) => change(value.copyWith(doubleTapScale: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hide controls automatically'),
                    value: value.autoHide,
                    onChanged: (v) => change(value.copyWith(autoHide: v)),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 20),
                    const Eyebrow('SCREEN BRIGHTNESS'),
                    Slider(
                      value: brightness < 0 ? .5 : brightness,
                      min: .02,
                      max: 1,
                      onChanged: (v) {
                        setState(() => brightness = v);
                        widget.onBrightness(v);
                      },
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => brightness = -1);
                        widget.onBrightness(-1);
                      },
                      icon: const Icon(Icons.brightness_auto_outlined),
                      label: const Text('Use system brightness'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await widget.onDefault(value);
                        if (mounted) setState(() => savedDefault = true);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not save reader defaults: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      savedDefault ? Icons.check : Icons.copy_all_outlined,
                    ),
                    label: Text(
                      savedDefault
                          ? 'Saved as your default'
                          : 'Use for new stories',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        final defaults = await widget.onReset();
                        if (mounted) {
                          setState(() => value = defaults);
                          widget.onChanged(defaults);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not restore reader defaults: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Reset this story to your defaults'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
