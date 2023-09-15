import 'package:customer_io/customer_io.dart';
import 'package:flutter/material.dart';

import '../components/container.dart';
import '../components/scroll_view.dart';
import '../components/text_field_label.dart';
import '../theme/sizes.dart';
import '../utils/extensions.dart';

class CustomEventScreen extends StatefulWidget {
  const CustomEventScreen({super.key});

  @override
  State<CustomEventScreen> createState() => _CustomEventScreenState();
}

class _CustomEventScreenState extends State<CustomEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _propertyNameController = TextEditingController();
  final _propertyValueController = TextEditingController();

  /// Shows success message and navigates up when event tracking is complete
  void _onEventTracked() {
    context.showSnackBar('Event sent successfully');
  }

  @override
  Widget build(BuildContext context) {
    final Sizes sizes = Theme.of(context).extension<Sizes>()!;

    return AppContainer(
      appBar: AppBar(
        backgroundColor: null,
      ),
      body: FullScreenScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.disabled,
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Send Custom Event',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _eventNameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    label: TextFieldLabel(
                      text: 'Event Name',
                      semanticsLabel: 'Event Name Input',
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _propertyNameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    label: TextFieldLabel(
                      text: 'Property Name',
                      semanticsLabel: 'Property Name Input',
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _propertyValueController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    label: TextFieldLabel(
                      text: 'Property Value',
                      semanticsLabel: 'Property Value Input',
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: sizes.buttonDefault(),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      String propertyName = _propertyNameController.text;
                      Map<String, String> attributes;
                      attributes = propertyName.isEmpty
                          ? {}
                          : {propertyName: _propertyValueController.text};
                      CustomerIO.track(
                          name: _eventNameController.text,
                          attributes: attributes);
                      _onEventTracked();
                    }
                  },
                  child: const Text(
                    'Send Event',
                    semanticsLabel: 'Send Event Button',
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
