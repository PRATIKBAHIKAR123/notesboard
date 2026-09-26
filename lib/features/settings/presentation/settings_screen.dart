import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasBackground,
      appBar: AppBar(
        title: const Text('Settings & Help'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/boards');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // About App Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.dashboard_rounded,
                            color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notesboard', style: AppTextStyles.titleLarge),
                          SizedBox(height: 2),
                          Text('v1.0.0 • Local-first Visual Canvas',
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Canvas Keyboard Shortcuts Reference
                const Text('CANVAS SHORTCUTS', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildShortcutTile('Pan Canvas', 'Drag background or space+drag'),
                      const Divider(height: 1),
                      _buildShortcutTile('Zoom In/Out', 'Mouse wheel / Trackpad pinch'),
                      const Divider(height: 1),
                      _buildShortcutTile('Delete Selected', 'Delete / Backspace'),
                      const Divider(height: 1),
                      _buildShortcutTile('Clear Selection / Cancel', 'Escape'),
                      const Divider(height: 1),
                      _buildShortcutTile('Undo', 'Ctrl / Cmd + Z'),
                      const Divider(height: 1),
                      _buildShortcutTile('Redo', 'Ctrl / Cmd + Shift + Z'),
                      const Divider(height: 1),
                      _buildShortcutTile('Search', 'Ctrl / Cmd + F'),
                      const Divider(height: 1),
                      _buildShortcutTile('Snap to Grid', 'Ctrl / Cmd + G'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Storage Info
                const Text('PERSISTENCE', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.storage_outlined,
                          color: AppColors.primary, size: 22),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Local SQLite Database (Drift)',
                                style: AppTextStyles.titleMedium),
                            SizedBox(height: 2),
                            Text(
                              'Boards, notes, images, groups, and connections are automatically saved locally with debounced autosave.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutTile(String action, String keyCombo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(action, style: AppTextStyles.bodyMedium),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              keyCombo,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
