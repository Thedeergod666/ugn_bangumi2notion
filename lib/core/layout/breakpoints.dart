enum ScreenSize {
  narrow,
  medium,
  wide,
}

class Breakpoints {
  static const double narrow = 720;
  static const double wide = 1100;

  static ScreenSize sizeForWidth(double width) {
    if (width < narrow) {
      return ScreenSize.narrow;
    }
    if (width < wide) {
      return ScreenSize.medium;
    }
    return ScreenSize.wide;
  }

  static bool isNarrow(double width) => sizeForWidth(width) == ScreenSize.narrow;

  static bool isMedium(double width) => sizeForWidth(width) == ScreenSize.medium;

  static bool isWide(double width) => sizeForWidth(width) == ScreenSize.wide;

  static double contentWidth(double width, {double maxWidth = 1200}) {
    if (width <= maxWidth) {
      return width;
    }
    return maxWidth;
  }
}
