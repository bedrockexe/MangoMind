import 'package:flutter/material.dart';
import 'package:insights/pages/homepage/Home/mango_detector.dart';

class MangoDetectorTile extends StatelessWidget {
  const MangoDetectorTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/mango_disease.jpg"),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MangoDiseaseDetectionPage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: const Icon(Icons.image_search_rounded),
                ),
                title: const Text(
                  'Mango Checkup',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                subtitle: const Text(
                  'Scan leaf/fruit for Anthracnose or Mildew',
                  style: TextStyle(color: Colors.black),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
