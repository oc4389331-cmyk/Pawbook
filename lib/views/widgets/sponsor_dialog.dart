import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SponsorDialog extends StatefulWidget {
  final String petName;
  final Function(int pawtScoreAmount) onSponsor;

  const SponsorDialog({
    super.key,
    required this.petName,
    required this.onSponsor,
  });

  @override
  State<SponsorDialog> createState() => _SponsorDialogState();
}

class _SponsorDialogState extends State<SponsorDialog> {
  int _selectedAmount = 25;
  final List<int> _amounts = [10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.solanaPurple, width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.favorite, color: AppTheme.solanaPurple, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Patrocinar a ${widget.petName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Elige la cantidad de PawtScore / Tokens \$SCP para apoyar el contenido de esta mascota:',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _amounts.map((amount) {
              final isSelected = _selectedAmount == amount;
              return ChoiceChip(
                label: Text('$amount 🐾'),
                selected: isSelected,
                selectedColor: AppTheme.solanaPurple,
                backgroundColor: AppTheme.surfaceDark,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedAmount = amount);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.bolt, color: AppTheme.solanaGreen),
          label: Text('Enviar $_selectedAmount PawtScore'),
          onPressed: () {
            widget.onSponsor(_selectedAmount);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('¡Has patrocinado a ${widget.petName} con $_selectedAmount PawtScore! 💖'),
                backgroundColor: AppTheme.solanaPurple,
              ),
            );
          },
        ),
      ],
    );
  }
}
