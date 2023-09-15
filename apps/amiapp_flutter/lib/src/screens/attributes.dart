import 'package:customer_io/customer_io.dart';
import 'package:flutter/material.dart';

import '../components/container.dart';
import '../components/scroll_view.dart';
import '../components/text_field_label.dart';
import '../theme/sizes.dart';
import '../utils/extensions.dart';

const _attributeTypeDevice = 'ATTRIBUTE_TYPE_DEVICE';
const _attributeTypeProfile = 'ATTRIBUTE_TYPE_PROFILE';

class AttributesScreen extends StatefulWidget {
  final String _attributeType;

  const AttributesScreen._internal(this._attributeType, {super.key});

  factory AttributesScreen.device({Key? key}) => AttributesScreen._internal(
        _attributeTypeDevice,
        key: key,
      );

  factory AttributesScreen.profile({Key? key}) => AttributesScreen._internal(
        _attributeTypeProfile,
        key: key,
      );

  String get attributeName {
    switch (_attributeType) {
      case _attributeTypeDevice:
        return 'Device';
      case _attributeTypeProfile:
        return 'Profile';
      default:
        throw ArgumentError('Invalid attribute type specified');
    }
  }

  String get screenTitle {
    switch (_attributeType) {
      case _attributeTypeDevice:
        return 'Set Custom Device Attribute';
      case _attributeTypeProfile:
        return 'Set Custom Profile Attribute';
      default:
        throw ArgumentError('Invalid attribute type specified');
    }
  }

  String get sendAttributeButtonText {
    switch (_attributeType) {
      case _attributeTypeDevice:
        return 'Send device attributes';
      case _attributeTypeProfile:
        return 'Send profile attributes';
      default:
        throw ArgumentError('Invalid attribute type specified');
    }
  }

  String get sendAttributeButtonSemanticsLabel {
    switch (_attributeType) {
      case _attributeTypeDevice:
        return 'Set Device Attribute Button';
      case _attributeTypeProfile:
        return 'Set Profile Attribute Button';
      default:
        throw ArgumentError('Invalid attribute type specified');
    }
  }

  @override
  State<AttributesScreen> createState() => _AttributesScreenState();
}

class _AttributesScreenState extends State<AttributesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _attributeNameController = TextEditingController();
  final _attributeValueController = TextEditingController();

  /// Shows success message and navigates up when event tracking is complete
  void _onEventTracked() {
    context
        .showSnackBar('${widget.attributeName} attribute sent successfully!');
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
                    widget.screenTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _attributeNameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    label: TextFieldLabel(
                      text: 'Attribute Name',
                      semanticsLabel: 'Attribute Name Input',
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _attributeValueController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    label: TextFieldLabel(
                      text: 'Attribute Value',
                      semanticsLabel: 'Attribute Value Input',
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: sizes.buttonDefault(),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      var attributes = {
                        _attributeNameController.text:
                            _attributeValueController.text,
                      };
                      switch (widget._attributeType) {
                        case _attributeTypeDevice:
                          CustomerIO.setDeviceAttributes(
                              attributes: attributes);
                          break;
                        case _attributeTypeProfile:
                          CustomerIO.setProfileAttributes(
                              attributes: attributes);
                          break;
                      }
                      _onEventTracked();
                    }
                  },
                  child: Text(
                    widget.sendAttributeButtonText,
                    semanticsLabel: widget.sendAttributeButtonSemanticsLabel,
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
