import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<Map<String, String>> _contacts = [
    {'name': 'Dr. Smith', 'number': '+1 555-0123', 'type': 'Doctor'},
    {'name': 'Emergency Services', 'number': '911', 'type': 'Emergency'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
            title: Text(
              'Emergency Contacts',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.add, size: 28),
                color: const Color(0xFF007AFF),
                onPressed: _showAddContactDialog,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'These contacts will be notified immediately when an SOS is triggered. Drag to reorder priority.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverReorderableList(
              itemCount: _contacts.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _contacts.removeAt(oldIndex);
                  _contacts.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                final isLast = index == _contacts.length - 1;
                
                return Container(
                  key: ValueKey(contact['number']),
                  margin: const EdgeInsets.only(bottom: 1),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? const Radius.circular(10) : Radius.zero,
                      bottom: isLast ? const Radius.circular(10) : Radius.zero,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: contact['type'] == 'Emergency' 
                                ? Colors.red.withOpacity(0.1) 
                                : const Color(0xFF007AFF).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            contact['type'] == 'Emergency' ? CupertinoIcons.heart_fill : CupertinoIcons.phone_fill,
                            color: contact['type'] == 'Emergency' ? Colors.red : const Color(0xFF007AFF),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          contact['name']!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          contact['number']!,
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 60,
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    // Implementation remains same
  }
}
