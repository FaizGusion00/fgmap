import '../../../core/utils/geo.dart';

/// Jejak GPS pendek untuk carian had laju tanpa laluan. Dikemas kini kira-kira setiap 20 s atau 250 m.
class SpeedLimitTrail {
  static const refreshEvery = Duration(seconds: 20);
  static const refreshDistanceM = 250.0;
  static const minStepM = 20.0;
  static const maxPoints = 8;

  final List<GeoPoint> points = [];
  DateTime? _lastQueryAt;
  GeoPoint? _lastQueryPoint;

  void add(GeoPoint point) {
    if (points.isNotEmpty && distanceMeters(points.last, point) < minStepM) {
      return;
    }
    points.add(point);
    if (points.length > maxPoints) points.removeAt(0);
  }

  bool get canQuery => points.length >= 2;

  bool due(DateTime now, GeoPoint here) {
    if (!canQuery) return false;
    final at = _lastQueryAt;
    final anchor = _lastQueryPoint;
    if (at == null || anchor == null) return true;
    return now.difference(at) >= refreshEvery ||
        distanceMeters(anchor, here) >= refreshDistanceM;
  }

  void markQueried(DateTime now, GeoPoint here) {
    _lastQueryAt = now;
    _lastQueryPoint = here;
  }

  void clear() {
    points.clear();
    _lastQueryAt = null;
    _lastQueryPoint = null;
  }
}
