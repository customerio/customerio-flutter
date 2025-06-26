import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_widgets.dart';
import 'package:customer_io/messaging_in_app/inline_in_app_message_view.dart';
import 'package:flutter/material.dart';

import '../components/container.dart';

class InlineMessagesScreen extends StatelessWidget {
  const InlineMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppContainer(
      appBar: AppBar(
        title: const Text('Inline Message Test'),
      ),
      body: Column(
        children: [
          // Sticky Header Inline Message
          InlineInAppMessageView(
            elementId: 'sticky-header',
            onActionClick: _showInlineActionClick,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildImageAndTextBlock(),
                  _buildFullWidthCard(),
                  _buildThreeColumnRow(),
                  InlineInAppMessageView(
                    elementId: 'inline',
                    onActionClick: _showInlineActionClick,
                  ),
                  _buildImageAndTextBlock(),
                  _buildFullWidthCard(),
                  _buildThreeColumnRow(),
                  InlineInAppMessageView(
                    elementId: 'below-fold',
                    onActionClick: _showInlineActionClick,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInlineActionClick(
      InAppMessage message, String actionValue, String actionName) {
    debugPrint(
        'Inline message action clicked: $actionName with value: $actionValue');

    CustomerIO.instance.track(
      name: 'Inline Message Action Clicked',
      properties: {
        'action_name': actionName,
        'action_value': actionValue,
        'message_id': message.messageId,
        'delivery_id': message.deliveryId ?? 'NULL',
      },
    );
  }

  Widget _buildImageAndTextBlock() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AspectRatio(
        aspectRatio: 10 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildThreeColumnRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
