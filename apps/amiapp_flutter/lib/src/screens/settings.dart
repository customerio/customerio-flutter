import 'package:customer_io/customer_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../auth.dart';
import '../components/container.dart';
import '../customer_io.dart';
import '../data/config.dart';
import '../data/screen.dart';
import '../theme/sizes.dart';
import '../utils/extensions.dart';
import '../widgets/app_footer.dart';
import '../widgets/header.dart';
import '../widgets/settings_form_field.dart';

class SettingsScreen extends StatefulWidget {
  final AmiAppAuth auth;
  final String? cdpApiKeyInitialValue;
  final String? siteIdInitialValue;

  const SettingsScreen({
    required this.auth,
    this.cdpApiKeyInitialValue,
    this.siteIdInitialValue,
    super.key,
  });

  CustomerIOSDK get _customerIOSDK => CustomerIOSDKInstance.get();

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _deviceTokenValueController;
  late final TextEditingController _cdpApiKeyValueController;
  late final TextEditingController _siteIDValueController;
  late final TextEditingController _apiHostValueController;
  late final TextEditingController _cdnHostValueController;
  late final TextEditingController _flushAtValueController;
  late final TextEditingController _flushIntervalValueController;

  late bool _featureTrackScreens;
  late bool _featureTrackDeviceAttributes;
  late bool _featureDebugMode;

  @override
  void initState() {
    CustomerIO.instance.pushMessaging.getRegisteredDeviceToken().then((value) =>
        setState(() => _deviceTokenValueController.text = value ?? ''));

    final cioConfig = widget._customerIOSDK.sdkConfig;
    _deviceTokenValueController = TextEditingController();
    _cdpApiKeyValueController = TextEditingController(
        text: widget.cdpApiKeyInitialValue ?? cioConfig?.cdpApiKey);
    _siteIDValueController = TextEditingController(
        text: widget.siteIdInitialValue ?? cioConfig?.migrationSiteId);
    _apiHostValueController = TextEditingController(text: cioConfig?.apiHost);
    _cdnHostValueController = TextEditingController(text: cioConfig?.cdnHost);
    _flushAtValueController =
        TextEditingController(text: cioConfig?.flushAt?.toString());
    _flushIntervalValueController =
        TextEditingController(text: cioConfig?.flushInterval?.toString());
    _featureTrackScreens = cioConfig?.screenTrackingEnabled ?? true;
    _featureTrackDeviceAttributes =
        cioConfig?.autoTrackDeviceAttributes ?? true;
    _featureDebugMode = cioConfig?.debugModeEnabled ?? true;

    super.initState();
  }

  void _saveSettings(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newConfig = CustomerIOSDKConfig(
      cdpApiKey: _cdpApiKeyValueController.text.trim(),
      migrationSiteId: _siteIDValueController.text.trim().nullIfEmpty(),
      apiHost: _apiHostValueController.text.trim().nullIfEmpty(),
      cdnHost: _cdnHostValueController.text.trim().nullIfEmpty(),
      flushAt: _flushAtValueController.text.trim().toIntOrNull(),
      flushInterval: _flushIntervalValueController.text.trim().toIntOrNull(),
      screenTrackingEnabled: _featureTrackScreens,
      autoTrackDeviceAttributes: _featureTrackDeviceAttributes,
      debugModeEnabled: _featureDebugMode,
    );
    widget._customerIOSDK.saveConfigToPreferences(newConfig).then((success) {
      if (!context.mounted) {
        return;
      } else if (success) {
        context.showSnackBar('Settings saved successfully');
        Navigator.of(context).pop();
        // Restart app here
      } else {
        context.showSnackBar('Could not save settings');
      }
      return null;
    });
  }

