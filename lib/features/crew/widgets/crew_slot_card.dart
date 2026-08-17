import 'package:flutter/material.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import '../models.dart';

class CrewSlotCard extends StatelessWidget {
  const CrewSlotCard({
    super.key,
    required this.roleTitle,
    required this.assignedMember,
    required this.onAssignTap,
    required this.onClearTap,
    this.isSubmitting = false,
  });

  final String roleTitle;
  final CrewMemberSimple? assignedMember;
  final VoidCallback onAssignTap;
  final VoidCallback onClearTap;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final bool isAssigned = assignedMember != null;
    final IconData roleIcon = roleTitle.toUpperCase().contains('EMT')
        ? Icons.medical_services_outlined
        : Icons.local_hospital_outlined;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAssigned
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isAssigned
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  roleIcon,
                  size: 18,
                  color: isAssigned ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$roleTitle Slot',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isAssigned
                      ? AppColors.accent.withValues(alpha: 0.1)
                      : AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isAssigned ? 'ASSIGNED' : 'UNASSIGNED',
                  style: TextStyle(
                    color: isAssigned ? AppColors.accent : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content body
          if (isAssigned) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brandNavy.withValues(alpha: 0.08),
                  child: Text(
                    assignedMember!.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.brandNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignedMember!.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (assignedMember!.phone != null &&
                          assignedMember!.phone!.isNotEmpty)
                        Text(
                          assignedMember!.phone!,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Buttons row: Change & Clear
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSubmitting ? null : onAssignTap,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Change'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : onClearTap,
                  icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'No crew member assigned to this slot yet.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onAssignTap,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text('Assign $roleTitle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandNavy,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
