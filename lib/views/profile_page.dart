import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/auth_controller.dart';
import '../controllers/transport_controller.dart';
import '../models/user.dart';
import '../widgets/eco_bottom_navigation.dart';
import 'about_eco_travel_page.dart';
import 'ai_trip_planner_page.dart';
import 'change_password_page.dart';
import 'community_feed_page.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'ride_home_page.dart';
import 'my_trip_plans_page.dart';
import 'saved_trip_plans_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthController authController = AuthController();
  final TransportController _transportController = TransportController();
  final ImagePicker _picker = ImagePicker();

  static const Color mainGreen = Color(0xFF2E7D32);
  static const Color pageBackground = Color(0xFFF8FAF8);
  static const Color textColor = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF777777);

  bool isLoading = true;
  bool isLoggingOut = false;
  bool isUploadingPhoto = false;

  UserModel? profile;
  String? fallbackEmail;

  // Eco-impact stats, sourced from the person's own trip plans' saved
  // transportation (see MyTripPlansPage / PlanTransportPage) rather
  // than the separate Saved List - null while loading so the stat
  // cells can show a "--" placeholder instead of a misleading 0.
  int? plannedTripsCount;
  double? totalCo2Kg;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadEcoStats();
  }

  Future<void> _loadEcoStats() async {
    try {
      final plans = await _transportController.getActiveSavedPlans();
      var plannedCount = 0;
      var co2 = 0.0;
      for (final plan in plans) {
        final legs = await _transportController.getSavedTransportPlan(
          plan.id,
        );
        if (legs == null || legs.isEmpty) continue;
        plannedCount++;
        for (final leg in legs) {
          final option = leg.option;
          if (option != null) co2 += option.co2Kg;
        }
      }
      if (!mounted) return;
      setState(() {
        plannedTripsCount = plannedCount;
        totalCo2Kg = co2;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        plannedTripsCount = 0;
        totalCo2Kg = 0;
      });
    }
  }

  Future<void> _loadProfile() async {
    final loaded = await authController.getCurrentUserProfile();

    if (!mounted) return;

    setState(() {
      profile = loaded;
      fallbackEmail = authController.currentUserEmail;
      isLoading = false;
    });
  }

  Future<void> _changePicture() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null || !mounted) return;

      XFile imageToUpload = picked;

      if (!kIsWeb) {
        final CroppedFile? cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 85,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Profile Picture',
              toolbarColor: mainGreen,
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: mainGreen,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Profile Picture',
              aspectRatioLockEnabled: true,
            ),
          ],
        );
        if (cropped == null || !mounted) return;
        imageToUpload = XFile(cropped.path);
      }

      setState(() => isUploadingPhoto = true);

      final photoUrl = await authController.uploadProfilePicture(
        imageToUpload,
      );
      await authController.updateProfile(photoUrl: photoUrl);

      if (!mounted) return;

      final current = profile;
      setState(() {
        profile = UserModel(
          uid: current?.uid ?? '',
          name: current?.name ?? '',
          email: current?.email ?? (fallbackEmail ?? ''),
          role: current?.role ?? 'user',
          photoUrl: photoUrl,
        );
        isUploadingPhoto = false;
      });
      _showSnack('Profile picture updated');
    } catch (error) {
      if (!mounted) return;
      setState(() => isUploadingPhoto = false);
      _showSnack('Could not update profile picture: $error', isError: true);
    }
  }

  // ============================================================
  // EDIT NAME
  // ============================================================
  Future<void> _editName() async {
    final controller = TextEditingController(text: profile?.name ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Full name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text(
                'Save',
                style: TextStyle(color: mainGreen, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty || !mounted) return;

    try {
      await authController.updateProfile(name: newName);
      if (!mounted) return;

      final current = profile;
      setState(() {
        profile = UserModel(
          uid: current?.uid ?? '',
          name: newName,
          email: current?.email ?? (fallbackEmail ?? ''),
          role: current?.role ?? 'user',
          photoUrl: current?.photoUrl,
        );
      });
      _showSnack('Name updated');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Could not update name: $error', isError: true);
    }
  }

  void _openTripPlans() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyTripPlansPage()),
    );
  }

  // ============================================================
  // CHANGE PASSWORD
  // In-app now (current password -> new password) - see
  // ChangePasswordPage - instead of emailing a reset link.
  // ============================================================
  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  void _openAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutEcoTravelPage()),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  void _showComingSoon(String page) {
    _showSnack('$page coming soon');
  }

  Future<void> _logout() async {
    setState(() {
      isLoggingOut = true;
    });

    await authController.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayName =
    (profile?.name.isNotEmpty ?? false) ? profile!.name : 'EcoTravel User';

    final String displayEmail =
    (profile?.email.isNotEmpty ?? false)
        ? profile!.email
        : (fallbackEmail ?? '');

    final String? photoUrl = profile?.photoUrl;

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                child: Row(
                  children: [
                    Transform.translate(
                      offset: const Offset(-7, 0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 55,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),

                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.1,
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      'Manage your account and preferences.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: secondaryText,
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: mainGreen,
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        color: mainGreen.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                        image: photoUrl != null
                                            ? DecorationImage(
                                          image: NetworkImage(photoUrl),
                                          fit: BoxFit.cover,
                                        )
                                            : null,
                                      ),
                                      child: photoUrl == null
                                          ? const Icon(
                                        Icons.person,
                                        size: 52,
                                        color: mainGreen,
                                      )
                                          : null,
                                    ),
                                    if (isUploadingPhoto)
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: const BoxDecoration(
                                            color: Colors.black38,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: GestureDetector(
                                        onTap:
                                        isUploadingPhoto ? null : _changePicture,
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: mainGreen,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: pageBackground,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: _editName,
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  displayEmail,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: mainGreen.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: mainGreen.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ecoStat(
                                    icon: Icons.bookmark_rounded,
                                    value: plannedTripsCount == null
                                        ? '--'
                                        : '$plannedTripsCount',
                                    label: 'Trips Planned',
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: mainGreen.withOpacity(0.15),
                                ),
                                Expanded(
                                  child: _ecoStat(
                                    icon: Icons.eco_rounded,
                                    value: totalCo2Kg == null
                                        ? '--'
                                        : '${totalCo2Kg!.toStringAsFixed(1)} kg',
                                    label: 'CO2 Tracked',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          _settingsCard([
                            _settingsTile(
                              icon: Icons.event_note_outlined,
                              label: 'My Trip Plans',
                              value: 'Saved multi-stop itineraries',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SavedTripPlansPage(),
                                  ),
                                );
                              },
                            ),
                          ]),

                          const SizedBox(height: 10),

                          _settingsCard([
                            _settingsTile(
                              icon: Icons.lock_outline,
                              label: 'Change Password',
                              value: 'Update your account password',
                              onTap: _openChangePassword,
                            ),
                          ]),

                          const SizedBox(height: 10),

                          _settingsCard([
                            _settingsTile(
                              icon: Icons.info_outline,
                              label: 'About EcoTravel',
                              value: 'Our mission & what we offer',
                              onTap: _openAbout,
                            ),
                          ]),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton(
                              onPressed: isLoggingOut ? null : _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(
                                  color: Colors.red.shade200,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isLoggingOut
                                  ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red.shade700,
                                ),
                              )
                                  : const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.logout_rounded,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 35),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: EcoBottomNavigation(
        currentIndex: 4,
        onHomeTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        },
        onTransportTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransportationPage()),
          );
        },
        onPlanTripTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiTripPlannerPage()),
          );
        },
        onCommunityTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const CommunityFeedPage(),
            ),
          );
        },
        onProfileTap: () {
          // Already on Profile page.
        },
      ),
    );
  }

  Widget _ecoStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: mainGreen, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mainGreen.withOpacity(0.15),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: mainGreen.withOpacity(0.10),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: mainGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
            ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: tile,
    );
  }
}