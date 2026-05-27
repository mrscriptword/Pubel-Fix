import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget desktopBody;
  final double breakpoint;

  const ResponsiveLayout({
    Key? key,
    required this.mobileBody,
    required this.desktopBody,
    this.breakpoint = 800,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return mobileBody;
        } else {
          return desktopBody;
        }
      },
    );
  }
}
