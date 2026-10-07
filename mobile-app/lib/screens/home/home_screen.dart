import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../calls/call_screen.dart';
import '../../services/webrtc_service.dart';
import '../../theme/design_system.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _targetIdController = TextEditingController();
  final WebRTCService _webRTCService = WebRTCService();

  @override
  void initState() {
    super.initState();
    _webRTCService.onIncomingCall = (offer) {

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return IncomingCallDialog(
            user: widget.user,
            offer: offer,
            webRTCService: _webRTCService,
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      );
    };

    _webRTCService.listenForIncomingCalls(widget.user.aegisId);
  }

  void _logout(BuildContext context) async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        AegisPageTransition.fadeTransition(const LoginScreen()),
      );
    }
  }

  void _startCall() {
    final targetId = _targetIdController.text.trim();
    if (targetId.isNotEmpty) {
      Navigator.push(
        context,
        AegisPageTransition.fadeTransition(
          CallScreen(
            currentUser: widget.user,
            targetAegisId: targetId,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _targetIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.3, 0.0),
            radius: 1.5,
            colors: [
              Color(0xFF131A1C),
              Color(0xFF080B0D),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 900;
            return Column(
              children: [
                _buildNavBar(),
                Expanded(
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 1, child: _buildLeftColumn(isDesktop)),
                            Expanded(flex: 1, child: const NetworkMeshGraphic()),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildLeftColumn(isDesktop),
                              const SizedBox(height: 500, child: NetworkMeshGraphic()),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF82E8B9), size: 28),
              const SizedBox(width: 12),
              Text(
                'AegisMesh',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (MediaQuery.of(context).size.width > 700)
            Row(
              children: const [
                HoverNavButton(title: 'Dashboard', isActive: true),
                HoverNavButton(title: 'Calls'),
                HoverNavButton(title: 'Security'),
                HoverNavButton(title: 'Activity'),
              ],
            ),
          Row(
            children: [
              const PulsingDot(),
              const SizedBox(width: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey[800],
                      child: Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(widget.user.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 16),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.logout, color: Colors.grey[400]),
                onPressed: () => _logout(context),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLeftColumn(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60.0 : 24.0,
        vertical: isDesktop ? 40.0 : 24.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome, ${widget.user.name}',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w600, letterSpacing: -1),
          ),
          const SizedBox(height: 12),
          Text(
            'Your secure communication network is ready.',
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF82E8B9).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF82E8B9).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Aegis ID: ${widget.user.aegisId}',
                  style: GoogleFonts.inter(color: const Color(0xFF82E8B9), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF82E8B9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF82E8B9).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const PulsingDot(),
                    const SizedBox(width: 8),
                    Text('Protected', style: GoogleFonts.inter(color: const Color(0xFF82E8B9), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          // Glassmorphism Card
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Dial an Aegis ID', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('Connect securely through the AegisMesh network.', style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14)),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: TextField(
                        controller: _targetIdController,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'USER-XXXX or SCAM-XXXX',
                          hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.key, color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    HoverSecureCallButton(onPressed: _startCall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _statusPill('Network Status: Active', showDot: true),
              _statusPill('Encrypted Tunnel: On'),
              _statusPill('Secure Connections: AES-256'),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statusPill(String text, {bool showDot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
          if (showDot) ...[
            const SizedBox(width: 8),
            const PulsingDot(size: 6),
          ]
        ],
      ),
    );
  }
}

class IncomingCallDialog extends StatefulWidget {
  final UserModel user;
  final dynamic offer;
  final WebRTCService webRTCService;

  const IncomingCallDialog({
    Key? key,
    required this.user,
    required this.offer,
    required this.webRTCService,
  }) : super(key: key);

  @override
  _IncomingCallDialogState createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> with SingleTickerProviderStateMixin {
  late AnimationController _sonarController;
  bool _isDeclineHovered = false;
  bool _isAcceptHovered = false;

  @override
  void initState() {
    super.initState();
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _sonarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const PulsingDot(size: 6),
                        const SizedBox(width: 8),
                        Text(
                          'INCOMING SECURE CONNECTION',
                          style: GoogleFonts.inter(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Caller Identity (Center Column)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Sonar Animation behind
                        AnimatedBuilder(
                          animation: _sonarController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(120, 120),
                              painter: _SonarPainter(_sonarController.value),
                            );
                          },
                        ),
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF131A1C), Color(0xFF080B0D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF82E8B9).withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(color: const Color(0xFF82E8B9).withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.shield, color: Color(0xFF82E8B9), size: 36),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'UNKNOWN CALLER',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'End-to-End Encrypted (AES-256)',
                      style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 40),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: MouseRegion(
                            onEnter: (_) => setState(() => _isDeclineHovered = true),
                            onExit: (_) => setState(() => _isDeclineHovered = false),
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                  boxShadow: _isDeclineHovered
                                      ? [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.2), blurRadius: 12)]
                                      : [],
                                ),
                                transform: _isDeclineHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
                                transformAlignment: Alignment.center,
                                child: const Icon(Icons.call_end, color: Color(0xFFEF4444)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: MouseRegion(
                            onEnter: (_) => setState(() => _isAcceptHovered = true),
                            onExit: (_) => setState(() => _isAcceptHovered = false),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  AegisPageTransition.fadeTransition(
                                    CallScreen(
                                      currentUser: widget.user,
                                      targetAegisId: 'Unknown',
                                      isIncoming: true,
                                      offer: widget.offer,
                                      callId: widget.webRTCService.currentCallId,
                                    ),
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF82E8B9),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: _isAcceptHovered
                                      ? [BoxShadow(color: const Color(0xFF82E8B9).withValues(alpha: 0.4), blurRadius: 16)]
                                      : [],
                                ),
                                transform: _isAcceptHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
                                transformAlignment: Alignment.center,
                                child: const Icon(Icons.call, color: Color(0xFF080B0D)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SonarPainter extends CustomPainter {
  final double animationValue;

  _SonarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF82E8B9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      // Offset phases to have multiple rings
      final phase = (animationValue + (i * 0.33)) % 1.0;
      final radius = maxRadius * phase;
      // Fade out as it expands
      final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.3; // max opacity 0.3
      
      paint.color = const Color(0xFF82E8B9).withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PulsingDot extends StatefulWidget {
  final double size;
  const PulsingDot({Key? key, this.size = 8}) : super(key: key);
  @override
  _PulsingDotState createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.2).chain(CurveTween(curve: Curves.easeInOut)), weight: 1.0),
    ]).animate(_controller);
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 1.0),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: const BoxDecoration(
                color: Color(0xFF82E8B9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xFF82E8B9), blurRadius: 8)
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class HoverNavButton extends StatefulWidget {
  final String title;
  final bool isActive;
  const HoverNavButton({Key? key, required this.title, this.isActive = false}) : super(key: key);
  @override
  _HoverNavButtonState createState() => _HoverNavButtonState();
}

class _HoverNavButtonState extends State<HoverNavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                color: widget.isActive || _isHovered ? Colors.white : Colors.grey[500]!,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(widget.title),
            ),
            if (widget.isActive) ...[
              const SizedBox(height: 4),
              Container(
                height: 2,
                width: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF82E8B9),
                  boxShadow: [BoxShadow(color: Color(0xFF82E8B9), blurRadius: 4)],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class HoverSecureCallButton extends StatefulWidget {
  final VoidCallback onPressed;
  const HoverSecureCallButton({Key? key, required this.onPressed}) : super(key: key);
  @override
  _HoverSecureCallButtonState createState() => _HoverSecureCallButtonState();
}

class _HoverSecureCallButtonState extends State<HoverSecureCallButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF82E8B9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (_isHovered)
                BoxShadow(color: const Color(0xFF82E8B9).withValues(alpha: 0.3), blurRadius: 12)
            ],
          ),
          transform: _isHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Start Secure Call', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF064E3B))),
              const SizedBox(width: 12),
              const Icon(Icons.phone_outlined, color: Color(0xFF064E3B)),
            ],
          ),
        ),
      ),
    );
  }
}

