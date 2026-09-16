import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:quietpath_flutter/core/network/api_client.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/core/services/tile_cache_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/core/widgets/quietpath_logo.dart';
import 'package:quietpath_flutter/features/profile/data/profile_provider.dart';

class SensoryProfileSetupScreen extends ConsumerStatefulWidget {
  final bool isStandaloneOnboarding;
  const SensoryProfileSetupScreen({super.key, this.isStandaloneOnboarding = true});

  @override
  ConsumerState<SensoryProfileSetupScreen> createState() =>
      _SensoryProfileSetupScreenState();
}

class _SensoryProfileSetupScreenState
    extends ConsumerState<SensoryProfileSetupScreen> {
  // 0 = low index (Prefer Quiet / Prefer Empty / Dim / Avoid Traffic / Extra Calm)
  // 1 = medium (Moderate / Some People / Standard / Moderate / Balanced)
  // 2 = high (Tolerate Loud / Busy is OK / Bright / Standard / Fastest)
  int _noiseIndex = 1;
  int _crowdIndex = 1;
  int _lightIndex = 1;
  int _trafficIndex = 1;
  int _timeToleranceIndex = 1;

  TileCacheInfo? _tileCacheInfo;
  bool _isDownloadingTiles = false;
  double _downloadProgress = 0.0;
  int _downloadedCount = 0;
  int _downloadTotal = 0;

  String? _serverPingStatus;
  bool _isTestingServer = false;
  bool _serverIsOnline = false;

  @override
  void initState() {
    super.initState();
    final p = AppConfigService().sensoryProfile;
    _noiseIndex = p.noiseSensitivity >= 0.7 ? 0 : (p.noiseSensitivity >= 0.4 ? 1 : 2);
    _crowdIndex = p.crowdComfort >= 0.7 ? 0 : (p.crowdComfort >= 0.4 ? 1 : 2);
    _lightIndex = p.lightIntensity >= 0.7 ? 0 : (p.lightIntensity >= 0.4 ? 1 : 2);
    _trafficIndex = p.trafficSensitivity >= 0.7 ? 0 : (p.trafficSensitivity >= 0.4 ? 1 : 2);
    _timeToleranceIndex = p.timePenaltyTolerance >= 0.7 ? 0 : (p.timePenaltyTolerance >= 0.35 ? 1 : 2);
    _loadTileCacheInfo();
    _testServerConnection(quiet: true);
  }

  Future<void> _testServerConnection({bool quiet = false}) async {
    if (_isTestingServer) return;
    setState(() {
      _isTestingServer = true;
      if (!quiet) _serverPingStatus = 'Testing backend...';
    });

    try {
      final sw = Stopwatch()..start();
      final dio = ApiClient().dio;
      final res = await dio.get(
        '/health',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      sw.stop();
      if (mounted) {
        if (res.statusCode == 200) {
          setState(() {
            _serverIsOnline = true;
            _serverPingStatus = 'Online (${sw.elapsedMilliseconds}ms)';
          });
        } else {
          setState(() {
            _serverIsOnline = false;
            _serverPingStatus = 'Server error (${res.statusCode})';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverIsOnline = false;
          _serverPingStatus = 'Offline mode active (app fully functional)';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingServer = false;
        });
      }
    }
  }

  Future<void> _loadTileCacheInfo() async {
    final info = await TileCacheService().getCachedTilesInfo();
    if (mounted) {
      setState(() {
        _tileCacheInfo = info;
      });
    }
  }

  Future<void> _startDownloadTilePack() async {
    if (_isDownloadingTiles) return;
    setState(() {
      _isDownloadingTiles = true;
      _downloadProgress = 0.0;
      _downloadedCount = 0;
      _downloadTotal = 0;
    });

    try {
      await TileCacheService().downloadCityTilePack(
        centerLat: 18.510408,
        centerLng: 73.937475,
        cityName: 'Pune Hadapsar',
        zoomLevels: const [13, 14, 15],
        radiusKm: 3.5,
        onProgress: (completed, total, pct) {
          if (mounted) {
            setState(() {
              _downloadedCount = completed;
              _downloadTotal = total;
              _downloadProgress = pct;
            });
          }
        },
      );
      await _loadTileCacheInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: QuietColors.primaryDark,
            content: Text(
              'Pune Hadapsar offline pack ready! You can now navigate offline without internet.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isDownloadingTiles = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // App logo
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: QuietColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const QuietPathLogo(size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isStandaloneOnboarding ? 'Welcome to QuietPath' : 'Sensory Profile & Settings',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: QuietColors.textCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isStandaloneOnboarding
                    ? "Let's set up your sensory preferences to find\nenvironments that feel right for you."
                    : "Tune your comfort thresholds. Routes and safe spaces recalculate dynamically.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: QuietColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Sparkle card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: QuietColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: QuietColors.borderLight),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: QuietColors.secondaryDark,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isStandaloneOnboarding
                            ? 'We use these settings to filter out places that might be overwhelming. You can always adjust these later as your needs change.'
                            : 'Your preferences automatically shape the calmest, lowest-stimulus paths and sanctuaries for you in real-time.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: QuietColors.textCharcoal,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Preference 1: Noise Sensitivity
              _buildSensoryCategory(
                icon: Icons.hearing_rounded,
                iconBg: const Color(0xFFF1EEF8),
                iconColor: QuietColors.secondaryDark,
                title: 'Noise Sensitivity',
                labels: ['Prefer Quiet', 'Moderate', 'Tolerate Loud'],
                selectedIndex: _noiseIndex,
                onChanged: (idx) {
                  setState(() => _noiseIndex = idx);
                  final weight = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.2);
                  ref.read(sensoryProfileProvider.notifier).updateNoise(weight);
                },
              ),
              const SizedBox(height: 24),

              // Preference 2: Crowd Comfort
              _buildSensoryCategory(
                icon: Icons.groups_rounded,
                iconBg: const Color(0xFFE2F4EE),
                iconColor: QuietColors.tertiaryDark,
                title: 'Crowd Comfort',
                labels: ['Prefer Empty', 'Some People', 'Busy is OK'],
                selectedIndex: _crowdIndex,
                onChanged: (idx) {
                  setState(() => _crowdIndex = idx);
                  final weight = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.2);
                  ref.read(sensoryProfileProvider.notifier).updateCrowd(weight);
                },
              ),
              const SizedBox(height: 24),

              // Preference 3: Light Intensity
              _buildSensoryCategory(
                icon: Icons.wb_sunny_rounded,
                iconBg: const Color(0xFFFEF7E6),
                iconColor: const Color(0xFFB57C1E),
                title: 'Light Intensity',
                labels: ['Dim/Soft', 'Standard', 'Bright/Daylight'],
                selectedIndex: _lightIndex,
                onChanged: (idx) {
                  setState(() => _lightIndex = idx);
                  final weight = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.2);
                  ref.read(sensoryProfileProvider.notifier).updateLight(weight);
                },
              ),

              const SizedBox(height: 24),

              // Preference 4: Traffic Congestion Tolerance
              _buildSensoryCategory(
                icon: Icons.directions_car_rounded,
                iconBg: const Color(0xFFE8F1F5),
                iconColor: const Color(0xFF2C6E8F),
                title: 'Traffic Congestion',
                labels: ['Avoid Traffic', 'Moderate', 'Standard'],
                selectedIndex: _trafficIndex,
                onChanged: (idx) {
                  setState(() => _trafficIndex = idx);
                  final weight = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.2);
                  ref.read(sensoryProfileProvider.notifier).updateTraffic(weight);
                },
              ),
              const SizedBox(height: 24),

              // Preference 5: Detour Willingness
              _buildSensoryCategory(
                icon: Icons.alt_route_rounded,
                iconBg: const Color(0xFFF3ECE5),
                iconColor: const Color(0xFF9A5B2D),
                title: 'Detour Willingness for Calm',
                labels: ['Extra Calm (+40%)', 'Balanced (+20%)', 'Fastest Route'],
                selectedIndex: _timeToleranceIndex,
                onChanged: (idx) {
                  setState(() => _timeToleranceIndex = idx);
                  final tolerance = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.15);
                  ref.read(sensoryProfileProvider.notifier).updateTimeTolerance(tolerance);
                },
              ),

              const SizedBox(height: 28),

              // Offline Navigation & Maps Pack (visible in settings mode)
              if (!widget.isStandaloneOnboarding) ...[
                _buildOfflineMapsCard(),
                const SizedBox(height: 16),
                _buildServerConnectionCard(),
                const SizedBox(height: 24),
              ],

              // Primary CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF456B34),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await ref.read(sensoryProfileProvider.notifier).saveProfile();
                    if (widget.isStandaloneOnboarding) {
                      await AppConfigService().setOnboardingCompleted(true);
                    }
                    if (context.mounted) {
                      if (widget.isStandaloneOnboarding) {
                        context.go('/explore');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: QuietColors.primaryDark,
                            content: Text(
                              'Sensory profile updated and saved locally. Navigation routes will adapt accordingly.',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    widget.isStandaloneOnboarding ? 'Save & Start Exploring →' : 'Save Sensory Preferences',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineMapsCard() {
    final info = _tileCacheInfo;
    final isReady = info?.isPunePackInstalled ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E9E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.offline_pin_rounded, color: QuietColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Maps & Navigation',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: QuietColors.textCharcoal,
                      ),
                    ),
                    Text(
                      '${info?.tileCount ?? 0} tiles cached • ${info?.sizeInMb ?? 0.0} MB',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: QuietColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isReady)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Offline Ready',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: QuietColors.primaryDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Download offline cartography for Pune Hadapsar (Amanora, Magarpatta, Mundhwa) for zero-latency, calm navigation when out of network coverage.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: QuietColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          if (_isDownloadingTiles) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                minHeight: 8,
                backgroundColor: const Color(0xFFDFE6DF),
                valueColor: const AlwaysStoppedAnimation<Color>(QuietColors.primaryDark),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloading tiles ($_downloadedCount/$_downloadTotal)...',
                  style: GoogleFonts.inter(fontSize: 11, color: QuietColors.primaryDark, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: GoogleFonts.inter(fontSize: 11, color: QuietColors.primaryDark, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startDownloadTilePack,
                    icon: Icon(isReady ? Icons.refresh_rounded : Icons.download_rounded, size: 18),
                    label: Text(
                      isReady ? 'Update Pune Pack (~8 MB)' : 'Download Pune Pack (~8 MB)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuietColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if ((info?.tileCount ?? 0) > 0) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFC62828), size: 20),
                    tooltip: 'Clear tile cache',
                    onPressed: () async {
                      await TileCacheService().clearTileCache();
                      await _loadTileCacheInfo();
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEditServerDialog() {
    final currentUrl = ApiClient().baseUrl;
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.dns_rounded, color: QuietColors.primaryDark, size: 22),
            const SizedBox(width: 8),
            Text(
              'Backend Server URL',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure the FastAPI server endpoint for real devices on your local Wi-Fi or USB tether:',
              style: GoogleFonts.inter(fontSize: 12, color: QuietColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Server Base URL',
                hintText: 'http://192.168.1.x:8000',
                filled: true,
                fillColor: const Color(0xFFF4F6F4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              'Quick Presets:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: QuietColors.textCharcoal),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Emulator (10.0.2.2)'),
                  onPressed: () => controller.text = 'http://10.0.2.2:8000',
                ),
                ActionChip(
                  label: const Text('USB / Local (127.0.0.1)'),
                  onPressed: () => controller.text = 'http://127.0.0.1:8000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: QuietColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: QuietColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                ApiClient().updateBaseUrl(newUrl);
                await AppConfigService().setServerBaseUrl(newUrl);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  _testServerConnection();
                }
              }
            },
            child: Text('Save & Reconnect', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildServerConnectionCard() {
    final currentUrl = ApiClient().baseUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _serverIsOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _serverIsOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: _serverIsOnline ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backend Server Connection',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: QuietColors.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _serverPingStatus ?? 'Checking connection...',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _serverIsOnline ? const Color(0xFF2E7D32) : const Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTestingServer)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: QuietColors.primaryDark),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: QuietColors.textMuted),
                  tooltip: 'Test Connection',
                  onPressed: () => _testServerConnection(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showEditServerDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 16, color: QuietColors.primaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentUrl,
                      style: GoogleFonts.inter(fontSize: 12, color: QuietColors.textCharcoal, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: QuietColors.primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Edit IP',
                      style: GoogleFonts.inter(fontSize: 11, color: QuietColors.primaryDark, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Physical phone testing: Set to your computer\'s Wi-Fi IP (e.g. http://192.168.1.x:8000). QuietPath will also run 100% offline with on-device fallbacks.',
            style: GoogleFonts.inter(fontSize: 10, color: QuietColors.textMuted, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSensoryCategory({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: QuietColors.textCharcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Discrete track
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: List.generate(3, (index) {
              final isSelected = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[index],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? QuietColors.textCharcoal
                            : QuietColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class BoxSideShadow extends BoxShadow {
  const BoxSideShadow({
    super.color,
    super.offset,
    super.blurRadius,
  });
}
