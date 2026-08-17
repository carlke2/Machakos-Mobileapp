import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Result object returned by [DirectionsService].
class DirectionsResult {
  const DirectionsResult({
    required this.points,
    this.distanceText,
    this.durationText,
    this.errorMessage,
  });

  final List<LatLng> points;
  final String? distanceText;
  final String? durationText;
  final String? errorMessage;
}

/// Service to query Google Directions API and decode polyline routes.
class DirectionsService {
  DirectionsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const String _mapsApiKey = 'AIzaSyDG6P_pPPLSpM9FMBrTL3t5mjj0JlJRZQ0';

  Future<DirectionsResult> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$originLat,$originLng&destination=$destLat,$destLng&mode=driving&key=$_mapsApiKey';

      debugPrint('[DirectionsService] Requesting directions from ($originLat, $originLng) to ($destLat, $destLng)');
      final response = await _dio.get<Map<String, dynamic>>(url);
      final data = response.data;

      if (data == null) {
        return const DirectionsResult(
          points: [],
          errorMessage: 'Empty response from Directions API',
        );
      }

      final status = data['status'] as String?;
      if (status != 'OK') {
        final errorMsg = data['error_message'] as String? ?? 'Status: $status';
        debugPrint('[DirectionsService] API Error: $errorMsg');
        return DirectionsResult(
          points: [],
          errorMessage: errorMsg,
        );
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return const DirectionsResult(
          points: [],
          errorMessage: 'No route found between locations',
        );
      }

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List<dynamic>?;
      String? distanceText;
      String? durationText;

      if (legs != null && legs.isNotEmpty) {
        final firstLeg = legs.first as Map<String, dynamic>;
        distanceText = firstLeg['distance']?['text'] as String?;
        durationText = firstLeg['duration']?['text'] as String?;
      }

      final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>?;
      final pointsString = overviewPolyline?['points'] as String?;

      if (pointsString == null || pointsString.isEmpty) {
        return DirectionsResult(
          points: [],
          distanceText: distanceText,
          durationText: durationText,
        );
      }

      final decodedPoints = _decodePolyline(pointsString);
      debugPrint('[DirectionsService] Successfully decoded ${decodedPoints.length} polyline points ($distanceText, $durationText)');

      return DirectionsResult(
        points: decodedPoints,
        distanceText: distanceText,
        durationText: durationText,
      );
    } catch (e, st) {
      debugPrint('[DirectionsService] Failed to fetch directions: $e\n$st');
      return DirectionsResult(
        points: [],
        errorMessage: 'Failed to connect to Directions service: $e',
      );
    }
  }

  /// Decodes an encoded polyline string into a list of [LatLng] coordinates.
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
