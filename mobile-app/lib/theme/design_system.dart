import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';

class AegisColors {
  static const Color background = Color(0xFF080B0D);
  static const Color backgroundCenter = Color(0xFF131A1C);
  static const Color accentGreen = Color(0xFF82E8B9);
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color inputBackground = Color(0xFF0D1114);
}

class AegisBackground extends StatefulWidget {
  final Widget child;
  const AegisBackground({Key? key, required this.child}) : super(key: key);

  @override
  _AegisBackgroundState createState() => _AegisBackgroundState();
}

class _AegisBackgroundState extends State<AegisBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.3, 0.0),
          radius: 1.5,
          colors: [
            AegisColors.backgroundCenter,
            AegisColors.background,
          ],
        ),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _DriftingMeshPainter(_controller.value),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _DriftingMeshPainter extends CustomPainter {
  final double animationValue;
  _DriftingMeshPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AegisColors.accentGreen.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;

    final random = math.Random(42);
    final nodes = <Offset>[];
    for (int i = 0; i < 20; i++) {
      nodes.add(Offset(
        random.nextDouble() * size.width + math.sin(animationValue * 2 * math.pi + i) * 20,
        random.nextDouble() * size.height + math.cos(animationValue * 2 * math.pi + i) * 20,
      ));
    }

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        if ((nodes[i] - nodes[j]).distance < 200) {
          canvas.drawLine(nodes[i], nodes[j], paint);
        }
      }
      canvas.drawCircle(nodes[i], 3, Paint()..color = AegisColors.accentGreen.withValues(alpha: 0.05));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AegisGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  const AegisGlassContainer({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.borderRadius = 24.0,
    this.borderColor,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AegisGlassCard extends StatefulWidget {
  final Widget child;
  final double padding;
  final double maxWidth;

  const AegisGlassCard({Key? key, required this.child, this.padding = 40.0, this.maxWidth = 480.0}) : super(key: key);

  @override
  _AegisGlassCardState createState() => _AegisGlassCardState();
}

class _AegisGlassCardState extends State<AegisGlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, val, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: _isHovered
                    ? [BoxShadow(color: AegisColors.accentGreen.withValues(alpha: 0.1), blurRadius: 20)]
                    : [],
              ),
              child: AegisGlassContainer(
                padding: EdgeInsets.all(widget.padding),
                borderColor: _isHovered ? AegisColors.accentGreen.withValues(alpha: 0.3) : null,
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class AegisTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final bool isPassword;
  final Function(String)? onSubmitted;
  final bool compact;

  const AegisTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.isPassword = false,
    this.onSubmitted,
    this.compact = false,
  }) : super(key: key);

  @override
  _AegisTextFieldState createState() => _AegisTextFieldState();
}

class _AegisTextFieldState extends State<AegisTextField> {
  bool _obscureText = true;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AegisColors.inputBackground,
        borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
        border: Border.all(
          color: _isFocused ? AegisColors.accentGreen : Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: _isFocused
            ? [BoxShadow(color: AegisColors.accentGreen.withValues(alpha: 0.15), blurRadius: 12)]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: _obscureText,
        onSubmitted: widget.onSubmitted,
        style: GoogleFonts.inter(color: Colors.white, fontSize: widget.compact ? 14 : 16),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
          prefixIcon: widget.icon != null ? Icon(widget.icon, color: _isFocused ? AegisColors.accentGreen : Colors.grey[500], size: widget.compact ? 20 : 24) : null,
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey[500], size: widget.compact ? 20 : 24),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: widget.compact ? 12 : 20),
        ),
      ),
    );
  }
}

class AegisButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;

  const AegisButton({Key? key, required this.text, this.onPressed, this.isLoading = false, this.color, this.textColor}) : super(key: key);

  @override
  _AegisButtonState createState() => _AegisButtonState();
}

class _AegisButtonState extends State<AegisButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.onPressed == null ? Colors.grey[800] : (widget.color ?? AegisColors.accentGreen);
    final txtColor = widget.textColor ?? const Color(0xFF064E3B);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              if (_isHovered && widget.onPressed != null)
                BoxShadow(color: bgColor!.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))
            ],
          ),
          transform: _isHovered && widget.onPressed != null ? (Matrix4.identity()..scale(1.02, 1.02, 1.0)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(txtColor),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      widget.text,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: txtColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AegisPageTransition {
  static Route<T> fadeTransition<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}

Future<T?> showAegisDialog<T>({required BuildContext context, required Widget child}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutQuint);
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
