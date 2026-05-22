import 'package:flutter/material.dart';

/// A premium slide-up + fade page route used across the entire Kindrop app.
/// Usage: Navigator.push(context, KindropRoute(builder: (_) => MyScreen()));
class KindropRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  KindropRoute({required this.builder, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide up from bottom 24px + fade in
            final slide = Tween<Offset>(
              begin: const Offset(0.0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
              ),
            );

            // Outgoing screen scales down very slightly
            final outScale = Tween<double>(begin: 1.0, end: 0.96).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeInOut,
              ),
            );

            return ScaleTransition(
              scale: outScale,
              child: SlideTransition(
                position: slide,
                child: FadeTransition(opacity: fade, child: child),
              ),
            );
          },
        );
}