  void _restoreDefaultSettings() {
    final defaultConfig = widget._customerIOSDK.getDefaultConfig();
    if (defaultConfig == null) {
      context.showSnackBar('No default values found');
      return;
    }

    setState(() {
      _cdpApiKeyValueController.text = defaultConfig.cdpApiKey;
      _siteIDValueController.text = defaultConfig.migrationSiteId ?? '';
      _apiHostValueController.text = defaultConfig.apiHost ?? '';
      _cdnHostValueController.text = defaultConfig.cdnHost ?? '';
      _flushAtValueController.text = defaultConfig.flushAt?.toString() ?? '';
      _flushIntervalValueController.text =
          defaultConfig.flushInterval?.toString() ?? '';
      _featureTrackScreens = defaultConfig.screenTrackingEnabled;
      _featureTrackDeviceAttributes =
          defaultConfig.autoTrackDeviceAttributes ?? true;
      _featureDebugMode = defaultConfig.debugModeEnabled;
      _saveSettings(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Sizes sizes = Theme.of(context).extension<Sizes>()!;

    return PopScope(
      onPopInvokedWithResult: (bool didPop, result) {
        if (widget.auth.signedIn == false) {
          context.go(Screen.login.location);
        }
      },
      child: AppContainer(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Container(
                      constraints:
                          BoxConstraints.loose(sizes.inputFieldDefault()),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        children: [
                          TextSettingsFormField(
                            labelText: 'Device Token',
                            semanticsLabel: 'Device Token Input',
                            hintText: 'Fetching...',
                            valueController: _deviceTokenValueController,
                            readOnly: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy),
                              tooltip: 'Copy Token',
                              onPressed: () {
                                final clipboardData = ClipboardData(
                                    text: _deviceTokenValueController.text);
                                Clipboard.setData(clipboardData).then((_) {
                                  if (context.mounted) {
                                    context.showSnackBar(
                                      'Device Token copied to clipboard',
                                    );
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextSettingsFormField(
                            labelText: 'CDP API Key',
                            semanticsLabel: 'CDP API Key Input',
                            valueController: _cdpApiKeyValueController,
                            validator: (value) =>
                                value?.trim().isNotEmpty == true
                                    ? null
                                    : 'This field cannot be blank',
                          ),
                          const SizedBox(height: 16),
                          TextSettingsFormField(
                            labelText: 'Site Id',
                            semanticsLabel: 'Site ID Input',
                            valueController: _siteIDValueController,
                          ),
                          const SizedBox(height: 32),
                          TextSettingsFormField(
                            labelText: 'API Host',
                            semanticsLabel: 'API Host Input',
                            hintText: 'cdp.customer.io/v1',
                            valueController: _apiHostValueController,
                            validator: (value) => value?.isEmptyOrValidUrl() !=
                                    false
                                ? null
                                : 'Please enter url e.g. cdp.customer.io/v1 (without https)',
                          ),
                          const SizedBox(height: 16),
                          TextSettingsFormField(
                            labelText: 'CDN Host',
                            semanticsLabel: 'CDN Host Input',
                            hintText: 'cdp.customer.io/v1',
                            valueController: _cdnHostValueController,
                            validator: (value) => value?.isEmptyOrValidUrl() !=
                                    false
                                ? null
                                : 'Please enter url e.g. cdp.customer.io/v1 (without https)',
                          ),
                          const SizedBox(height: 32),
                          TextSettingsFormField(
                            labelText: 'Flush At',
                            semanticsLabel: 'BQ Min Number of Tasks Input',
                            hintText: '20',
                            valueController: _flushAtValueController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              bool isBlank = value?.trim().isNotEmpty != true;
                              if (!isBlank) {
                                int minValue = 1;
                                bool isInvalid =
                                    value?.isValidInt(min: minValue) != true;
                                if (isInvalid) {
                                  return 'The value must be greater than or equal to $minValue';
                                }
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextSettingsFormField(
                            labelText: 'Flush Interval',
                            semanticsLabel: 'BQ Seconds Delay Input',
                            hintText: '30',
                            valueController: _flushIntervalValueController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              bool isBlank = value?.trim().isNotEmpty != true;
                              if (!isBlank) {
                                int minValue = 1;
                                bool isInvalid =
                                    value?.isValidInt(min: minValue) != true;
                                if (isInvalid) {
                                  return 'The value must be greater than or equal to $minValue';
                                }
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          const TextSectionHeader(
                            text: 'Features',
                          ),
                          SwitchSettingsFormField(
                            labelText: 'Track Screens',
                            semanticsLabel: 'Track Screens Toggle',
                            value: _featureTrackScreens,
                            updateState: ((value) =>
                                setState(() => _featureTrackScreens = value)),
                          ),
                          SwitchSettingsFormField(
                            labelText: 'Track Device Attributes',
                            semanticsLabel: 'Track Device Attributes Toggle',
                            value: _featureTrackDeviceAttributes,
                            updateState: ((value) => setState(
                                () => _featureTrackDeviceAttributes = value)),
                          ),
                          SwitchSettingsFormField(
                            labelText: 'Debug Mode',
                            semanticsLabel: 'Debug Mode Toggle',
                            value: _featureDebugMode,
                            updateState: ((value) =>
                                setState(() => _featureDebugMode = value)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: sizes.buttonDefault(),
                ),
                onPressed: () => _saveSettings(context),
                child: Text(
                  'Save'.toUpperCase(),
                  semanticsLabel: 'Save Settings Button',
                ),
              ),
            ),
            TextButton(
              style: FilledButton.styleFrom(
                minimumSize: sizes.buttonDefault(),
              ),
              onPressed: () => _restoreDefaultSettings(),
              child: const Text(
                'Restore Defaults',
                semanticsLabel: 'Restore Default Settings Button',
              ),
            ),
            const SizedBox(height: 8),
            const TextFooter(
                text: 'Note: You must restart the app to apply these settings'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
