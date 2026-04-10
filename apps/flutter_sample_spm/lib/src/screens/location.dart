import 'package:customer_io/customer_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;

import '../components/container.dart';
import '../components/scroll_view.dart';
import '../components/text_field_label.dart';
import '../theme/sizes.dart';
import '../utils/extensions.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  String _statusText = 'No location set yet';

  static const _presetNames = [
    'New York', 'London', 'Tokyo', 'Sydney', 'Sao Paulo', '0, 0'
  ];
  static const _presetCoords = [
    [40.7128, -74.0060],
    [51.5074, -0.1278],
    [35.6762, 139.6503],
    [-33.8688, 151.2093],
    [-23.5505, -46.6333],
    [0.0, 0.0],
  ];

  void _setLocation(double latitude, double longitude, String source) {
    CustomerIO.location.setLastKnownLocation(
      latitude: latitude,
      longitude: longitude,
    );
    setState(() {
      _statusText =
          'Last set: $latitude, $longitude ($source)';
    });
    context.showSnackBar('Location set ($source)');
  }

  static const _permissionChannel =
      MethodChannel('io.customer.testbed/permissions');

  Future<void> _requestSdkLocation() async {
    final status =
        await _permissionChannel.invokeMethod<String>('requestLocationPermission');

    if (status == 'permanentlyDenied') {
      if (!mounted) return;
      context.showMessageDialog(
        'Location Permission Required',
        'Location permission is permanently denied. Please enable it from app settings.',
        actions: [
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop();
              _permissionChannel.invokeMethod('openAppSettings');
            },
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
      return;
    }

    if (status == 'granted') {
      CustomerIO.location.requestLocationUpdate();
      setState(() {
        _statusText = 'Requested SDK location update...';
      });
      if (!mounted) return;
      context.showSnackBar('SDK location update requested');
    } else {
      if (!mounted) return;
      context.showSnackBar('Location permission denied');
    }
  }

  void _setManualLocation() {
    final latText = _latitudeController.text.trim();
    final lonText = _longitudeController.text.trim();

    if (latText.isEmpty || lonText.isEmpty) {
      context.showSnackBar('Enter valid coordinates');
      return;
    }

    final latitude = double.tryParse(latText);
    final longitude = double.tryParse(lonText);

    if (latitude == null || longitude == null) {
      context.showSnackBar('Enter valid coordinates');
      return;
    }

    _setLocation(latitude, longitude, 'Manual');
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Sizes sizes = Theme.of(context).extension<Sizes>()!;
    final theme = Theme.of(context);

    return AppContainer(
      appBar: AppBar(
        backgroundColor: null,
      ),
      body: FullScreenScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location Testing',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              // Section 1: Quick Presets
              _SectionCard(
                title: 'Quick Presets',
                description:
                    'Tap a city to call setLastKnownLocation with its coordinates.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    _presetNames.length,
                    (i) => OutlinedButton(
                      onPressed: () => _setLocation(
                          _presetCoords[i][0], _presetCoords[i][1], _presetNames[i]),
                      child: Text(_presetNames[i]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: SDK Location Request
              _SectionCard(
                title: 'SDK Location Request',
                description:
                    'Asks the SDK to fetch location once. Requires location permission granted by the host app.',
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: sizes.buttonDefault(),
                  ),
                  onPressed: _requestSdkLocation,
                  child: const Text('Request Location Update'),
                ),
              ),
              const SizedBox(height: 16),

              // Section 3: Manual Entry
              _SectionCard(
                title: 'Manual Entry',
                description: 'Enter custom latitude and longitude values.',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        label: TextFieldLabel(
                          text: 'Latitude',
                          semanticsLabel: 'Latitude Input',
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: true),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        label: TextFieldLabel(
                          text: 'Longitude',
                          semanticsLabel: 'Longitude Input',
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: true),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: sizes.buttonDefault(),
                      ),
                      onPressed: _setManualLocation,
                      child: const Text('Set Location'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
