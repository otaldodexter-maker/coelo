abstract final class CoeloSpacing {
  static const double space0 = 0;
  static const double spaceHalf = 2;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;
  static const double space20 = 80;
  static const double space24 = 96;
}

abstract final class CoeloRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
}

abstract final class CoeloElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
  static const double level3 = 3;
}

abstract final class CoeloMotion {
  static const instant = Duration.zero;
  static const fast = Duration(milliseconds: 100);
  static const short = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 220);
  static const enter = Duration(milliseconds: 280);
  static const emphasized = Duration(milliseconds: 360);
}

abstract final class CoeloSize {
  static const double touchMin = 48;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double brandMarkLg = 80;
  static const double brandSignatureMd = 200;
  static const double brandSignatureLg = 240;
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 48;
}
