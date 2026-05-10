import 'package:flutter/material.dart';

/// Large collapsing app bar — title shrinks as content scrolls.
///
/// `bottom` slot for TabBar / search field. `actions` for icons.
class SliverHeroAppBar extends StatelessWidget {
  const SliverHeroAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final baseHeight = subtitle == null ? 132.0 : 156.0;
    return SliverAppBar.large(
      pinned: true,
      stretch: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      expandedHeight: baseHeight + bottomHeight,
      actions: actions,
      bottom: bottom,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsetsDirectional.only(
          start: 20,
          bottom: 16 + bottomHeight,
          end: 20,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