class NetworkMeshGraphic extends StatefulWidget {
  const NetworkMeshGraphic({Key? key}) : super(key: key);
  @override
  _NetworkMeshGraphicState createState() => _NetworkMeshGraphicState();
}

class _NetworkMeshGraphicState extends State<NetworkMeshGraphic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 40,
          child: Column(
            children: [
              Text('SECURE COMMUNICATION MESH', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('NETWORK TOPOLOGY', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12, letterSpacing: 1.5)),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(double.infinity, 600),
              painter: TopologyPainter(animationValue: _controller.value),
            );
          },
        ),
      ],
    );
  }
}

class TopologyPainter extends CustomPainter {
  final double animationValue;
  TopologyPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final center = Offset(centerX, centerY);
    final green = const Color(0xFF82E8B9);

    final nodes = [
      {'id': 'AES-256', 'angle': -math.pi / 2, 'dist': 180.0},
      {'id': 'NODE-31', 'angle': -math.pi / 4, 'dist': 220.0},
      {'id': 'NODE-26', 'angle': 0.0, 'dist': 250.0},
      {'id': 'NODE-39', 'angle': math.pi / 4, 'dist': 220.0},
      {'id': 'NODE-21', 'angle': math.pi / 2, 'dist': 180.0},
      {'id': 'NODE-31', 'angle': 3 * math.pi / 4, 'dist': 220.0},
      {'id': 'GATEWAY-09', 'angle': math.pi, 'dist': 250.0},
      {'id': 'NODE-31', 'angle': -3 * math.pi / 4, 'dist': 220.0},
    ];

