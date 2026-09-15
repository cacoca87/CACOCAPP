import 'package:flutter/material.dart';

/// Transición "hoja que sube desde abajo", como el Now Playing de
/// Spotify/Apple Music al tocar el mini-reproductor. El slide
/// horizontal default de Android tiene sentido para navegar a una
/// sección nueva, pero para "expandir" el reproductor que ya está
/// sonando, una hoja que sube se siente mucho más premium y además
/// comunica mejor la relación entre el mini player y la pantalla
/// completa.
Route<T> rutaDesdeAbajo<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curva = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curva),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    },
  );
}