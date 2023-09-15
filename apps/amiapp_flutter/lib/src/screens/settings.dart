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
  final String? siteIdInitialValue;
  final String? apiKeyInitialValue;

  const SettingsScreen({
    required this.auth,
    this.siteIdInitialValue,
    this.apiKeyInitialValue,
    super.key,
  });

  CustomerIOSDK get _customerIOSDK => CustomerIOSDKInstance.get();

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _deviceTokenValueController;
  late final TextEditingController _trackingURLValueController;
  late final TextEditingController _siteIDValueController;
  late final TextEditingController _apiKeyValueController;
  late final TextEditingController _bqSecondsDelayValueController;
  late final TextEditingController _bqMinNumberOfTasksValueController;

  late bool _featureTrackScreens;
  late bool _featureTrackDeviceAttributes;
  late bool _featureDebugMode;

  @override
  void initState() {
    widget._customerIOSDK.getDeviceToken().then((value) =>
        setState(() => _deviceTokenValueController.text = value ?? ''));

    final cioConfig = widget._customerIOSDK.sdkConfig;
    _deviceTokenValueController = TextEditingController();
    _trackingURLValueController =
        TextEditingController(text: cioConfig?.trackingUrl);
    _siteIDValueController = TextEditingController(
        text: widget.siteIdInitialValue ?? cioConfig?.siteId);
    _apiKeyValueController = TextEditingController(
        text: widget.apiKeyInitialValue ?? cioConfig?.apiKey);
    _bqSecondsDelayValueController = TextEditingController(
        text: cioConfig?.backgroundQueueSecondsDelay?.toTrimmedString());
    _bqMinNumberOfTasksValueController = TextEditingController(
        text: cioConfig?.backgroundQueueMinNumOfTasks?.toString());
    _featureTrackScreens = cioConfig?.screenTrackingEnabled ?? true;
    _featureTrackDeviceAttributes =
        cioConfig?.deviceAttributesTrackingEnabled ?? true;
    _featureDebugMode = cioConfig?.debugModeEnabled ?? true;

    super.initState();
  }

  void _saveSettings() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newConfig = CustomerIOSDKConfig(
      siteId: _siteIDValueController.text.trim(),
      apiKey: _apiKeyValueController.text.trim(),
      trackingUrl: _trackingURLValueController.text.trim(),
      backgroundQueueSecondsDelay:
          _bqSecondsDelayValueController.text.trim().toDoubleOrNull(),
      backgroundQueueMinNumOfTasks:
          _bqMinNumberOfTasksValueController.text.trim().toIntOrNull(),
      screenTrackingEnabled: _featureTrackScreens,
      deviceAttributesTrackingEnabled: _featureTrackDeviceAttributes,
      debugModeEnabled: _featureDebugMode,
    );
    widget._customerIOSDK.saveConfigToPreferences(newConfig).then((success) {
      if (success) {
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
      _siteIDValueController.text = defaultConfig.siteId;
      _apiKeyValueController.text = defaultConfig.apiKey;
      _trackingURLValueController.text = defaultConfig.trackingUrl ?? '';
      _bqSecondsDelayValueController.text =
          defaultConfig.backgroundQueueSecondsDelay?.toTrimmedString() ?? '';
      _bqMinNumberOfTasksValueController.text =
          defaultConfig.backgroundQueueMinNumOfTasks?.toString() ?? '';
      _featureTrackScreens = defaultConfig.screenTrackingEnabled;
      _featureTrackDeviceAttributes =
          defaultConfig.deviceAttributesTrackingEnabled;
      _featureDebugMode = defaultConfig.debugModeEnabled;
      _saveSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Sizes sizes = Theme.of(context).extension<Sizes>()!;

    return WillPopScope(
      onWillPop: () {
        if (widget.auth.signedIn == false) {
          context.go(Screen.login.location);
          return Future.value(false);
        }

        return Future.value(true);
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
                            valueController: _deviceTokenValueController,
                            readOnly: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy),
                              tooltip: 'Copy Token',
                              onPressed: () {
                                final clipboardData = ClipboardData(
                                    text: _deviceTokenValueController.text);
                                Clipboard.setData(clipboardData).then((_) =>
                                    context.showSnackBar(
                                        'Device Token copied to clipboard'));
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextSettingsFormField(
                            labelText: 'CIO Track URL',
                            semanticsLabel: 'Track URL Input',
                            valueController: _trackingURLValueController,
                            validator: (value) => value?.isValidUrl() != false
                                ? null
                                : 'Please enter formatted url e.g. https://tracking.cio/',
                          ),
                          const SizedBox(height: 32),
                          TextSettingsFormField(
                            labelText: 'Site Id',
                            semanticsLabel: 'Site ID Input',
                            valueController: _siteIDValueController,
                            validator: (value) =>
                                value?.trim().isNotEmpty == true
                                    ? null
                                    : 'This field cannot be blank',
                          ),
                          const SizedBox(height: 16),
                          TextSettingsFormField(
                            labelText: 'API Key',
                            semanticsLabel: 'API Key Input',
                            valueController: _apiKeyValueController,
                            validator: (value) =>
                                value?.trim().isNotEmpty == true
                                    ? null
                                    : 'This field cannot be blank',
                          ),
                          const SizedBox(height: 32),
                          TextSettingsFormField(
                            labelText: 'backgroundQueueSecondsDelay',
                            semanticsLabel: 'BQ Seconds Delay Input',
                            valueController: _bqSecondsDelayValueController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              bool isBlank = value?.trim().isNotEmpty != true;
                              if (isBlank) {
                                return 'This field cannot be blank';
                              }

                              double minValue = 1.0;
                              bool isInvalid =
                                  value?.isValidDouble(min: minValue) != true;
                              if (isInvalid) {
                                return 'The value must be greater than or equal to $minValue';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextSettingsFormField(
                            labelText: 'backgroundQueueMinNumberOfTasks',
                            semanticsLabel: 'BQ Min Number of Tasks Input',
                            valueController: _bqMinNumberOfTasksValueController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              bool isBlank = value?.trim().isNotEmpty != true;
                              if (isBlank) {
                                return 'This field cannot be blank';
                              }

                              int minValue = 1;
                              bool isInvalid =
                                  value?.isValidInt(min: minValue) != true;
                              if (isInvalid) {
                                return 'The value must be greater than or equal to $minValue';
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
                onPressed: () => _saveSettings(),
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
