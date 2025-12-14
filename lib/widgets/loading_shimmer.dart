// widgets/loading_shimmer.dart - Modern Loading UI
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class LoadingShimmer extends StatelessWidget {
  final String? message;
  
  const LoadingShimmer({
    Key? key,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading.json',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          
          Text(
            message ?? 'Loading',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6366F1),
              ),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingCard extends StatelessWidget {
  const LoadingCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A1A1A),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: const Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }
}

class MiniLoading extends StatelessWidget {
  final String? text;
  final Color? color;
  
  const MiniLoading({
    Key? key,
    this.text,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color ?? Colors.white,
          ),
        ),
        if (text != null) ...[
          const SizedBox(width: 8),
          Text(
            text!,
            style: GoogleFonts.inter(
              color: color ?? Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}