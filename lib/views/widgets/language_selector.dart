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

  static void showModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LanguagePickerBottomSheet(),
    );
  }

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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.primaryTerracotta,
                  duration: const Duration(seconds: 2),
                  content: Text(
                    langController.t('languageAppliedToast', {'lang': newLang.toUpperCase()}),
                    style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
                  ),
                ),
              );
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

class LanguageProfileTile extends StatelessWidget {
  const LanguageProfileTile({super.key});

  @override
  Widget build(BuildContext context) {
    final langController = Provider.of<LanguageController>(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderWarm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryTerracotta.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.language_rounded, color: AppTheme.primaryTerracotta, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langController.t('language'),
                  style: GoogleFonts.fredoka(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                Text(
                  langController.t('changeLanguageDesc'),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textMutedWarm,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const LanguageSelector(),
        ],
      ),
    );
  }
}

class LanguagePickerBottomSheet extends StatelessWidget {
  const LanguagePickerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final langController = Provider.of<LanguageController>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppTheme.bgWarmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.language_rounded, color: AppTheme.primaryTerracotta, size: 24),
              const SizedBox(width: 10),
              Text(
                langController.t('selectLanguageTitle'),
                style: GoogleFonts.fredoka(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...LanguageController.supportedLanguages.map((lang) {
            final isSelected = langController.currentLanguage == lang['code'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryTerracotta.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryTerracotta : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.8 : 1,
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: Text(lang['flag']!, style: const TextStyle(fontSize: 26)),
                title: Text(
                  lang['name']!,
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.primaryTerracotta : AppTheme.textPrimaryDark,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTerracotta, size: 22)
                    : null,
                onTap: () {
                  langController.setLanguage(lang['code']!);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.primaryTerracotta,
                      duration: const Duration(seconds: 2),
                      content: Text(
                        langController.t('languageAppliedToast', {'lang': lang['name']!}),
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
