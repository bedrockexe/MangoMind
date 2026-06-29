// Flutter packages
import 'package:flutter/material.dart';
import 'package:insights/theme/transitions.dart';

// Pages
import 'package:insights/pages/homepage/Farm/mangoprice/mangowidget.dart';
import 'package:insights/pages/homepage/Farm/farmlist/farmlist.dart';
import 'package:insights/pages/homepage/Farm/assessment_button.dart';

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
          AssessmentButton(),
          SizedBox(height: 16),
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
                      appRoute(const FarmListPage()),
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
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        "View and manage your farm list",
                        style: TextStyle(color: Colors.grey[800]),
                      ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
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
