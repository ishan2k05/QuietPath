import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/core/widgets/quietpath_logo.dart';
import 'package:quietpath_flutter/features/safe_spaces/data/safe_spaces_provider.dart';

class SafeSpacesScreen extends ConsumerWidget {
  const SafeSpacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesAsync = ref.watch(safeSpacesProvider);
    final activeTag = ref.watch(selectedSpaceTagProvider);

    return Scaffold(
      backgroundColor: QuietColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF2EE),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFCBD6CA),
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const QuietPathLogo(size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'QuietPath',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: QuietColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.emergency_share_outlined, color: QuietColors.textCharcoal, size: 20),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18.0, 14.0, 18.0, 110.0),
                children: [
                  // Title & Subtitle
                  Text(
                    'Safe Spaces Nearby',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: QuietColors.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quiet, low-stimulus sanctuaries near you.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: QuietColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips (Interactive)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          ref: ref,
                          tag: 'All',
                          label: 'All Places',
                          icon: Icons.tune_rounded,
                          isSelected: activeTag == 'All',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          ref: ref,
                          tag: 'Low Noise',
                          label: 'Low Noise',
                          icon: Icons.volume_off_rounded,
                          isSelected: activeTag == 'Low Noise',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          ref: ref,
                          tag: 'Low Crowd',
                          label: 'Low Crowd',
                          icon: Icons.groups_rounded,
                          isSelected: activeTag == 'Low Crowd',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          ref: ref,
                          tag: 'Silence Required',
                          label: 'Silence Zone',
                          icon: Icons.menu_book_rounded,
                          isSelected: activeTag == 'Silence Required',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Spaces List
                  spacesAsync.when(
                    data: (spaces) {
                      if (spaces.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No safe spaces found for "$activeTag".',
                              style: GoogleFonts.inter(color: QuietColors.textMuted),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: spaces.map((space) => _buildSpaceCard(context, space)).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: QuietColors.primaryDark),
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Text('Error loading safe spaces: $err'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required WidgetRef ref,
    required String tag,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    final bgColor = isSelected ? const Color(0xFF456B34) : const Color(0xFFE9ECEF);
    final textColor = isSelected ? Colors.white : QuietColors.textCharcoal;

    return GestureDetector(
      onTap: () {
        ref.read(selectedSpaceTagProvider.notifier).state = tag;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceCard(BuildContext context, SafeSpaceItem space) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QuietColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.push('/navigation', extra: {
              'destination': space.name,
              'isSafeSpaceExit': true,
              'quietSpot': space.quietZoneInfo ?? space.bestSpot ?? '',
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Match Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        space.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: QuietColors.textCharcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: QuietColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.spa_rounded, size: 11, color: QuietColors.primaryDark),
                          const SizedBox(width: 4),
                          Text(
                            '${space.sensoryMatchScore ?? 92}%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: QuietColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Real-Time Distance & Environmental Metadata
                Text(
                  '${space.category} • ${space.distanceMiles < 1.0 ? '${(space.distanceMiles * 1609).round()}m away' : '${(space.distanceMiles * 1.609).toStringAsFixed(1)} km away'}${space.quietZoneInfo != null ? ' • ${space.quietZoneInfo}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: QuietColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Bottom Row: 1 Subtle Highlight Tag + Compact Sanctuary Exit Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Single Key Highlight Pill
                    if (space.featureTags.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          space.featureTags.first,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: QuietColors.textCharcoal,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Compact Sanctuary Exit Button (34px height)
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: QuietColors.primaryDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            'Sanctuary Exit',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
