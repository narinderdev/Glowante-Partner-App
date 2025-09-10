import 'package:flutter/material.dart';
import 'services_screen.dart';
import 'team_member_screen.dart';
import 'reviews_screen.dart';
import 'about_screen.dart';
import '../screens/BranchPackages.dart';
import '../screens/BranchDeals.dart';
import '../screens/BranchBookings.dart';

class BranchScreen extends StatelessWidget {
  final int salonId;
  final Map<String, dynamic> branchDetails;

  const BranchScreen({
    Key? key,
    required this.salonId,
    required this.branchDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = branchDetails['imageUrl'];
    final String branchName = branchDetails['name'] ?? 'Branch Name';
    final String line1 = branchDetails['address']?['line1'] ?? 'No address';

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            // App bar with back button only
            SliverAppBar(
              pinned: true,
              title: const Text('Branch Details'),
              automaticallyImplyLeading: true,
              iconTheme: const IconThemeData(color: Colors.white),
              backgroundColor: Colors.purple,
            ),

            // Image with overlay details
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.40,
                    width: double.infinity,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : const Center(
                            child: Icon(Icons.store, size: 70, color: Colors.grey),
                          ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branchName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                line1,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar pinned below the image
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                const TabBar(
                  isScrollable: true,
                  labelColor: Colors.purple,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.purple,
                  tabs: [
                    Tab(text: 'Bookings'),
                    Tab(text: 'Services'),
                    Tab(text: 'Packages'),
                    Tab(text: 'Deals'),
                    Tab(text: 'Team Member'),
                    Tab(text: 'Reviews'),
                    Tab(text: 'About'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              BranchBookingsScreen(),
              ServicesTab(branchId: branchDetails['id']),
              BranchPackagesScreen(branchDetails: branchDetails,),
              BranchDealsScreen(branchDetails: branchDetails,),
              TeamMemberScreen(branchDetails: branchDetails,),
              ReviewsScreen(),
              AboutScreen(branchDetails: branchDetails),
            ],
          ),
        ),
      ),
    );
  }
}

// Delegate for pinned TabBar
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
