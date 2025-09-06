import 'package:flutter/material.dart';

class FarmListCard extends StatelessWidget {
  const FarmListCard({
    super.key,
    this.header = 'Farm List',
    required this.farmName,
    required this.farmAddress,
    this.onOpenFarm,
    this.onAddFarm,
    this.padding = const EdgeInsets.all(12),
  });

  final String header;
  final String farmName;
  final String farmAddress;
  final VoidCallback? onOpenFarm;
  final VoidCallback? onAddFarm;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = Colors.green.shade700;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.agriculture, size: 20, color: green),
                const SizedBox(width: 8),
                Text(
                  header,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),

            // Farm item
            InkWell(
              onTap: onOpenFarm,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            farmAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: scheme.onSurface.withOpacity(.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: scheme.onSurface.withOpacity(.6),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Add button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddFarm,
                icon: const Icon(Icons.add),
                label: const Text('Add New Farm'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
