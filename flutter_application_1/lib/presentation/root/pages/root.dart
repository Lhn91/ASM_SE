import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/configs/assets/app_images.dart';
import 'package:flutter_application_1/core/configs/theme/app_colors.dart';
import 'package:flutter_application_1/data/models/booking/booking_request.dart';
import 'package:flutter_application_1/presentation/booking/pages/booking_pages.dart';
import 'package:flutter_application_1/presentation/booking_history/booking_history_page.dart';
import 'package:flutter_application_1/presentation/manage/room_auth_page.dart';
import 'notifications_page.dart';
import 'account_page.dart';
import 'settings_page.dart';
import 'package:flutter_application_1/presentation/choose_mode/pages/choose_mode.dart'; // Trang mới để nhận phòng

import 'package:flutter_application_1/presentation/checkin_page/pages/check_in_page.dart';

class RootPage extends StatefulWidget {
  final String? message;

  const RootPage({
    Key? key,
    this.message,
  }) : super(key: key);

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<List<BookingRequest>>? _bookingsStream;

  @override
  void initState() {
    super.initState();
    _initBookingsStream();
    if (widget.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.message!)),
        );
      });
    }
    _checkAndSendNotifications();
  }

  void _initBookingsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _bookingsStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BookingRequest.fromJson(doc.data()))
              .toList());
    }
  }

  void _checkAndSendNotifications() {
    _bookingsStream?.listen((bookings) {
      for (var booking in bookings) {
        final startDateTime = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
          booking.startTime.hour,
          booking.startTime.minute,
        );

        final now = DateTime.now();
        final difference = startDateTime.difference(now).inMinutes;

        if (difference <= 15 && difference > 0) {
          if (booking.status == 'pending' || booking.status == 'confirmed') {
            _sendNotification(booking);
          }
        }
      }
    });
  }

  Future<void> _sendNotification(BookingRequest booking) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final message = booking.status == 'pending'
        ? 'Bạn vừa đặt phòng ${booking.roomNumber} lúc ${booking.startTime.format(context)}. Vui lòng chờ xác nhận.'
        : 'Đặt phòng ${booking.roomNumber} của bạn đã được xác nhận lúc ${booking.startTime.format(context)}!';

    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': currentUser.uid,
      'message': message,
      'createdAt': Timestamp.now(),
      'isRead': false,
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationsPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AccountPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        break;
    }
  }

  void _showMenu() {
    final currentUser = _auth.currentUser;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentUser != null) ...[
              ListTile(
                leading: const Icon(Icons.check_box, color: Colors.blue),
                title: const Text('Nhận phòng'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CheckInPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Đăng xuất'),
                onTap: () async {
                  await _auth.signOut();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đăng xuất thành công!')),
                  );
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.login, color: Colors.blue),
                title: const Text('Đăng nhập'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: _showMenu,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
            },
          ),
          const CircleAvatar(
            radius: 16,
            backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                AppImages.iconic_logo,
                height: 60,
                width: 60,
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildFeatureCard(
                    title: 'Đặt Phòng',
                    icon: Icons.add_circle,
                    image: 'assets/images/booking.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BookingPage()),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    title: 'Lịch sử đặt',
                    icon: Icons.history,
                    image: 'assets/images/booking_history.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BookingHistoryPage()),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    title: 'Nhận phòng',
                    icon: Icons.check_box,
                    image: 'assets/images/check_in.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CheckInPage()),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    title: 'Quản Lí Phòng',
                    icon: Icons.settings,
                    image: 'assets/images/room_management.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RoomAuthPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Tin nhắn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required String image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Icon(icon, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}