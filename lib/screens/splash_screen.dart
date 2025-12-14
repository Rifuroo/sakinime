import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _progressController;
  late AnimationController _shimmerController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _scaleController.forward();
    _progressController.forward();
    
    _navigateToHome();
  }

  void _navigateToHome() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    _progressController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0a0e27),
              const Color(0xFF1a1f3a),
              const Color(0xFF2d1b4e),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated gradient orbs
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rotateController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: GradientOrbsPainter(
                      animation: _rotateController.value,
                    ),
                  );
                },
              ),
            ),
            
            // Floating particles
            ...List.generate(20, (index) => _buildParticle(index, size)),
            
            // Glass morphism rings
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rotateController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: GlassRingsPainter(
                      animation: _rotateController.value,
                    ),
                  );
                },
              ),
            ),
            
            // Main content
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with premium glow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.6),
                                blurRadius: 80,
                                spreadRadius: 30,
                              ),
                              BoxShadow(
                                color: Colors.purpleAccent.withOpacity(0.4),
                                blurRadius: 120,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                          child: Lottie.asset(
                            'assets/animations/splash.json',
                            width: 280,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // App title with shimmer
                        AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => LinearGradient(
                                begin: Alignment(_shimmerAnimation.value - 1, 0),
                                end: Alignment(_shimmerAnimation.value + 1, 0),
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.white,
                                  Colors.purpleAccent,
                                  Colors.white,
                                  Colors.white.withOpacity(0.3),
                                ],
                                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                              ).createShader(bounds),
                              child: Text(
                                'Sukinime',
                                style: GoogleFonts.poppins(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  height: 1,
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Subtitle with glass effect
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  'Stream Your Favorite Anime',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 80),
                        
                        // Modern loading bar
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Column(
                              children: [
                                // Progress bar
                                Container(
                                  width: 200,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Animated gradient bar
                                      FractionallySizedBox(
                                        widthFactor: _progressAnimation.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.deepPurple,
                                                Colors.purpleAccent,
                                                Colors.pinkAccent,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.purpleAccent.withOpacity(0.6),
                                                blurRadius: 15,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Shimmer effect
                                      if (_progressAnimation.value > 0)
                                        Positioned(
                                          left: _progressAnimation.value * 180,
                                          child: Container(
                                            width: 20,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white.withOpacity(0.6),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Loading text
                                Text(
                                  _getLoadingText(_progressAnimation.value),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Bottom info
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copyright_rounded,
                                size: 14,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '2025 Riplo',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticle(int index, Size size) {
    final random = (index * 47) % 100;
    final particleSize = 2.0 + (random % 3);
    final speed = 3000 + (random % 10) * 200;
    
    return Positioned(
      left: (random * size.width / 100) % size.width,
      top: (random * size.height / 100) % size.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: speed),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(
              math.sin(value * 2 * math.pi + index) * 30,
              math.cos(value * 2 * math.pi + index) * 30,
            ),
            child: Opacity(
              opacity: 0.3 * math.sin(value * math.pi),
              child: Container(
                width: particleSize,
                height: particleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purpleAccent.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        onEnd: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  String _getLoadingText(double progress) {
    if (progress < 0.4) return 'Loading...';
    if (progress < 0.7) return 'Almost there...';
    return 'Ready!';
  }
}

class GradientOrbsPainter extends CustomPainter {
  final double animation;
  GradientOrbsPainter({required this.animation});
  
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final offset = animation * 2 * math.pi + (i * 2.1);
      final x = size.width * 0.5 + math.cos(offset) * size.width * 0.35;
      final y = size.height * 0.5 + math.sin(offset) * size.height * 0.35;
      
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            i == 0 ? Colors.deepPurple.withOpacity(0.2) :
            i == 1 ? Colors.purple.withOpacity(0.15) :
            Colors.pinkAccent.withOpacity(0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(x, y),
          radius: size.width * 0.4,
        ));
      
      canvas.drawCircle(Offset(x, y), size.width * 0.4, paint);
    }
  }
  
  @override
  bool shouldRepaint(GradientOrbsPainter oldDelegate) => true;
}

class GlassRingsPainter extends CustomPainter {
  final double animation;
  GlassRingsPainter({required this.animation});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (int i = 0; i < 4; i++) {
      final radius = 150.0 + (i * 70) + (math.sin(animation * 2 * math.pi + i) * 10);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = SweepGradient(
          colors: [
            Colors.deepPurple.withOpacity(0.15),
            Colors.purpleAccent.withOpacity(0.2),
            Colors.pinkAccent.withOpacity(0.15),
            Colors.deepPurple.withOpacity(0.15),
          ],
          transform: GradientRotation(animation * 2 * math.pi),
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      
      canvas.drawCircle(center, radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(GlassRingsPainter oldDelegate) => true;
}