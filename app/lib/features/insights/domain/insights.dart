class DayPoint {
  const DayPoint({required this.date, required this.planned, required this.done, this.ratio});

  final DateTime date;
  final int planned;
  final int done;

  /// Share completed that day; null when nothing was planned.
  final double? ratio;
}

class RateRow {
  const RateRow({required this.label, required this.steps, required this.rate});

  final String label;
  final int steps;
  final double rate;
}

class Observation {
  const Observation({required this.kind, required this.text});

  final String kind;
  final String text;
}

class InsightsSummary {
  const InsightsSummary({
    required this.days,
    required this.daysShowedUp,
    required this.daysPlanned,
    required this.partialWins,
    required this.series,
    required this.routines,
    required this.partsOfDay,
    required this.skipReasons,
    required this.observations,
    this.consistency,
    this.completionRate,
  });

  final int days;
  final int daysShowedUp;
  final int daysPlanned;
  final double? consistency;
  final double? completionRate;
  final int partialWins;
  final List<DayPoint> series;
  final List<RateRow> routines;
  final List<RateRow> partsOfDay;
  final Map<String, int> skipReasons;
  final List<Observation> observations;

  bool get hasData => daysPlanned > 0;
}
