import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The same hand-drawn 24px line icons the web app uses (src/components/Icon.js).
const _icons = <String, List<String>>{
  'thermo': ['<path d="M10 14.2V5.5a2 2 0 1 1 4 0v8.7a4 4 0 1 1-4 0z"/>'],
  'drop': ['<path d="M12 3.5c3.4 4 5.7 6.9 5.7 9.6a5.7 5.7 0 0 1-11.4 0C6.3 10.4 8.6 7.5 12 3.5z"/>'],
  'leaf': ['<path d="M5 19c0-8 5-14 14.5-14.5C19.5 14 14 19.5 5 19z"/>', '<path d="M5 19c3-5.5 6.5-8.5 10-10.5"/>'],
  'wifi': ['<path d="M3 9.5a13.5 13.5 0 0 1 18 0"/>', '<path d="M6 13a9 9 0 0 1 12 0"/>', '<path d="M9 16.5a4.5 4.5 0 0 1 6 0"/>', '<circle cx="12" cy="19.5" r="0.6"/>'],
  'clock': ['<circle cx="12" cy="12" r="8.5"/>', '<path d="M12 7.5V12l3 2"/>'],
  'gauge': ['<path d="M4.5 17a8.5 8.5 0 1 1 15 0"/>', '<path d="M12 13l3.5-4"/>'],
  'chart': ['<path d="M4 4v16h16"/>', '<path d="M8 15l3.5-4.5 3 2.5L19 7"/>'],
  'chevron': ['<path d="M9 6l6 6-6 6"/>'],
  'refresh': ['<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3"/>', '<path d="M19.5 4.5v4h-4"/>'],
  'lock': ['<rect x="5" y="11" width="14" height="9" rx="2.5"/>', '<path d="M8 11V8.5a4 4 0 0 1 8 0V11"/>'],
  'eye': ['<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/>', '<circle cx="12" cy="12" r="3"/>'],
  'eyeoff': ['<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/>', '<circle cx="12" cy="12" r="3"/>', '<path d="M4 4l16 16"/>'],
  'alert': ['<path d="M12 4l8.5 15h-17L12 4z"/>', '<path d="M12 10v4.2"/>', '<path d="M12 16.8v.1"/>'],
  'plus': ['<path d="M12 5v14"/>', '<path d="M5 12h14"/>'],
  'logout': ['<path d="M9.5 4.5h-4v15h4"/>', '<path d="M15 8l4 4-4 4"/>', '<path d="M19 12H9.5"/>'],
  'shield': ['<path d="M12 3.5l7.5 2.8v5.6c0 4.4-3.1 7.5-7.5 8.6-4.4-1.1-7.5-4.2-7.5-8.6V6.3L12 3.5z"/>', '<path d="M9 12l2.2 2.2L15.2 10"/>'],
};

class AgriIcon extends StatelessWidget {
  const AgriIcon(this.name, {super.key, this.size = 22, this.color = const Color(0xFF2A3320), this.sw = 1.8});
  final String name;
  final double size;
  final Color color;
  final double sw;

  @override
  Widget build(BuildContext context) {
    final body = (_icons[name] ?? const []).join();
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000000" '
        'stroke-width="$sw" stroke-linecap="round" stroke-linejoin="round">$body</svg>';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }
}

/// The AgriSense sprout mark (Logo.js).
class Sprout extends StatelessWidget {
  const Sprout({super.key, this.size = 40});
  final double size;

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs><linearGradient id="sg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8DAA63"/><stop offset="1" stop-color="#4D6B2C"/></linearGradient></defs>
  <path d="M32 38C32 27 23 18 11 17C11 29 19 38 32 38Z" fill="url(#sg)"/>
  <path d="M32 32C32 21 41 12 54 11C54 23 45 32 32 32Z" fill="url(#sg)"/>
  <path d="M32 34V50" stroke="#5F7F3A" stroke-width="4.6" stroke-linecap="round"/>
</svg>''';

  @override
  Widget build(BuildContext context) => SvgPicture.string(_svg, width: size, height: size);
}
