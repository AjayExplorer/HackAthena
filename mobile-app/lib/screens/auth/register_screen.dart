import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../../theme/design_system.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    setState(() => _isLoading = true);
    var user = await _authService.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (user != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          AegisPageTransition.fadeTransition(HomeScreen(user: user)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed.', style: GoogleFonts.inter()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AegisBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 900;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 80.0 : 24.0,
                  vertical: 40.0,
                ),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildLeftColumn()),
                          const SizedBox(width: 80),
                          Expanded(child: Center(child: _buildRightColumn())),
                        ],
                      )
                    : Column(
                        children: [
                          _buildLeftColumn(),
                          const SizedBox(height: 60),
                          _buildRightColumn(),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, color: AegisColors.accentGreen, size: 40),
            const SizedBox(width: 16),
            Text(
              'AEGISMESH',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AegisColors.textPrimary,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Text(
          'Join the secure\ndecentralized\nnetwork.',
          style: GoogleFonts.inter(
            fontSize: 48,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.2,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Create your Aegis ID and instantly connect with your team\nthrough military-grade encrypted tunnels.',
          style: GoogleFonts.inter(
            fontSize: 18,
            color: AegisColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return AegisGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Create Account',
            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign up for AegisMesh',
            style: GoogleFonts.inter(fontSize: 16, color: AegisColors.textSecondary),
          ),
          const SizedBox(height: 40),
          AegisTextField(
            controller: _nameController,
            hintText: 'Full Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          AegisTextField(
            controller: _emailController,
            hintText: 'Enter your email',
            icon: Icons.mail_outline,
          ),
          const SizedBox(height: 16),
          AegisTextField(
            controller: _passwordController,
            hintText: 'Create a password',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 32),
          AegisButton(
            text: 'Register',
            onPressed: _register,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account? ",
                style: GoogleFonts.inter(color: AegisColors.textSecondary),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Login here',
                    style: GoogleFonts.inter(color: AegisColors.accentGreen, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
