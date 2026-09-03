import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PetBadge extends StatelessWidget {
  final String? nftMintAddress;
  final String petName;
  final String? avatarUrl;

  const PetBadge({
    super.key,
    required this.petName,
    this.nftMintAddress,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: nftMintAddress != null ? AppTheme.solanaGreen : AppTheme.borderDark,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatarUrl != null && avatarUrl!.isNotEmpty) ...[
            CircleAvatar(
              radius: 10,
              backgroundImage: NetworkImage(avatarUrl!),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            petName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (nftMintAddress != null && nftMintAddress!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.solanaGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, size: 12, color: AppTheme.solanaGreen),
                  SizedBox(width: 3),
                  Text(
                    'NFT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.solanaGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
