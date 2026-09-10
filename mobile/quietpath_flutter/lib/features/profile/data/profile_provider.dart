import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quietpath_flutter/core/network/api_client.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/features/profile/data/profile_models.dart';

class SensoryProfileNotifier extends StateNotifier<SensoryProfile> {
  SensoryProfileNotifier() : super(AppConfigService().sensoryProfile);

  void loadFromConfig() {
    state = AppConfigService().sensoryProfile;
  }

  void updateNoise(double val) {
    state = state.copyWith(noiseSensitivity: val);
    AppConfigService().updateSensoryProfile(state);
  }

  void updateCrowd(double val) {
    state = state.copyWith(crowdComfort: val);
    AppConfigService().updateSensoryProfile(state);
  }

  void updateLight(double val) {
    state = state.copyWith(lightIntensity: val);
    AppConfigService().updateSensoryProfile(state);
  }

  void updateTraffic(double val) {
    state = state.copyWith(trafficSensitivity: val);
    AppConfigService().updateSensoryProfile(state);
  }

  void updateConstruction(double val) {
    state = state.copyWith(constructionSensitivity: val);
    AppConfigService().updateSensoryProfile(state);
  }

  void updateAirQuality(double val) {
    state = state.copyWith(airQualitySensitivity: val);
    AppConfigService().updateSensoryProfile(state);
  }

  void updateTimeTolerance(double val) {
    state = state.copyWith(timePenaltyTolerance: val);
    AppConfigService().updateSensoryProfile(state);
  }

  Future<bool> saveProfile() async {
    // 1. Always save locally first
    await AppConfigService().updateSensoryProfile(state);

    // 2. Optionally sync with backend if online
    try {
      final dio = ApiClient().dio;
      await dio.post('/profiles/', data: state.toJson());
      return true;
    } catch (e) {
      // Offline fallback: local state is preserved
      return true;
    }
  }
}

final sensoryProfileProvider =
    StateNotifierProvider<SensoryProfileNotifier, SensoryProfile>((ref) {
  return SensoryProfileNotifier();
});
