import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Raised clay surface: diagonal gradient, lit edge and a soft green drop shadow (Clay.js).
class Clay extends StatelessWidget {
  const Clay({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(16),
    this.depth = 1,
    this.colors = const [C.cardTop, C.cardBottom],
  });
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final double depth;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        border: Border.all(color: const Color(0xD9FFFFFF), width: 2),
        boxShadow: [
          BoxShadow(color: const Color.fromRGBO(88, 112, 58, 0.24), blurRadius: 14 * depth, offset: Offset(5 * depth, 8 * depth)),
          BoxShadow(color: const Color.fromRGBO(255, 255, 255, 0.9), blurRadius: 8 * depth, offset: Offset(-3 * depth, -3 * depth)),
        ],
      ),
      child: child,
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: color.withAlpha(0x26), borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: nunito(12.5, w: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// Pressable matcha button.
class ClayButton extends StatefulWidget {
  const ClayButton({super.key, required this.label, required this.onTap, this.icon, this.primary = true, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final Widget? icon;
  final bool primary;
  final bool busy;

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.primary ? Colors.white : C.matchaInk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.busy ? null : widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: const Duration(milliseconds: 90),
        child: Clay(
          radius: 22,
          depth: widget.primary ? 0.9 : 0.6,
          colors: widget.primary ? const [C.matchaLight, C.matchaDark] : const [C.cardTop, C.cardBottom],
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.busy)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
            else if (widget.icon != null)
              widget.icon!,
            if (widget.busy || widget.icon != null) const SizedBox(width: 9),
            Flexible(child: Text(widget.label, style: nunito(16, w: FontWeight.w700, color: fg), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }
}

/// Soil ring gauge (Charts.js Ring).
class Ring extends StatelessWidget {
  const Ring({super.key, required this.size, required this.stroke, required this.value, this.child});
  final double size;
  final double stroke;
  final double value; // 0..100
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 100) / 100),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, p, _) => CustomPaint(painter: _RingPainter(p, stroke), child: Center(child: child)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.stroke);
  final double p;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = C.well);
    if (p <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [Color(0xFFB0CB84), Color(0xFF5F7F3A)],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * p, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.p != p || old.stroke != stroke;
}

/// Airy field-garden backdrop: pale sky, soft sun glow, drifting clouds, rolling hills with crop rows.
class FieldBackdrop extends StatefulWidget {
  const FieldBackdrop({super.key});
  @override
  State<FieldBackdrop> createState() => _FieldBackdropState();
}

class _FieldBackdropState extends State<FieldBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: _FieldPainter(_c), size: Size.infinite));
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  Path _hill(Size s, double base, double amp, double phase, double freq) {
    final p = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width + 4; x += 4) {
      p.lineTo(x, base + amp * math.sin(x / s.width * freq * math.pi * 2 + phase));
    }
    p.lineTo(s.width, s.height);
    p.close();
    return p;
  }

  void _cloud(Canvas c, Offset o, double r, double alpha) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    c.drawCircle(o, r, paint);
    c.drawCircle(o + Offset(r * 1.0, r * 0.18), r * 0.82, paint);
    c.drawCircle(o + Offset(-r * 0.95, r * 0.25), r * 0.7, paint);
    c.drawCircle(o + Offset(r * 0.2, r * 0.38), r * 0.9, paint);
  }

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCDE5EC), Color(0xFFE2F0E6), Color(0xFFEDF1E1)],
          stops: [0, 0.45, 0.8],
        ).createShader(rect),
    );

    // sun glow
    final sun = Offset(s.width * 0.84, s.height * 0.085);
    canvas.drawCircle(
      sun,
      150,
      Paint()..shader = const RadialGradient(colors: [Color(0xE6FFF6D2), Color(0x00FFF6D2)]).createShader(Rect.fromCircle(center: sun, radius: 150)),
    );

    // clouds drift left to right, wrapping
    final span = s.width + 220;
    void drift(double offset, double y, double r, double alpha, double speed) {
      final x = ((t.value * speed + offset) % 1.0) * span - 110;
      _cloud(canvas, Offset(x, y), r, alpha);
    }
    drift(0.05, s.height * 0.07, 24, 0.75, 1);
    drift(0.48, s.height * 0.15, 32, 0.62, 1);
    drift(0.80, s.height * 0.045, 18, 0.55, 2);

    // hills
    final h = s.height;
    canvas.drawPath(_hill(s, h * 0.80, 14, 0.4, 1.1), Paint()..color = const Color(0xFFD7E7BF));
    canvas.drawPath(_hill(s, h * 0.865, 16, 2.1, 0.9), Paint()..color = const Color(0xFFC3DA9F));
    final front = _hill(s, h * 0.93, 12, 4.0, 1.3);
    canvas.drawPath(front, Paint()..color = const Color(0xFFAFCB86));

    // crop rows on the front hill
    final row = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x4D7E9C54);
    for (int k = 1; k <= 3; k++) {
      final path = Path();
      final base = h * 0.93 + k * 15.0 * (1 + k * 0.25);
      for (double x = 0; x <= s.width + 4; x += 4) {
        final y = base + 12 * math.sin(x / s.width * 1.3 * math.pi * 2 + 4.0);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, row);
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) => false;
}
