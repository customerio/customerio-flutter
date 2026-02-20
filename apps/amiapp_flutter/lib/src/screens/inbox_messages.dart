import 'dart:async';

import 'package:customer_io/customer_io.dart';
import 'package:customer_io/messaging_in_app.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/container.dart';

class InboxMessagesScreen extends StatefulWidget {
  const InboxMessagesScreen({super.key});

  @override
  State<InboxMessagesScreen> createState() => _InboxMessagesScreenState();
}

class _InboxMessagesScreenState extends State<InboxMessagesScreen> {
  final _inbox = CustomerIO.inAppMessaging.inbox;
  List<InboxMessage> _messages = [];
  bool _isLoading = false;
  StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _setupInbox();
  }

  void _setupInbox() {
    // Listen to real-time updates
    _messagesSubscription = _inbox.messages().listen((messages) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    });

    // Fetch messages
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _inbox.fetchMessages();
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching messages: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _toggleRead(InboxMessage message) {
    if (message.opened) {
      _inbox.markMessageUnopened(message);
    } else {
      _inbox.markMessageOpened(message);
    }
  }

  void _showTrackClickDialog(InboxMessage message) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Track Click'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter action name (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Action name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final actionName = controller.text.trim();
              if (actionName.isEmpty) {
                _inbox.trackMessageClicked(message);
              } else {
                _inbox.trackMessageClicked(message, actionName: actionName);
              }
              Navigator.of(dialogContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Click tracked successfully')),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(InboxMessage message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _inbox.markMessageDeleted(message);
              Navigator.of(dialogContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppContainer(
      appBar: AppBar(
        title: const Text('Inbox Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMessages,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages in your inbox',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _InboxMessageCard(
          message: message,
          index: index + 1,
          onToggleRead: () => _toggleRead(message),
          onTrackClick: () => _showTrackClickDialog(message),
          onDelete: () => _showDeleteDialog(message),
        );
      },
    );
  }
}

class _InboxMessageCard extends StatelessWidget {
  final InboxMessage message;
  final int index;
  final VoidCallback onToggleRead;
  final VoidCallback onTrackClick;
  final VoidCallback onDelete;

  const _InboxMessageCard({
    required this.message,
    required this.index,
    required this.onToggleRead,
    required this.onTrackClick,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('M/d/yyyy, h:mm:ss a');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: message.opened ? Colors.grey[200] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with index and badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#$index',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // Priority badge (if exists)
                    if (message.priority != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'P${message.priority}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Read/Unread badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: message.opened ? Colors.grey : Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        message.opened ? 'READ' : 'UNREAD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Message details
            Text(
              message.deliveryId ?? message.queueId,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sent: ${dateFormat.format(message.sentAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (message.expiry != null) ...[
              const SizedBox(height: 4),
              Text(
                'Expires: ${dateFormat.format(message.expiry!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],

            // Properties
            if (message.properties.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: message.opened ? Colors.grey[300] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatProperties(message.properties),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],

            // Actions
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onToggleRead,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: Text(
                      message.opened ? 'Unread' : 'Read',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onTrackClick,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text(
                      'Track',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text(
                      'Delete',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatProperties(Map<String, dynamic> properties) {
    final buffer = StringBuffer('{\n');
    properties.forEach((key, value) {
      final formattedValue = value is String ? '"$value"' : value.toString();
      buffer.write('  "$key": $formattedValue,\n');
    });
    buffer.write('}');
    return buffer.toString();
  }
}
