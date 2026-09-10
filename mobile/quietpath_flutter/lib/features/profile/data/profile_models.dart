class SensoryProfile {
  final double noiseSensitivity;
  final double crowdComfort;
  final double lightIntensity;
  final double trafficSensitivity;
  final double constructionSensitivity;
  final double airQualitySensitivity;
  final double timePenaltyTolerance;

  SensoryProfile({
    this.noiseSensitivity = 0.8,
    this.crowdComfort = 0.7,
    this.lightIntensity = 0.5,
    this.trafficSensitivity = 0.7,
    this.constructionSensitivity = 0.8,
    this.airQualitySensitivity = 0.6,
    this.timePenaltyTolerance = 0.6,
  });

  SensoryProfile copyWith({
    double? noiseSensitivity,
    double? crowdComfort,
    double? lightIntensity,
    double? trafficSensitivity,
    double? constructionSensitivity,
    double? airQualitySensitivity,
    double? timePenaltyTolerance,
  }) {
    return SensoryProfile(
      noiseSensitivity: noiseSensitivity ?? this.noiseSensitivity,
      crowdComfort: crowdComfort ?? this.crowdComfort,
      lightIntensity: lightIntensity ?? this.lightIntensity,
      trafficSensitivity: trafficSensitivity ?? this.trafficSensitivity,
      constructionSensitivity: constructionSensitivity ?? this.constructionSensitivity,
      airQualitySensitivity: airQualitySensitivity ?? this.airQualitySensitivity,
      timePenaltyTolerance: timePenaltyTolerance ?? this.timePenaltyTolerance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noise_sensitivity': noiseSensitivity,
      'crowd_comfort': crowdComfort,
      'light_intensity': lightIntensity,
      'traffic_sensitivity': trafficSensitivity,
      'construction_sensitivity': constructionSensitivity,
      'air_quality_sensitivity': airQualitySensitivity,
      'time_penalty_tolerance': timePenaltyTolerance,
    };
  }

  factory SensoryProfile.fromJson(Map<String, dynamic> json) {
    return SensoryProfile(
      noiseSensitivity: (json['noise_sensitivity'] as num?)?.toDouble() ?? 0.8,
      crowdComfort: (json['crowd_comfort'] as num?)?.toDouble() ?? 0.7,
      lightIntensity: (json['light_intensity'] as num?)?.toDouble() ?? 0.5,
      trafficSensitivity: (json['traffic_sensitivity'] as num?)?.toDouble() ?? 0.7,
      constructionSensitivity: (json['construction_sensitivity'] as num?)?.toDouble() ?? 0.8,
      airQualitySensitivity: (json['air_quality_sensitivity'] as num?)?.toDouble() ?? 0.6,
      timePenaltyTolerance: (json['time_penalty_tolerance'] as num?)?.toDouble() ?? 0.6,
    );
  }
}
