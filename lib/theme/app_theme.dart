import 'package:flutter/material.dart';

class AppColors {
  static const primary = Colors.blue;
  static const price = Colors.blue;
  static const profit = Colors.green;
  static const loss = Colors.red;
  static const warning = Colors.orange;
  static const lowStock = Colors.red;
  static const stockAdd = Colors.green;
  static const stockSale = Colors.red;
  static const stockAdjust = Colors.orange;

  static Color chipBg(Color c) => c.withValues(alpha: 0.1);
  static Color chipText(MaterialColor c) => c.shade700;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(md);
  static const EdgeInsets list = EdgeInsets.fromLTRB(lg, xs, lg, 80);
}

class AppText {
  static const TextStyle price = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: AppColors.price,
  );

  static const TextStyle largePrice = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 48,
    color: AppColors.price,
  );

  static const TextStyle name = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  static const TextStyle nameSmall = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    color: Colors.grey,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: Colors.black87,
  );

  static const String peso = '\u20B1';
}

class AppCard {
  static ShapeBorder rounded({double radius = 16}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  static BoxDecoration outline(BuildContext context) => BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      );

  static EdgeInsets get padding => const EdgeInsets.all(12);
}
