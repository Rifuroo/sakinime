import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function(String) onChanged; // sekarang async untuk menandai loading
  final VoidCallback? onClear;

  const CustomSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  Timer? _debounce;
  bool isLoading = false;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => isLoading = true);
      try {
        await widget.onChanged(query);
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
        ),
        onChanged: (value) {
          setState(() {}); // update icon clear
          _onSearchChanged(value); // debounce async call
        },
        onSubmitted: (value) async {
          setState(() => isLoading = true);
          try {
            await widget.onChanged(value);
          } finally {
            if (mounted) setState(() => isLoading = false);
          }
        },
        decoration: InputDecoration(
          hintText: 'Cari anime... (Naruto, One Piece, dll)',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey[500],
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.deepPurple[300],
          ),
          suffixIcon: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        setState(() {});
                        if (widget.onClear != null) {
                          widget.onClear!();
                        }
                      },
                    )
                  : null,
          filled: true,
          fillColor: const Color(0xFF1a1f3a),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2a2f4a)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.deepPurple.withAlpha(77),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.deepPurple,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
