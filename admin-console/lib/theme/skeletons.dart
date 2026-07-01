import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable shimmer skeleton loaders.
///
/// These replace plain `CircularProgressIndicator` spinners on data screens so
/// that, while Firestore loads, the user sees a greyed-out preview of the real
/// layout that pulses. It reads far more "polished" and tells the user what's
/// coming. Colors come from the theme so it works in light and dark mode.

/// A single rounded grey block used as a shimmer building-block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps [child] in a theme-aware shimmer sweep.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainer,
      child: child,
    );
  }
}

/// Skeleton list shown while the farm list loads — mirrors the real farm card
/// (text column on the left, square image on the right, full-width button).
class FarmListSkeleton extends StatelessWidget {
  const FarmListSkeleton({super.key, this.itemCount = 4});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, _) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 140, height: 18),
                          SizedBox(height: 10),
                          SkeletonBox(width: 180),
                          SizedBox(height: 8),
                          SkeletonBox(width: 110),
                          SizedBox(height: 12),
                          SkeletonBox(width: 90, height: 22, radius: 20),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const SkeletonBox(width: 110, height: 110, radius: 10),
                  ],
                ),
                const SizedBox(height: 14),
                const SkeletonBox(
                  width: double.infinity,
                  height: 44,
                  radius: 8,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton list shown while trainings load — mirrors the training card
/// (square thumbnail, text lines, trailing action button).
class TrainingListSkeleton extends StatelessWidget {
  const TrainingListSkeleton({super.key, this.itemCount = 5});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, _) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 80, height: 80, radius: 10),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: double.infinity, height: 18),
                        SizedBox(height: 10),
                        SkeletonBox(width: 150),
                        SizedBox(height: 8),
                        SkeletonBox(width: 100),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 64, height: 34, radius: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Generic skeleton for simple record lists (observations, irrigations, tasks,
/// submissions…): a leading square, two text lines, and a trailing chevron
/// block, repeated as outlined rows.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, _) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 44, height: 44, radius: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 160, height: 15),
                      SizedBox(height: 8),
                      SkeletonBox(width: 100),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const SkeletonBox(width: 20, height: 20, radius: 6),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for a profile header (avatar circle + name + email lines), used
/// while the Settings and Edit-account screens load the user document.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Avatar
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 16),
            const SkeletonBox(width: 160, height: 18),
            const SizedBox(height: 10),
            const SkeletonBox(width: 200),
            const SizedBox(height: 28),
            // A couple of card-like blocks below the header.
            const SkeletonBox(width: double.infinity, height: 64, radius: 12),
            const SizedBox(height: 12),
            const SkeletonBox(width: double.infinity, height: 64, radius: 12),
          ],
        ),
      ),
    );
  }
}