    final positions = <Offset>[];
    for (var node in nodes) {
      final angle = node['angle'] as double;
      final dist = node['dist'] as double;
      positions.add(Offset(centerX + math.cos(angle) * dist, centerY + math.sin(angle) * dist));
    }

    // Breathing glow (expands and contracts gracefully)
    double breath = math.sin(animationValue * math.pi * 2); // -1 to 1
    
    // Draw paths and particles
    for (int i = 0; i < positions.length; i++) {
      final target = positions[i];
      final angle = nodes[i]['angle'] as double;
      final dist = nodes[i]['dist'] as double;

      for (int j = -2; j <= 2; j++) {
        final isCenter = j == 0;
        final spread = j * (math.pi / 12);
        final cpAngle = angle + spread;
        final cpDist = dist * 0.6;
        final cp = Offset(centerX + math.cos(cpAngle) * cpDist, centerY + math.sin(cpAngle) * cpDist);

        final path = Path()
          ..moveTo(centerX, centerY)
          ..quadraticBezierTo(cp.dx, cp.dy, target.dx, target.dy);

        final p = Paint()
          ..color = isCenter ? green.withValues(alpha: 0.3) : green.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCenter ? 1.5 : 0.5;

        canvas.drawPath(path, p);

        // Data Flow Particles
        if (j % 2 == 0) { // Add particles to some paths
          final metrics = path.computeMetrics().toList();
          if (metrics.isNotEmpty) {
            final pathMetric = metrics.first;
            // offset particle animation phase based on path index
            final phaseOffset = (i * 0.2 + j * 0.1);
            final particleAnim = (animationValue + phaseOffset) % 1.0;
            final offset = pathMetric.getTangentForOffset(pathMetric.length * particleAnim)?.position;
            if (offset != null) {
              canvas.drawCircle(
                offset, 
                2.0, 
                Paint()
                  ..color = green
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0)
              );
            }
          }
        }
      }
    }

    // Draw Outer Nodes
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final name = nodes[i]['id'] as String;

      canvas.drawCircle(pos, 12, Paint()..color = green.withValues(alpha: 0.05)..style = PaintingStyle.fill);
      canvas.drawCircle(pos, 12, Paint()..color = green.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 1);
      canvas.drawCircle(pos, 4, Paint()..color = green..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

      final textPainter = TextPainter(
        text: TextSpan(text: name, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final angle = nodes[i]['angle'] as double;
      double lx = pos.dx;
      double ly = pos.dy;
      if (angle.abs() < 0.1) { lx += 20; ly -= 5; }
      else if (angle.abs() > math.pi - 0.1) { lx -= textPainter.width + 20; ly -= 5; }
      else if (angle > 0) { ly += 20; lx -= textPainter.width / 2; }
      else { ly -= 30; lx -= textPainter.width / 2; }

      textPainter.paint(canvas, Offset(lx, ly));
    }

    // Animate soft BoxShadow glow behind the central shield node
    final glowRadius = 25.0 + (breath * 10.0);
    canvas.drawCircle(
      center, 
      glowRadius, 
      Paint()
        ..color = green.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25.0)
    );

    // Draw Center Node (Shield approximation)
    final centerGlowSizes = [80.0, 65.0, 50.0, 35.0];
    for (int i = 0; i < centerGlowSizes.length; i++) {
      final op = 0.05 + (i * 0.05) + (breath * 0.02);
      canvas.drawCircle(
        center, 
        centerGlowSizes[i], 
        Paint()..color = green.withValues(alpha: op.clamp(0.0, 1.0))..style = PaintingStyle.stroke..strokeWidth = 1
      );
    }
    
    canvas.drawCircle(center, 22, Paint()..color = green.withValues(alpha: 0.15)..style = PaintingStyle.fill);
    canvas.drawCircle(center, 22, Paint()..color = green.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 2);

    final shieldPaint = Paint()..color = green..style = PaintingStyle.fill;
    final shieldPath = Path()
      ..moveTo(centerX, centerY - 10)
      ..lineTo(centerX + 8, centerY - 6)
      ..lineTo(centerX + 8, centerY + 2)
      ..cubicTo(centerX + 8, centerY + 8, centerX, centerY + 12, centerX, centerY + 12)
      ..cubicTo(centerX, centerY + 12, centerX - 8, centerY + 8, centerX - 8, centerY + 2)
      ..lineTo(centerX - 8, centerY - 6)
      ..close();
    canvas.drawPath(shieldPath, shieldPaint);
  }

  @override
  bool shouldRepaint(covariant TopologyPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
