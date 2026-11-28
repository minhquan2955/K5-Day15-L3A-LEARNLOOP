import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

const ink = Color(0xff4a2012);
const muted = Color(0xff775541);
const brown = Color(0xff8a4a2a);
const cream = Color(0xfffdf6ec);
const beige = Color(0xfff5e4d0);
const surface = Color(0xfffffbf5);
const tint = Color(0xfff6e7d4);
const outline = Color(0xffd9b99a);
const line = Color(0xffebd5be);
const brand = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xffae6b38), Color(0xff773b1b)],
);
const shadow = [
  BoxShadow(color: Color(0x168a4a2a), blurRadius: 14, offset: Offset(0, 3)),
];

TextStyle display(double size, {bool italic = false}) => TextStyle(
  fontFamily: 'Playfair Display',
  fontSize: size,
  fontVariations: const [FontVariation.weight(750)],
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  height: 1.12,
  color: ink,
);
const caption = TextStyle(color: muted, fontSize: 12, height: 1.25);

class TravelScroll extends MaterialScrollBehavior {
  const TravelScroll();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

Future<T?> sheet<T>(BuildContext context, String title, {Widget? body}) =>
    showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      backgroundColor: surface,
      constraints: const BoxConstraints(maxWidth: 460),
      builder: (context) => SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: display(25, italic: true)),
            const SizedBox(height: 12),
            ?body,
          ],
        ),
      ),
    );

class Paper extends StatelessWidget {
  const Paper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [cream, beige],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: Opacity(
            opacity: .20,
            child: Image(
              image: AssetImage('assets/images/paper-texture.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class Art extends StatelessWidget {
  const Art(
    this.name, {
    super.key,
    this.width,
    this.height,
    this.radius = 15,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });
  final String name;
  final double? width, height;
  final double radius;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.asset(
      'assets/images/$name',
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, _, _) => Container(
        width: width,
        height: height,
        color: tint,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: brown),
      ),
    ),
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.action,
    this.home = false,
    this.profile = false,
  });
  final String title, subtitle;
  final IconData? icon;
  final Widget? action;
  final bool home, profile;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: home ? 183 : 135),
    child: Stack(
      children: [
        Positioned.fill(child: BannerArt(profile: profile)),
        Padding(
          padding: EdgeInsets.fromLTRB(home ? 30 : 19, home ? 27 : 49, 16, 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (home)
                const Padding(
                  padding: EdgeInsets.only(left: 69, bottom: 2),
                  child: Art('pagoda.jpg', width: 28, height: 25, radius: 3),
                ),
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: brown, size: 27),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      style: display(home ? 38 : 32, italic: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: display(
                        home ? 14 : 12,
                        italic: true,
                      ).copyWith(color: muted),
                    ),
                  ),
                  if (action != null) ...[const SizedBox(width: 8), action!],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BannerArt extends StatelessWidget {
  const BannerArt({super.key, this.profile = false});
  final bool profile;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          right: -6,
          bottom: 0,
          width: 222,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              colors: [Colors.transparent, Colors.white, Colors.white],
              stops: [0, .58, 1],
            ).createShader(rect),
            child: Art(
              profile ? 'pavilion.jpg' : 'lake.jpg',
              radius: 0,
              alignment: Alignment.center,
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          width: 127,
          height: 62,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, .35, .85],
            ).createShader(rect),
            child: const Art('branch.jpg', radius: 0),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 37,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00fdf6ec), cream],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
      child: Material(
        color: surface.withValues(alpha: .91),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: line),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                hoverColor: tint,
                focusColor: tint,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.trailing,
    this.filled = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon, trailing;
  final bool filled, compact;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : brown;
    final style = TextButton.styleFrom(
      foregroundColor: foreground,
      minimumSize: Size(0, compact ? 44 : 46),
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const StadiumBorder(),
      side: filled ? null : const BorderSide(color: outline),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: filled && onTap != null ? brand : null,
        color: filled && onTap == null ? tint : null,
      ),
      child: TextButton(
        onPressed: onTap,
        style: style,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 14 : 17),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class Meta extends StatelessWidget {
  const Meta(this.icon, this.label, {super.key});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: brown, size: 14),
      const SizedBox(width: 4),
      Flexible(child: Text(label, style: caption)),
    ],
  );
}

class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.action,
  });
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged, onSubmitted;
  final Widget? action;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(28),
      boxShadow: shadow,
      border: Border.all(color: line),
    ),
    child: Row(
      children: [
        const SizedBox(width: 13),
        const Icon(Icons.search, color: brown, size: 23),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: ink, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: caption,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(right: 3), child: action!),
      ],
    ),
  );
}

class RoundAction extends StatelessWidget {
  const RoundAction(
    this.icon,
    this.label, {
    super.key,
    this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled && onTap == null ? tint : surface,
      gradient: filled && onTap != null ? brand : null,
    ),
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: filled ? Colors.white : brown,
        disabledForegroundColor: muted,
      ),
    ),
  );
}
