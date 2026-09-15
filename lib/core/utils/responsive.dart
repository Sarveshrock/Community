import 'package:flutter/widgets.dart';

import '../constants/app_constants.dart';

enum ScreenSize { mobile, tablet, desktop }

/// Custom breakpoint helper (spec section 66). Prefer this over hardcoded
/// widths so layouts adapt across small Android phones through tablets.
class Responsive {
  Responsive._();

  static ScreenSize screenSizeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppConstants.desktopBreakpoint) return ScreenSize.desktop;
    if (width >= AppConstants.tabletBreakpoint) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  static bool isTabletOrLarger(BuildContext context) =>
      screenSizeOf(context) != ScreenSize.mobile;

  /// Number of grid columns for card-based lists (people, jobs, projects...).
  static int gridColumns(BuildContext context) {
    switch (screenSizeOf(context)) {
      case ScreenSize.mobile:
        return 1;
      case ScreenSize.tablet:
        return 2;
      case ScreenSize.desktop:
        return 3;
    }
  }

  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width > AppConstants.maxContentWidth
        ? AppConstants.maxContentWidth
        : width;
  }
}

/// Centers and caps content width on large screens (tablets/desktop) while
/// staying full-width on phones.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppConstants.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
