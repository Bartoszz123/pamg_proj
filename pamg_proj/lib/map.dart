import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';


class MapMeasurement {
  final LatLng location;
  final double gravityValue;
  final DateTime timestamp;

  MapMeasurement({
    required this.location,
    required this.gravityValue,
    required this.timestamp,
  });
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();

  final List<MapMeasurement> measurements = [];
  bool isMeasuring = false;

  StreamSubscription<Position>? positionStream;
  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;

  double currentTotalAcceleration = 0.0;
  Position? currentPosition;

  @override
  void dispose() {
    _stopStreams();
    mapController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _stopStreams() {
    positionStream?.cancel();
    accelerometerSubscription?.cancel();
    positionStream = null;
    accelerometerSubscription = null;
  }

  void _onPosition(Position position) {
    if (!mounted) return;
    setState(() {
      currentPosition = position;
    });
    mapController.move(LatLng(position.latitude, position.longitude), 16);
  }

  Future<void> startMeasurement() async {
    if (isMeasuring) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Lokalizacja w telefonie jest wyłączona.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Brak uprawnień do lokalizacji.');
      return;
    }

    if (!mounted) return;
    setState(() {
      isMeasuring = true;
    });

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen(
      _onPosition,
      onError: (Object e) => _showMessage('Błąd GPS: $e'),
    );

    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      if (isMeasuring) _onPosition(first);
    } catch (_) {
    }

    accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      (AccelerometerEvent event) {
        if (!mounted) return;
        setState(() {
          currentTotalAcceleration =
              sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        });
      },
      onError: (Object e) => _showMessage('Błąd akcelerometru: $e'),
    );

    _showMessage('Rozpoczęto pomiar przyspieszenia...');
  }

  void _clearCurrentMeasurement() {
    _stopStreams();
    setState(() {
      isMeasuring = false;
      currentPosition = null;
      currentTotalAcceleration = 0.0;
    });
  }

  void resetMeasurement() {
    _clearCurrentMeasurement();
    _showMessage('Zresetowano bieżący pomiar.');
  }

  void saveMeasurement() {
    if (currentPosition == null) {
      _showMessage('Brak pozycji GPS. Poczekaj na ustalenie lokalizacji.');
      return;
    }

    final newMeasurement = MapMeasurement(
      location: LatLng(currentPosition!.latitude, currentPosition!.longitude),
      gravityValue: currentTotalAcceleration,
      timestamp: DateTime.now(),
    );

    setState(() {
      measurements.add(newMeasurement);
    });

    _clearCurrentMeasurement();
    _showMessage('Zapisano pomiar! Łącznie w pamięci: ${measurements.length}');
  }

  Future<void> exportMeasurements() async {
    if (measurements.isEmpty) {
      _showMessage('Brak zapisanych pomiarów do eksportu.');
      return;
    }

    final geoJsonMap = {
      "type": "FeatureCollection",
      "features": measurements.map((m) {
        return {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [m.location.longitude, m.location.latitude]
          },
          "properties": {
            "gravity_value": m.gravityValue,
            "timestamp": m.timestamp.toIso8601String(),
          }
        };
      }).toList(),
    };

    try {
      final directory = await getApplicationDocumentsDirectory();
      // Nazwa pliku bez spacji i znaków specjalnych
      final timestampStr = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9T]'), '-');
      final file =
          File('${directory.path}/geograv_pomiary_$timestampStr.geojson');

      await file.writeAsString(jsonEncode(geoJsonMap));

      // Udostępnianie pliku na zewnątrz (np. Messenger, Mail, Dysk Google)
      // Jeśli masz share_plus >= 11 i pojawi się ostrzeżenie o przestarzałej metodzie:
      // await SharePlus.instance.share(ShareParams(
      //   files: [XFile(file.path)],
      //   text: 'Eksport pomiarów GeoGrav (GeoJSON)',
      // ));
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/geo+json')],
        text: 'Eksport pomiarów GeoGrav (GeoJSON)',
      );

      if (!mounted) return;
      setState(() {
        measurements.clear();
      });
    } catch (e) {
      _showMessage('Nie udało się wyeksportować pomiarów: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoGrav - Mapa i Pomiary'),
        backgroundColor: const Color(0xFF2C5E3B),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Mapa OpenStreetMap
          FlutterMap(
            mapController: mapController,
            options: const MapOptions(
              initialCenter: LatLng(52.237049, 21.017532), // Domyślny środek (Warszawa)
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.geograv',
              ),
              MarkerLayer(
                markers: [
                  if (currentPosition != null)
                    Marker(
                      point: LatLng(
                          currentPosition!.latitude, currentPosition!.longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                  ...measurements.map((m) => Marker(
                        point: m.location,
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.fiber_manual_record,
                            color: Colors.blue, size: 25),
                      )),
                ],
              ),
            ],
          ),

          if (isMeasuring)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white.withValues(alpha: 0.95),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Wykonywanie pomiaru...',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Wypadkowe przyspieszenie: ${currentTotalAcceleration.toStringAsFixed(3)} m/s²',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF2C5E3B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentPosition == null
                            ? 'Oczekiwanie na pozycję GPS...'
                            : 'GPS: ${currentPosition!.latitude.toStringAsFixed(6)}, '
                                '${currentPosition!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: isMeasuring ? null : startMeasurement,
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    tooltip: 'Pomiar',
                  ),
                  IconButton(
                    onPressed: isMeasuring ? saveMeasurement : null,
                    icon: const Icon(Icons.save, color: Colors.blue),
                    tooltip: 'Zapisz',
                  ),
                  IconButton(
                    onPressed: isMeasuring ? resetMeasurement : null,
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    tooltip: 'Reset',
                  ),
                  IconButton(
                    onPressed: exportMeasurements,
                    icon: const Icon(Icons.share, color: Colors.purple),
                    tooltip: 'Eksportuj (GeoJSON)',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}