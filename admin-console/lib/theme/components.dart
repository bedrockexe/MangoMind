import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'interactions.dart';

/// Shared building-block widgets for MangoMind.
///
/// These capture the UI patterns that were being re-coded on almost every
/// screen (rounded outlined cards, section titles, empty states, status pills)
/// so screens stay short and consistent and a single change here updates the
/// whole app. All colors come from the theme, so light/dark mode just work.

/// A rounded, outlined surface card — the default container for grouped
/// content. Optionally tappable (with [Pressable] press feedback) and
/// selectable (draws a primary-colored border when [selected]).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space4),
    this.onTap,
    this.selected = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}

/// A small section title, e.g. "Account", "Today's tasks". Uppercased and
/// letter-spaced so it reads as a label rather than body text.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(
      left: AppTheme.space1,
      bottom: AppTheme.space2,
    ),
    this.trailing,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );

    return Padding(
      padding: padding,
      child: trailing == null
          ? label
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [label, trailing!],
            ),
    );
  }
}

/// A centered empty / placeholder state: an icon, a title, an optional message
/// and an optional action button. Replaces the bespoke "No X yet" columns.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.primary),
            const SizedBox(height: AppTheme.space3),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppTheme.space1 + 2),
              Text(
                message!,
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.space4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Semantic intent for [AppStatusChip].
enum StatusTone { neutral, success, warning, danger, info }

/// A compact status pill (e.g. "Soil: Loam", "Anthracnose", "Registered").
/// [tone] picks a semantic color pair from the theme; an optional [icon] is
/// shown before the label.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip(
    this.label, {
    super.key,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    late final Color bg;
    late final Color fg;
    switch (tone) {
      case StatusTone.neutral:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
      case StatusTone.success:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
      case StatusTone.warning:
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
      case StatusTone.danger:
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
      case StatusTone.info:
        bg = scheme.secondaryContainer;
        fg = scheme.onSecondaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, color: fg),
          ),
        ],
      ),
    );
  }
}
