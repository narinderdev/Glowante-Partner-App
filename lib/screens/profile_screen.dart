import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final ApiService apiService = ApiService();

  void _showLogoutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildLogoutActions(context)],
          ),
        );
      },
    );
  }

  Widget _buildLogoutActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Logout',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Are you sure you want to Log Out?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          Divider(color: Colors.grey, thickness: 1, indent: 30, endIndent: 30),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ❌ Cancel button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context), // just close modal
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Cancel'),
                ),
              ),
              SizedBox(width: 10),
              // ✅ Confirm Logout
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final success = await apiService.logoutUserAPI();
                    Navigator.pop(context); // close modal
                    if (success) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                        (route) => false,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout failed. Please try again.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Yes, Log out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange, // 👈 Orange background
            foregroundColor: Colors.white,  // 👈 White text
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () => _showLogoutModal(context),
          child: Text(
            'Logout',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../utils/api_service.dart';
// import 'login_screen.dart';

// class ProfileScreen extends StatelessWidget {
//   final ApiService apiService = ApiService();

//   Future<void> _openLink(String url) async {
//     final Uri uri = Uri.parse(url);
//     if (!await launchUrl(
//       uri,
//       mode: LaunchMode.inAppWebView, // 👈 Open inside the app
//       webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
//     )) {
//       throw Exception('Could not launch $url');
//     }
//   }

//   void _showLogoutModal(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       builder: (BuildContext context) {
//         return Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [_buildLogoutActions(context)],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildLogoutActions(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 20.0),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text(
//             'Logout',
//             style: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//               color: Colors.red,
//             ),
//           ),
//           const SizedBox(height: 10),
//           const Text(
//             'Are you sure you want to Log Out?',
//             textAlign: TextAlign.center,
//             style: TextStyle(fontSize: 16),
//           ),
//           const SizedBox(height: 20),
//           const Divider(color: Colors.grey, thickness: 1, indent: 30, endIndent: 30),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: () => Navigator.pop(context),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.grey[300],
//                     foregroundColor: Colors.black,
//                     padding: const EdgeInsets.symmetric(vertical: 15),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                   ),
//                   child: const Text('Cancel'),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: () async {
//                     final success = await apiService.logoutUserAPI();
//                     Navigator.pop(context);
//                     if (success) {
//                       Navigator.pushAndRemoveUntil(
//                         context,
//                         MaterialPageRoute(builder: (_) => const LoginScreen()),
//                         (route) => false,
//                       );
//                     } else {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text('Logout failed. Please try again.')),
//                       );
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 15),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                   ),
//                   child: const Text('Yes, Log out'),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         title: const Text('Profile'),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         foregroundColor: Colors.black,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             /// Profile avatar + Name + Number
//             Column(
//               children: [
//                 Stack(
//                   children: [
//                     CircleAvatar(
//                       radius: 40,
//                       backgroundColor: Colors.grey[300],
//                       child: Icon(Icons.person, size: 40, color: Colors.grey[600]),
//                     ),
//                     Positioned(
//                       bottom: 0,
//                       right: 0,
//                       child: CircleAvatar(
//                         radius: 14,
//                         backgroundColor: Colors.orange,
//                         child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
//                       ),
//                     )
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 const Text("Madhavi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 Text("8219325453", style: TextStyle(color: Colors.grey[600])),
//               ],
//             ),

//             const SizedBox(height: 30),

//             /// Privacy Policy
//             ListTile(
//               leading: const Icon(Icons.privacy_tip, color: Colors.black87),
//               title: const Text("Privacy Policy"),
//               trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//               onTap: () => _openLink(
//                 "https://www.freeprivacypolicy.com/live/ea801575-3a5f-4a5f-b989-b90bbab92814",
//               ),
//             ),
//             const Divider(),

//             /// Terms & Conditions
//             ListTile(
//               leading: const Icon(Icons.policy, color: Colors.black87),
//               title: const Text("Terms & Conditions"),
//               trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//               onTap: () => _openLink(
//                 "https://www.freeprivacypolicy.com/live",
//               ),
//             ),
//             const Divider(),

//             const Spacer(),

//             /// Logout Button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () => _showLogoutModal(context),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.orange,
//                   padding: const EdgeInsets.symmetric(vertical: 15),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//                 child: const Text("Logout", style: TextStyle(fontSize: 16, color: Colors.white)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
