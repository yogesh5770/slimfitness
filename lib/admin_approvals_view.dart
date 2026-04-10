import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class OwnerApprovalsView extends StatefulWidget {
  const OwnerApprovalsView({super.key});

  @override
  State<OwnerApprovalsView> createState() => _OwnerApprovalsViewState();
}

class _OwnerApprovalsViewState extends State<OwnerApprovalsView> {
  final _database = FirebaseDatabase.instance.ref();

  void _approveUser(String uid, String name) async {
    try {
      await _database.child('users/$uid/status').set('approved');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name approved successfully!'),
          backgroundColor: Theme.of(context).primaryColor,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to approve user: $e'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Approvals'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _database.child('users').orderByChild('status').equalTo('pending').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Theme.of(context).primaryColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No pending approvals.', style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }

          final Map<dynamic, dynamic> usersMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final pendingUsers = usersMap.entries.map((e) {
            final user = Map<String, dynamic>.from(e.value as Map);
            user['uid'] = e.key;
            return user;
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingUsers.length,
            itemBuilder: (context, index) {
              final user = pendingUsers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white10,
                      child: Text(
                        user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(user['email'] ?? 'No email', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _approveUser(user['uid'], user['name'] ?? 'User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
