/// Day of the cycle, the same way the server computes `Episode.cycleDay`:
/// days since cycleStart + 1; 1 when before the start or unknown.
int cycleDayFor(DateTime? cycleStart, DateTime now) {
  if (cycleStart == null) return 1;
  // Compare calendar dates in UTC so daylight-saving shifts don't matter.
  final start = DateTime.utc(cycleStart.year, cycleStart.month, cycleStart.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final days = today.difference(start).inDays;
  return days < 0 ? 1 : days + 1;
}

/// "08:00" → minutes since midnight ("24:00" → 1440).
int minutesOf(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0].trim()) ?? 0;
  final m = int.tryParse(parts[1].trim()) ?? 0;
  final total = h * 60 + m;
  // Treat 00:00 as the end of the day (ondansetron 3x: 08/16/24 h).
  return total == 0 ? 1440 : total;
}

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "1–3, 5" style compact list.
String compactDays(List<int> days) {
  final s = (days.toSet().toList()..sort());
  final parts = <String>[];
  var i = 0;
  while (i < s.length) {
    var j = i;
    while (j + 1 < s.length && s[j + 1] == s[j] + 1) {
      j++;
    }
    parts.add(i == j ? '${s[i]}' : '${s[i]}–${s[j]}');
    i = j + 1;
  }
  return parts.join(', ');
}
