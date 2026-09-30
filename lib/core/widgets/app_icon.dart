import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icônes Lucide (trait 1.5), reprises du prototype.
enum AppIcons {
  chevronLeft('<path d="m15 18-6-6 6-6"/>'),
  chevronRight('<path d="m9 18 6-6-6-6"/>'),
  arrowLeft('<path d="m12 19-7-7 7-7M19 12H5"/>'),
  calendar('<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>'),
  sliders('<path d="M21 4h-7M10 4H3M21 12h-9M8 12H3M21 20h-5M12 20H3M14 2v4M8 10v4M16 18v4"/>'),
  rotateCcw('<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>'),
  users(
    '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
  ),
  alertTriangle(
    '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4M12 17h.01"/>',
  ),
  check('<path d="M20 6 9 17l-5-5"/>'),
  x('<path d="M18 6 6 18M6 6l12 12"/>'),
  plus('<path d="M5 12h14M12 5v14"/>'),
  minus('<path d="M5 12h14"/>'),
  send('<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>'),
  copy(
    '<rect width="14" height="14" x="8" y="8" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
  ),
  calendarPlus('<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18M12 14v4M10 16h4"/>');

  const AppIcons(this.body);
  final String body;
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 20, this.color, this.strokeWidth = 1.5});

  final AppIcons icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
      'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">${icon.body}</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: c),
    );
  }
}
