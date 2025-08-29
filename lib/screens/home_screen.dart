import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService apiService = ApiService();
  String? salonName;
  String? salonAddress;

  @override
  void initState() {
    super.initState();
    _loadCachedSalon();   // Load cached values first
    _fetchSalonFromApi(); // Then update from API
  }

  Future<void> _loadCachedSalon() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      salonName = prefs.getString("salon_name");
      salonAddress = prefs.getString("salon_address");
    });
  }

  Future<void> _fetchSalonFromApi() async {
    try {
      final response = await apiService.getSalonListApi();
      if (response['success'] == true && response['data'].isNotEmpty) {
        final firstSalon = response['data'][0];
        final branches = firstSalon['branches'] as List?;
        final addressObj =
            (branches != null && branches.isNotEmpty) ? branches[0]['address'] : null;

        final name = firstSalon['name'] ?? "Unnamed Salon";
        final address = addressObj != null
            ? "${addressObj['line1'] ?? ''}, ${addressObj['city'] ?? ''}, "
              "${addressObj['state'] ?? ''}, ${addressObj['postalCode'] ?? ''}"
            : "No address available";

        // ✅ Save in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("salon_name", name);
        await prefs.setString("salon_address", address);

        setState(() {
          salonName = name;
          salonAddress = address;
        });
      }
    } catch (e) {
      print("❌ Error fetching salon: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (salonName == null || salonAddress == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // ✅ Salon Name
            Text(
              salonName!,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),

           // ✅ Salon Address
Row(
  children: [
    Icon(Icons.location_on, color: Colors.black, size: 18),
    SizedBox(width: 5),
    Expanded(
      child: Text(
        salonAddress!,
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        maxLines: 1,                  // 👈 one line only
        overflow: TextOverflow.ellipsis, // 👈 show "..."
      ),
    ),
  ],
),

            SizedBox(height: 20),

            // ✅ Revenue Section (static for now)
            Text("Revenue",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Rs.50,000.86 (Weekly 17Feb–23Feb)",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 20),

            // ✅ Specialists Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Specialists",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("View all",
                    style: TextStyle(color: Colors.orange, fontSize: 14)),
              ],
            ),
            SizedBox(height: 8),

            // ✅ Legends
            Row(
              children: [
                _legendDot(Colors.green, "Present"),
                SizedBox(width: 10),
                _legendDot(Colors.red, "Absent"),
                SizedBox(width: 10),
                _legendDot(Colors.orange, "Break"),
              ],
            ),
            SizedBox(height: 20),

            // ✅ Static placeholders
            Center(
                child: Text("No specialists available",
                    style: TextStyle(color: Colors.grey))),
            SizedBox(height: 20),
            Center(
                child: Text("No requested bookings found.",
                    style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
