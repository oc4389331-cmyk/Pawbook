import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/feed_controller.dart';
import '../../models/pet_model.dart';
import '../../theme/app_theme.dart';
import '../widgets/pet_badge.dart';
import '../widgets/sponsor_dialog.dart';

class PetProfileScreen extends StatelessWidget {
  final PetModel pet;

  const PetProfileScreen({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    final feedController = Provider.of<FeedController>(context);
    final petPosts = feedController.posts.where((p) => p.petId == pet.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Hero Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceDark,
                border: Border(bottom: BorderSide(color: AppTheme.borderDark)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppTheme.solanaPurple,
                    backgroundImage: NetworkImage(
                      pet.avatarUrl.isNotEmpty
                          ? pet.avatarUrl
                          : 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400',
                    ),
                  ),
                  const SizedBox(height: 12),
                  PetBadge(
                    petName: pet.name,
                    nftMintAddress: pet.nftMintAddress,
                    avatarUrl: null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ' • ',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pet.bio,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Stats Row: Total Sponsored Score & Posts Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Patrocinios', ' 🐾', AppTheme.solanaGreen),
                      _buildStatColumn('Publicaciones', '', AppTheme.solanaPurple),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sponsor Action Button
                  SizedBox(
                    width: 220,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.solanaPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.volunteer_activism, color: AppTheme.solanaGreen),
                      label: const Text('Patrocinar Mascota'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => SponsorDialog(
                            petName: pet.name,
                            onSponsor: (amount) {
                              feedController.sponsorPet(pet.id, amount);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Pet Posts Grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Galería de ',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),

            if (petPosts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Esta mascota aún no tiene publicaciones activas.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: petPosts.length,
                itemBuilder: (context, index) {
                  final post = petPosts[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: AppTheme.cardDark,
                      child: Image.network(
                        post.mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.pets, color: AppTheme.solanaPurple),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
