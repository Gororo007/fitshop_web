import 'package:flutter/material.dart';

class Breakpoints {
  Breakpoints._();

  static const mobileMax = 600.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < mobileMax;
  }
}
