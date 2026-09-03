import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/pet_controller.dart';
import '../../theme/app_theme.dart';

class RewardsStoreScreen extends StatefulWidget {
  const RewardsStoreScreen({super.key});

  @override
  State<RewardsStoreScreen> createState() => _RewardsStoreScreenState();
}

class _RewardsStoreScreenState extends State<RewardsStoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthController>(context, listen: false);
      final petController = Provider.of<PetController>(context, listen: false);
      if (auth.currentProfile != null) {
        petController.fetchUserOrders(auth.currentProfile!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final petController = Provider.of<PetController>(context);
    final userScore = authController.currentProfile?.pawtScore ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tienda de Recompensas Pawtbook'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Balance Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.solanaPurple, Color(0xFF6B21A8)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.solanaPurple.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 40, color: AppTheme.solanaGreen),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tu PawtScore Acumulado', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        ' 🐾 PawtScore',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Recompensas Físicas Disponibles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Rewards Items Catalog
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: petController.availableRewards.length,
              itemBuilder: (context, index) {
                final item = petController.availableRewards[index];
                final canAfford = userScore >= item.pointsCost;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 70,
                              height: 70,
                              color: AppTheme.surfaceDark,
                              child: const Icon(Icons.card_giftcard, color: AppTheme.solanaPurple),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(item.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(
                                ' PawtScore',
                                style: const TextStyle(color: AppTheme.solanaGreen, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford ? AppTheme.solanaPurple : AppTheme.surfaceDark,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: !canAfford
                              ? null
                              : () async {
                                  final ok = await petController.redeemReward(
                                    userId: authController.currentProfile!.id,
                                    reward: item,
                                    currentPawtScore: userScore,
                                  );

                                  if (ok) {
                                    authController.deductPawtScore(item.pointsCost);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('¡Canjeaste ! Tu pedido fue registrado.'),
                                          backgroundColor: AppTheme.solanaGreen,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: const Text('Canjear', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Order History Section
            const Text(
              'Historial de Pedidos (orders)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            if (petController.userOrders.isEmpty)
              const Text('Aún no has realizado canjes de recompensas.', style: TextStyle(color: AppTheme.textMuted))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: petController.userOrders.length,
                itemBuilder: (context, index) {
                  final order = petController.userOrders[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.rewardName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Costo:  pts', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.solanaGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: const TextStyle(color: AppTheme.solanaGreen, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
