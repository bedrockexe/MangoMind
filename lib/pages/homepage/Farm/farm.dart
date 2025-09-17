// Flutter packages
import 'package:flutter/material.dart';

// Pages
import 'package:insights/pages/homepage/Farm/mangowidget.dart';
import 'package:insights/pages/homepage/Farm/farmlist.dart';

class FarmList extends StatefulWidget {
  const FarmList({super.key});
  @override
  State<FarmList> createState() => _FarmListState();
}

class _FarmListState extends State<FarmList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farm Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // View and Manage Farms
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/mangofarm.png"),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FarmListPage(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.agriculture,
                        color: Color.fromARGB(255, 62, 142, 63),
                        size: 64,
                      ),
                      title: const Text(
                        "My Farms",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text("View and manage your farm list"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),
          // View Mango Market Price
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/mangga.jpg"),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(12),
            ),

            child: Card(
              color: Colors.white.withValues(alpha: 0.7),
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer,
                          size: 20,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mango Public Market Price',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 27),
                        child: Text(
                          "Based on DA \"Bantay Presyo\"",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),

                    MangoPriceTile(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
