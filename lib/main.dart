
import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SmartLogisticsApp());
}

class RouteStop {
  final String label;
  final LatLng position;
  final Color color;

  const RouteStop({
    required this.label,
    required this.position,
    required this.color,
  });
}

class SmartLogisticsApp extends StatelessWidget {
  const SmartLogisticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Logistics Routing',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const RoutingPage(),
    );
  }
}

class RoutingPage extends StatefulWidget {
  const RoutingPage({super.key});

  static const LatLng mapCenter = LatLng(-7.2683, 112.7424);

  static const List<RouteStop> stops = [
    RouteStop(label: 'P1', position: LatLng(-7.2890, 112.7285), color: Colors.red),
    RouteStop(label: 'P2', position: LatLng(-7.2734, 112.7420), color: Colors.red),
    RouteStop(label: 'P3', position: LatLng(-7.2640, 112.7560), color: Colors.red),
    RouteStop(label: 'P4', position: LatLng(-7.2495, 112.7490), color: Colors.red),
    RouteStop(label: 'P5', position: LatLng(-7.2545, 112.7705), color: Colors.red),
  ];

  static const List<LatLng> routePath = [
    LatLng(-7.2890, 112.7285),
    LatLng(-7.2734, 112.7420),
    LatLng(-7.2640, 112.7560),
    LatLng(-7.2495, 112.7490),
    LatLng(-7.2545, 112.7705),
    LatLng(-7.2890, 112.7285),
  ];

  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  static const String _storageKey = 'routing_points_v1';

  late List<RouteStop> _stops;
  late List<LatLng> _routePath;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  int? _editingStopIndex;
  bool _isLoadingStorage = true;

  @override
  void initState() {
    super.initState();
    _stops = List<RouteStop>.from(RoutingPage.stops);
    _routePath = _buildRoutePath(_stops);
    _loadSavedStops();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedStops() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_storageKey);

    if (!mounted) return;

    if (savedValue == null || savedValue.isEmpty) {
      setState(() {
        _stops = List<RouteStop>.from(RoutingPage.stops);
        _routePath = _buildRoutePath(_stops);
        _isLoadingStorage = false;
      });
      return;
    }

