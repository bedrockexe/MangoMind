import 'package:flutter/material.dart';
import 'package:insights/pages/homepage/Home/detector.dart';

class MangoDetectorTile extends StatelessWidget {
  const MangoDetectorTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/mango_disease.jpg"),
          fit: BoxFit.cover, // cover, contain, etc.
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            // MaterialPageRoute(builder: (_) => const MangoDiseaseDetectorPage()),
            MaterialPageRoute(builder: (_) => const MangoDiseaseDetectorPage()),
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
                color: Colors.white,
              ),
            ),
            subtitle: const Text(
              'Scan leaf/fruit for Anthracnose or Mildew',
              style: TextStyle(color: Colors.white),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
