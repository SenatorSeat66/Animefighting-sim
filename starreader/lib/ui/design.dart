import 'dart:math' as math;

import 'package:flutter/material.dart';

const starMint = Color(0xffbde9d1);
const starGold = Color(0xffe8cc97);

class StarTheme {
  static ThemeData build(
    Brightness brightness, {
    required Color accent,
    bool amoled = false,
  }) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      primary: dark ? accent : base.primary,
      surface: dark
          ? (amoled ? Colors.black : const Color(0xff101613))
          : const Color(0xfff7f6f0),
      surfaceContainer: dark
          ? const Color(0xff19231e)
          : const Color(0xffefeee6),
      surfaceContainerHigh: dark
          ? const Color(0xff25332b)
          : const Color(0xffe5e9df),
      outlineVariant: dark ? const Color(0xff304238) : const Color(0xffd7ded2),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Manrope',
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .55),
        space: 1,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.3),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: .19),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary.withValues(alpha: .19),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.all(16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          color: scheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -.9,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: scheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {this.color, super.key});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: color ?? Theme.of(context).colorScheme.primary,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.0,
    ),
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle, actionLabel;
  final VoidCallback? onAction;
  const SectionHeading(
    this.title, {
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel ?? 'See all'),
          ),
      ],
    ),
  );
}

class QuietBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const QuietBadge(this.text, {this.icon, this.color, super.key});
  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Original geometric constellation illustration, rendered at device resolution.
class OrbitArt extends StatelessWidget {
  final double size;
  const OrbitArt({this.size = 150, super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _OrbitPainter()),
  );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width * .54, s.height * .5);
    final r = s.width * .34;
    final line = Paint()
      ..color = starMint.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(-.55);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2.7, height: r * 1.2),
      line,
    );
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.2, height: r * 2.7),
      line,
    );
    c.restore();
    void star(Offset at, double radius, Color color) {
      final p = Path();
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 - math.pi / 2;
        final rr = i.isEven ? radius : radius * .26;
        final point = at + Offset(math.cos(angle) * rr, math.sin(angle) * rr);
        if (i == 0) {
          p.moveTo(point.dx, point.dy);
        } else {
          p.lineTo(point.dx, point.dy);
        }
      }
      p.close();
      c.drawPath(p, Paint()..color = color);
    }

    star(center, r * .65, starMint);
    star(Offset(s.width * .82, s.height * .2), r * .23, starGold);
    star(Offset(s.width * .18, s.height * .7), r * .16, starMint);
    for (final point in [
      Offset(s.width * .12, s.height * .3),
      Offset(s.width * .8, s.height * .8),
      Offset(s.width * .45, s.height * .1),
    ]) {
      c.drawCircle(point, 2, Paint()..color = starGold.withValues(alpha: .7));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}
