import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  final List<Map<String, dynamic>> _bandanas = const [
    {
      'id': 'bdn_solana',
      'name': 'Solana Cyber Bandana ⚡',
      'pricePoints': 250,
      'priceUsd': 12.99,
      'imageUrl': 'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=600',
      'tag': 'Solana Exclusive',
      'color': Color(0xFF9945FF),
    },
    {
      'id': 'bdn_golden',
      'name': 'Pawtbook Gold Edition 👑',
      'pricePoints': 500,
      'priceUsd': 24.99,
      'imageUrl': 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
      'tag': 'Best Seller',
      'color': Color(0xFFEAB308),
    },
    {
      'id': 'bdn_neon',
      'name': 'Neon Paw Glow Bandana 🌟',
      'pricePoints': 180,
      'priceUsd': 9.99,
      'imageUrl': 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=600',
      'tag': 'Limited Edition',
      'color': Color(0xFFEC4899),
    },
    {
      'id': 'bdn_ocean',
      'name': 'Ocean Beach Walker 🌊',
      'pricePoints': 200,
      'priceUsd': 10.99,
      'imageUrl': 'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=600',
      'tag': 'Summer 2026',
      'color': Color(0xFF06B6D4),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final userScore = authController.currentProfile?.pawtScore ?? 100;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        title: const Row(
          children: [
            Text('🛍️ Pawtbook Marketplace', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6366F1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 6),
                Text(
                  '$userScore pts',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('OFFICIAL MERCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Exclusive Pet Bandanas 🐾',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Redeem with PawtScore or buy with Card / Solana Pay',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Featured Bandanas Collection',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: _bandanas.length,
              itemBuilder: (ctx, idx) {
                final item = _bandanas[idx];
                final canAfford = userScore >= (item['pricePoints'] as int);

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              item['imageUrl'],
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (item['color'] as Color).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['tag'],
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.stars, color: Color(0xFFF59E0B), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${item['pricePoints']} pts',
                                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  '\$${item['priceUsd']}',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 34,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (canAfford) {
                                    authController.deductPawtScore(item['pricePoints'] as int);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF10B981),
                                        content: Text('🎉 Redeemed ${item['name']} successfully!'),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFFEF4444),
                                        content: Text('Insufficient PawtScore points. Sponsor pets to earn more!'),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford ? const Color(0xFF6366F1) : const Color(0xFF27272A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  canAfford ? 'Redeem Bandana' : 'Get Points',
                                  style: TextStyle(
                                    color: canAfford ? Colors.white : Colors.grey[400],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          ],
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
