import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/language_controller.dart';
import '../../theme/app_theme.dart';

class LanguageSelector extends StatelessWidget {
  final bool isDark;

  const LanguageSelector({
    super.key,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final langController = Provider.of<LanguageController>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.4) : AppTheme.surfaceWarm,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white30 : AppTheme.borderWarm,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: langController.currentLanguage,
          dropdownColor: AppTheme.bgWarmCream,
          icon: Icon(
            Icons.language_rounded,
            color: isDark ? Colors.white : AppTheme.primaryTerracotta,
            size: 20,
          ),
          onChanged: (String? newLang) {
            if (newLang != null) {
              langController.setLanguage(newLang);
            }
          },
          items: LanguageController.supportedLanguages.map((lang) {
            return DropdownMenuItem<String>(
              value: lang['code'],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lang['flag']!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    lang['name']!,
                    style: GoogleFonts.fredoka(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
