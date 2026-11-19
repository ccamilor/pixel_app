import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';

/// Pantalla base reutilizable para las vistas iniciales de la Fase 1.
class ModulePlaceholderView extends StatelessWidget {
  const ModulePlaceholderView({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.phaseBadge,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String phaseBadge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDeepBlue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(icon, color: AppColors.accentCyan, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        phaseBadge,
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.accentCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
