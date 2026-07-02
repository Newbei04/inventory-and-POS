import 'package:flutter/material.dart';

Route<T> slideIn<T>(Widget page) => PageRouteBuilder(
      pageBuilder: (context, animation, secondary) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        const begin = Offset(0.15, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        return SlideTransition(
          position: Tween(begin: begin, end: end).chain(CurveTween(curve: curve)).animate(animation),
          child: FadeTransition(
            opacity: Tween(begin: 0.0, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );

Route<T> fadeIn<T>(Widget page) => PageRouteBuilder(
      pageBuilder: (context, animation, secondary) => page,
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    );
