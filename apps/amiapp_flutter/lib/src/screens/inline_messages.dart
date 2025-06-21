import 'package:customer_io/customer_io_widgets.dart';
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top inline message
            _buildInlineMessageSection('inline-top'),
            
            // Skeleton loading content 1
            _buildSkeletonContent(),
            
            // Middle inline message
            _buildInlineMessageSection('inline-middle'),
            
            // Skeleton loading content 2
            _buildSkeletonContent(),
            
            // Bottom inline message
            _buildInlineMessageSection('inline-bottom'),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineMessageSection(String elementId) {
    return Builder(
      builder: (context) {
        return InlineInAppMessageView(
          elementId: elementId,
          onAction: (actionValue, actionName, {messageId, deliveryId}) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Action: $actionName, Value: $actionValue'
                  '${messageId != null ? ', Message ID: $messageId' : ''}'
                  '${deliveryId != null ? ', Delivery ID: $deliveryId' : ''}',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left skeleton block
        Expanded(
          flex: 2,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right skeleton content
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top skeleton bars
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 16,
                width: double.infinity * 0.7,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              // Bottom skeleton block
              AspectRatio(
                aspectRatio: 1.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}