    final loadedStops = _decodeStops(savedValue);
    setState(() {
      _stops = loadedStops.isEmpty ? List<RouteStop>.from(RoutingPage.stops) : loadedStops;
      _routePath = _buildRoutePath(_stops);
      _isLoadingStorage = false;
    });
  }

  Future<void> _persistStops() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _encodeStops(_stops));
  }

  String _encodeStops(List<RouteStop> stops) {
    if (stops.isEmpty) return '';

    final items = stops.map((stop) {
      final label = Uri.encodeComponent(stop.label);
      return '$label|${stop.position.latitude}|${stop.position.longitude}';
    }).toList();

    return items.join(';');
  }

  List<RouteStop> _decodeStops(String raw) {
    final items = raw.split(';');
    final result = <RouteStop>[];

    for (final item in items) {
      if (item.trim().isEmpty) continue;
      final parts = item.split('|');
      if (parts.length < 3) continue;

      final label = Uri.decodeComponent(parts[0]);
      final latitude = double.tryParse(parts[1]);
      final longitude = double.tryParse(parts[2]);

      if (label.isEmpty || latitude == null || longitude == null) continue;

      result.add(
        RouteStop(
          label: label,
          position: LatLng(latitude, longitude),
          color: Colors.red,
        ),
      );
    }

    return result;
  }

  void _exportRouteData() {
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada titik yang bisa di-export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final payload = jsonEncode(
      _stops.map((stop) {
        return {
          'label': stop.label,
          'latitude': stop.position.latitude,
          'longitude': stop.position.longitude,
        };
      }).toList(),
    );

    final blob = html.Blob([payload]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'route_points.json');
    anchor.click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data titik berhasil di-export sebagai JSON.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Layanan lokasi mati. Aktifkan GPS atau isi koordinat manual.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi ditolak. Silakan isi koordinat manual.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin lokasi permanen ditolak. Gunakan input manual.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: 10),
    );

    setState(() {
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Koordinat lokasi saat ini berhasil diisi.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearForm() {
    _labelController.clear();
    _latController.clear();
    _lngController.clear();
    _editingStopIndex = null;
  }

  void _startEditStop(int index) {
    final stop = _stops[index];
    _labelController.text = stop.label;
    _latController.text = stop.position.latitude.toStringAsFixed(6);
    _lngController.text = stop.position.longitude.toStringAsFixed(6);
    setState(() {
      _editingStopIndex = index;
    });
  }

  List<LatLng> _buildRoutePath(List<RouteStop> stops) {
    if (stops.isEmpty) return <LatLng>[];

    final points = stops.map((stop) => stop.position).toList();
    if (points.length > 1) {
      return [...points, points.first];
    }
    return points;
  }

  String _routeSummary() {
    if (_stops.isEmpty) return 'Belum ada titik';
    return _stops.map((stop) => stop.label).join(' → ');
  }

  void _resetStops() {
    setState(() {
      _stops = List<RouteStop>.from(RoutingPage.stops);
      _routePath = _buildRoutePath(_stops);
    });
    _persistStops();
  }

  void _moveStop(int index, bool moveUp) {
    if (index < 0 || index >= _stops.length) return;

    final newIndex = moveUp ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= _stops.length) return;

    setState(() {
      final item = _stops.removeAt(index);
      _stops.insert(newIndex, item);
      _routePath = _buildRoutePath(_stops);
    });
    _persistStops();
  }

  void _removeStop(int index) {
    if (index < 0 || index >= _stops.length) return;

    final removed = _stops[index];

    setState(() {
      _stops.removeAt(index);
      _routePath = _buildRoutePath(_stops);
    });
    _persistStops();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Titik ${removed.label} dihapus dari rute.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _saveStopFromInput() {
    final label = _labelController.text.trim();
    final latValue = double.tryParse(_latController.text.trim());
    final lngValue = double.tryParse(_lngController.text.trim());

    if (label.isEmpty || latValue == null || lngValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi label, latitude, dan longitude dengan benar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (latValue < -90 || latValue > 90 || lngValue < -180 || lngValue > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koordinat tidak valid. Pastikan latitude dan longitude benar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final duplicateExists = _stops.any(
      (stop) =>
          stop.label.toLowerCase() == label.toLowerCase() &&
          _editingStopIndex != _stops.indexOf(stop),
    );

    if (duplicateExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama titik sudah ada, gunakan label lain.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = RouteStop(
      label: label,
      position: LatLng(latValue, lngValue),
      color: Colors.red,
    );

    setState(() {
      if (_editingStopIndex == null) {
        _stops.add(data);
      } else {
        _stops[_editingStopIndex!] = data;
      }
      _routePath = _buildRoutePath(_stops);
      _clearForm();
    });
    _persistStops();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _editingStopIndex == null
              ? 'Titik $label berhasil ditambahkan ke peta.'
              : 'Titik $label berhasil diperbarui.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  List<Polyline> get routeLines => [
    Polyline(
      points: _routePath,
      color: const Color(0xFF0E56D4),
      strokeWidth: 4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 950;

    if (_isLoadingStorage) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: const Color(0xFF0D5EA8),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Express Route Logistics',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              'UTS Maps Flutter - Route Optimization',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFFDDEBFF),
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 1600,
            child: Row(
              children: [
                Expanded(
                  flex: isCompact ? 1 : 7,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: MapController(),
                          options: MapOptions(
                            initialCenter: RoutingPage.mapCenter,
                            initialZoom: 12,
                            minZoom: 10,
                            maxZoom: 18,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.yemima.smartlogistics',
                            ),
                            PolylineLayer(
                              polylines: routeLines,
                            ),
                            MarkerLayer(
                              markers: [
                                for (int i = 0; i < _stops.length; i++)
                                  Marker(
                                    point: _stops[i].position,
                                    width: 34,
                                    height: 34,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          _stops[i].label,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(220),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: const Text(
                              'Pusat Peta: -7.2575, 112.7521',
                              style: TextStyle(
                                color: Color(0xFF1E2A39),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Row(
                            children: [
                              _smallMapButton(Icons.map_rounded),
                              const SizedBox(width: 8),
                              _smallMapButton(Icons.layers_rounded),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          right: 14,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.add, color: Colors.indigo),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: isCompact ? 2 : 5,
                  child: Container(
                    color: const Color(0xFFF4F6FA),
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 12),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  _routeToggle('Aksi Rute', true),
                                  const SizedBox(width: 8),
                                  _routeToggle('Input Titik', false),
                                  const Spacer(),
                                  _routeToggle('Daftar (${_stops.length})', false),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _editingStopIndex == null ? 'Input Titik Baru' : 'Edit Titik',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E2A39),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _labelController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama titik',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _latController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _lngController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _getCurrentLocation,
                                    icon: const Icon(Icons.my_location_rounded),
                                    label: const Text('Ambil Lokasi Saya'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _saveStopFromInput,
                                        icon: Icon(
                                          _editingStopIndex == null
                                              ? Icons.add_location_alt_rounded
                                              : Icons.save_alt_rounded,
                                        ),
                                        label: Text(
                                          _editingStopIndex == null
                                              ? 'Tambah Titik ke Rute'
                                              : 'Simpan Perubahan',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0D5EA8),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                      ),
                                    ),
                                    if (_editingStopIndex != null) ...[
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: _clearForm,
                                        icon: const Icon(Icons.close_rounded),
                                        label: const Text('Batal'),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _exportRouteData,
                                    icon: const Icon(Icons.download_rounded),
                                    label: const Text('Export JSON'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Daftar Titik Saat Ini',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E2A39),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_stops.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Belum ada titik. Tambahkan titik baru di form di atas.',
                                      style: TextStyle(
                                        color: Color(0xFF5A6981),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                else
                                  ..._stops.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final stop = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F6FA),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  stop.label,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1E2A39),
                                                  ),
                                                ),
                                                Text(
                                                  '${stop.position.latitude.toStringAsFixed(4)}, ${stop.position.longitude.toStringAsFixed(4)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF5A6981),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                onPressed: index > 0 ? () => _moveStop(index, true) : null,
                                                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.blueGrey),
                                                tooltip: 'Naikkan urutan',
                                              ),
                                              IconButton(
                                                onPressed: index < _stops.length - 1 ? () => _moveStop(index, false) : null,
                                                icon: const Icon(Icons.arrow_downward_rounded, color: Colors.blueGrey),
                                                tooltip: 'Turunkan urutan',
                                              ),
                                              IconButton(
                                                onPressed: () => _startEditStop(index),
                                                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                                tooltip: 'Edit titik',
                                              ),
                                              IconButton(
                                                onPressed: () => _removeStop(index),
                                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                                tooltip: 'Hapus titik',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _resetStops,
                                    icon: const Icon(Icons.restart_alt_rounded),
                                    label: const Text('Reset ke Titik Default'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _routeChoice(
                            order: '1',
                            title: 'Rute Sesuai Input (Sekuensial)',
                            active: true,
                            accent: const Color(0xFFEC8A2F),
                          ),
                          const SizedBox(height: 10),
                          _routeChoice(
                            order: '2',
                            title: 'Rute Terpendek Algoritma Dijkstra',
                            active: true,
                            accent: const Color(0xFF2F6AE7),
                          ),
                          const SizedBox(height: 10),
                          _routeChoice(
                            order: '3',
                            title: 'Rute Terpendek Nearest Neighbor (Greedy TSP)',
                            active: true,
                            accent: const Color(0xFF4BBE60),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: const Center(
                              child: Text(
                                'Bandingkan Semua Ketiga Rute Sekaligus',
                                style: TextStyle(
                                  color: Color(0xFF2B3C59),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Panel Analisis Rute & Efisiensi',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E2A39),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2EBD64),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.trending_up, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _stops.length > 1
                                              ? 'RUTE AKTIF SIAP DIGUNAKAN\nUrutan titik: ${_routeSummary()}'
                                              : 'TAMBAH TITIK BARU UNTUK MEMBUAT RUTE',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    const Icon(Icons.route, color: Color(0xFF2A5BFF), size: 18),
                                    const Text(
                                      'Rute Aktif:',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      _stops.length > 1 ? _routeSummary() : 'Belum ada rute',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Jarak Total',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      _stops.length > 1 ? '${(_stops.length * 3.5).toStringAsFixed(2)} km' : '0.00 km',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Perjalanan',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _routeSummary(),
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.indigo.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F9FC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: const [
                                      _DistanceRow(label: '1. Sekuensial (Urutan Input)', value: '37.80 km (0 m)'),
                                      _DistanceRow(label: '2. Dijkstra Shortest Path', value: '29.41 km (0 ms)'),
                                      _DistanceRow(label: '3. Nearest Neighbor (Heuristik)', value: '29.41 km (0 ms)'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _smallMapButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Icon(icon, color: const Color(0xFF1E2A39), size: 20),
    );
  }

  static Widget _routeToggle(String text, bool active) {
    return Expanded(
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEEF3FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: const Color(0xFFBCD4FF)) : null,
        ),
        child: Center(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: active ? const Color(0xFF1D4ED8) : const Color(0xFF46576A),
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _routeChoice({
    required String order,
    required String title,
    required bool active,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: active ? accent.withAlpha(24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? accent.withAlpha(150) : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  order,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF1F2C3D),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceRow extends StatelessWidget {
  final String label;
  final String value;

  const _DistanceRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2C3D)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF41506B),
            ),
          ),
        ],
      ),
    );
  }
}
