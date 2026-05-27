import 'package:flutter/material.dart';

class AppTextStyles {
  // Font Families
  static const String fontSans = 'DM Sans';
  static const String fontSerif = 'Fraunces';
  static const String fontMono = 'DM Mono';

  // Headings & Displays (Fraunces)
  static const TextStyle statValue = TextStyle(
    fontFamily: fontSerif,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -1,
  );
  
  static const TextStyle emptyStateHeading = TextStyle(
    fontFamily: fontSerif,
    fontSize: 22,
    fontWeight: FontWeight.w300,
  );

  static const TextStyle brandHeading = TextStyle(
    fontFamily: fontSerif,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  static const TextStyle dropHeading = TextStyle(
    fontFamily: fontSerif,
    fontSize: 20,
    fontWeight: FontWeight.w300,
  );

  static const TextStyle topbarTitle = TextStyle(
    fontFamily: fontSerif,
    fontSize: 15,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
  );

  // Body Texts (DM Sans)
  static const TextStyle navItem = TextStyle(
    fontFamily: fontSans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: fontSans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontSans,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  // Captions & Metas (DM Sans)
  static const TextStyle dropDivider = TextStyle(
    fontFamily: fontSans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontSans,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8, // Setara dengan 0.08em
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: fontSans,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );

  // Monospace (DM Mono)
  static const TextStyle fileMeta = TextStyle(
    fontFamily: fontMono,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle brandTag = TextStyle(
    fontFamily: fontMono,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.22, // Setara dengan 0.02em
  );

  static const TextStyle navBadge = TextStyle(
    fontFamily: fontMono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );
}
