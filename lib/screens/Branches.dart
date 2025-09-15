// import 'package:flutter/material.dart';
// import '../utils/api_service.dart';

// class BranchesScreen extends StatefulWidget {
//   final int branchId; // Coming from SalonDetailsScreen

//   const BranchesScreen({Key? key, required this.branchId}) : super(key: key);

//   @override
//   _BranchesScreenState createState() => _BranchesScreenState();
// }

// class _BranchesScreenState extends State<BranchesScreen> {
//   late Future<List<Map<String, dynamic>>> _branchesFuture;

//   @override
//   void initState() {
//     super.initState();
//     _branchesFuture = _fetchBranches();
//   }

//   Future<List<Map<String, dynamic>>> _fetchBranches() async {
//     try {
//       final response = await ApiService().getSalonBranches(widget.branchId);
//       if (response['success'] == true) {
//         return List<Map<String, dynamic>>.from(response['data']);
//       } else {
//         return [];
//       }
//     } catch (e) {
//       print("Error fetching branches: $e");
//       return [];
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: FutureBuilder<List<Map<String, dynamic>>>(
//         future: _branchesFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text("No branches found"));
//           }

//           final branches = snapshot.data!;

//           return ListView.builder(
//             padding: const EdgeInsets.all(12),
//             itemCount: branches.length,
//             itemBuilder: (context, index) {
//               final branch = branches[index];
//               final String branchName = branch['name'] ?? 'Unknown Branch';
//               final String phone = branch['phone'] ?? 'No phone';
//               final String address = branch['address']?['line1'] ?? 'No address';
//               final String? imageUrl = branch['imageUrl'];

//               return Card(
//                 margin: const EdgeInsets.symmetric(vertical: 8),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 elevation: 2,
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.blue.shade50, // light bluish background
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.all(14),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Branch Image
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(8),
//                         child: imageUrl != null && imageUrl.isNotEmpty
//                             ? Image.network(imageUrl,
//                                 width: 60, height: 60, fit: BoxFit.cover)
//                             : Container(
//                                 width: 60,
//                                 height: 60,
//                                 color: Colors.grey.shade300,
//                                 child: const Icon(Icons.store,
//                                     size: 30, color: Colors.grey),
//                               ),
//                       ),
//                       const SizedBox(width: 12),

//                       // Branch Info
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               branchName,
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.pink, // magenta like screenshot
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Row(
//                               children: [
//                                 const Icon(Icons.phone,
//                                     size: 14, color: Colors.black54),
//                                 const SizedBox(width: 6),
//                                 Text(
//                                   phone,
//                                   style: const TextStyle(
//                                     fontSize: 13,
//                                     color: Colors.black87,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 6),
//                             Row(
//                               children: [
//                                 const Icon(Icons.location_on,
//                                     size: 14, color: Colors.black54),
//                                 const SizedBox(width: 6),
//                                 Expanded(
//                                   child: Text(
//                                     address,
//                                     style: const TextStyle(
//                                       fontSize: 13,
//                                       color: Colors.black87,
//                                     ),
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),

//       // Floating action button (bottom right + icon)
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: Colors.purple,
//         onPressed: () {
//           // TODO: Navigate to Add Branch Screen
//         },
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
