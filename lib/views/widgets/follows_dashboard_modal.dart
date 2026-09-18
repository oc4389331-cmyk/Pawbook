import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/feed_controller.dart';
import '../../models/pet_model.dart';
import '../../models/profile_model.dart';
import '../../theme/app_theme.dart';
import '../screens/pet_profile_screen.dart';

class FollowsDashboardModal extends StatefulWidget {
  final PetModel pet;
  final String? currentUserId;
  final int initialTabIndex;

  const FollowsDashboardModal({
    super.key,
    required this.pet,
    this.currentUserId,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required PetModel pet,
    String? currentUserId,
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FollowsDashboardModal(
        pet: pet,
        currentUserId: currentUserId,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<FollowsDashboardModal> createState() => _FollowsDashboardModalState();
}

class _FollowsDashboardModalState extends State<FollowsDashboardModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<List<ProfileModel>>? _followersFuture;
  Future<List<PetModel>>? _followingFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
  }

  void _loadData() {
    final feed = Provider.of<FeedController>(context, listen: false);
    setState(() {
      _followersFuture = feed.getFollowersForPet(widget.pet.id);
      if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) {
        _followingFuture = feed.getFollowedPets(widget.currentUserId!);
      } else {
        _followingFuture = Future.value([]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFBFBFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: AppTheme.primaryTerracotta,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comunidad & Suscripciones',
                        style: GoogleFonts.fredoka(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryDark,
                        ),
                      ),
                      Text(
                        'Canal oficial de ${widget.pet.name}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textMutedWarm,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: AppTheme.textMutedWarm,
                ),
              ],
            ),
          ),

          // Summary Stats Cards (Dual Metric Header)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: FutureBuilder(
              future: Future.wait([
                _followersFuture ?? Future.value(<ProfileModel>[]),
                _followingFuture ?? Future.value(<PetModel>[]),
              ]),
              builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                final followersCount = snapshot.hasData
                    ? (snapshot.data![0] as List<ProfileModel>).length
                    : 0;
                final followingCount = snapshot.hasData
                    ? (snapshot.data![1] as List<PetModel>).length
                    : 0;

                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryMetricCard(
                        title: 'Suscritos a ${widget.pet.name}',
                        subtitle: 'Seguidores de tu mascota',
                        value: snapshot.hasData ? '$followersCount' : '...',
                        icon: Icons.favorite_rounded,
                        color: AppTheme.brandCoral,
                        isSelected: _tabController.index == 0,
                        onTap: () {
                          _tabController.animateTo(0);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryMetricCard(
                        title: 'Tus Suscripciones',
                        subtitle: 'Mascotas que sigues tú',
                        value: snapshot.hasData ? '$followingCount' : '...',
                        icon: Icons.pets_rounded,
                        color: const Color(0xFF0284C7),
                        isSelected: _tabController.index == 1,
                        onTap: () {
                          _tabController.animateTo(1);
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Tab Bar Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {}),
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppTheme.textPrimaryDark,
              unselectedLabelColor: AppTheme.textMutedWarm,
              labelStyle: GoogleFonts.fredoka(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.fredoka(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: const [
                Tab(text: 'Suscritos (Seguidores)'),
                Tab(text: 'Siguiendo (Tus suscripciones)'),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFollowersTab(),
                _buildFollowingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetricCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppTheme.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                Text(
                  value,
                  style: GoogleFonts.fredoka(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.fredoka(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.textMutedWarm,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: FOLLOWERS OF PET ---
  Widget _buildFollowersTab() {
    return FutureBuilder<List<ProfileModel>>(
      future: _followersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'No se pudieron cargar los suscriptores',
                    style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMutedWarm),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTerracotta),
                    child: Text('Reintentar', style: GoogleFonts.fredoka(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        final followers = snapshot.data ?? [];

        if (followers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.brandCoral.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_off_rounded, size: 48, color: AppTheme.brandCoral),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay suscriptores',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '¡Publica videos y comparte el perfil de ${widget.pet.name} para ganar tu primer suscriptor!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textMutedWarm,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          itemCount: followers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final profile = followers[index];
            final displayName = profile.fullName?.isNotEmpty == true
                ? profile.fullName!
                : (profile.username.isNotEmpty ? profile.username : 'Usuario Pawbook');
            final usernameHandle = profile.username.isNotEmpty ? '@${profile.username}' : '';

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softCardShadow,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryTerracotta.withValues(alpha: 0.15),
                    backgroundImage: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                        ? Text(
                            displayName.substring(0, 1).toUpperCase(),
                            style: GoogleFonts.fredoka(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.primaryTerracotta,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: GoogleFonts.fredoka(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 14, color: AppTheme.emeraldGreen),
                          ],
                        ),
                        if (usernameHandle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            usernameHandle,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textMutedWarm,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_rounded, size: 13, color: AppTheme.emeraldGreen),
                        const SizedBox(width: 4),
                        Text(
                          'Suscrito',
                          style: GoogleFonts.fredoka(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: PETS FOLLOWED BY USER ---
  Widget _buildFollowingTab() {
    return FutureBuilder<List<PetModel>>(
      future: _followingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0284C7)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Error al cargar tus suscripciones',
                    style: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                    child: Text('Reintentar', style: GoogleFonts.fredoka(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        final followedPets = snapshot.data ?? [];

        if (followedPets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pets_rounded, size: 48, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No te has suscrito a mascotas aún',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Explora el feed de Pawbook y sigue a tus mascotas favoritas para ver sus videos y apoyar sus aventuras.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textMutedWarm,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          itemCount: followedPets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final pet = followedPets[index];

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softCardShadow,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    backgroundImage: pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty
                        ? NetworkImage(pet.avatarUrl!)
                        : null,
                    child: pet.avatarUrl == null || pet.avatarUrl!.isEmpty
                        ? Text(
                            pet.name.substring(0, 1).toUpperCase(),
                            style: GoogleFonts.fredoka(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: const Color(0xFF0284C7),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pet.species} • ${pet.breed}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textMutedWarm,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: AppTheme.textPrimaryDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PetProfileScreen(pet: pet)),
                      );
                    },
                    child: Text('Ver perfil', style: GoogleFonts.fredoka(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
