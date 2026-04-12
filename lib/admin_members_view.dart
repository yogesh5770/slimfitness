import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';
import 'weight_chart_view.dart';
import 'streak_service.dart';

class AdminMembersView extends StatefulWidget {
  const AdminMembersView({super.key});

  @override
  State<AdminMembersView> createState() => _AdminMembersViewState();
}

class _AdminMembersViewState extends State<AdminMembersView> {
  final _database = FirebaseDatabase.instance.ref();

  Future<List<Map<String, dynamic>>> _getAllLibraryWorkouts() async {
    final snapshot = await _database.child('workouts').get();
    List<Map<String, dynamic>> workouts = [];
    if (snapshot.exists) {
      _extractWorkouts(snapshot.value as Map, workouts);
    }
    return workouts;
  }

  void _extractWorkouts(Map data, List<Map<String, dynamic>> list) {
    data.forEach((key, value) {
      if (value is Map) {
        if (value['type'] == 'video' && value['link'] != null) {
          list.add({
            'name': value['name'] ?? 'Untitled',
            'link': value['link'],
          });
        }
        _extractWorkouts(value, list);
      }
    });
  }

  void _showAssignDiet(String uid, String memberName) {
    final dietController = TextEditingController();
    
    // Fetch current diet to preload
    _database.child('users/$uid/assigned_diet').get().then((snap) {
      if (snap.exists) {
        dietController.text = (snap.value as Map)['plan'] ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('DIET FOR ${memberName.toUpperCase()}', style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter daily diet instructions, macro targets, or meal timings.', style: TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 16),
            TextField(
              controller: dietController,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g., Morning: 4 Egg Whites...\nLunch: 100g Chicken...',
                hintStyle: const TextStyle(color: Colors.white12),
                filled: true, fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), // Emerald Green for diet
            onPressed: () async {
              await _database.child('users/$uid/assigned_diet').set({
                'plan': dietController.text.trim(),
                'updatedAt': ServerValue.timestamp,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('PUSH DIET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddPersonalWorkout(String uid, String memberEmail) {
    final titleController = TextEditingController();
    final linkController = TextEditingController();
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final minsController = TextEditingController();
    bool isTimed = false;

    void _pickFromLibrary(Function(String, String) onPick) async {
      final workouts = await _getAllLibraryWorkouts();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('SELECT FROM LIBRARY', style: TextStyle(letterSpacing: 1.5, fontSize: 14)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: workouts.length,
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.play_circle_fill, color: Color(0xFF8B5CF6)),
                title: Text(workouts[index]['name'], style: const TextStyle(fontSize: 13)),
                onTap: () {
                  onPick(workouts[index]['name'], workouts[index]['link']);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161B22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Assign to ${memberEmail.split('@')[0]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildPopupField(titleController, 'Workout Name', Icons.fitness_center)),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _pickFromLibrary((n, l) {
                            setState(() {
                              titleController.text = n;
                              linkController.text = l;
                            });
                          }),
                          icon: const Icon(Icons.library_books, color: Color(0xFF8B5CF6)),
                          tooltip: 'Pick from Library',
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPopupField(linkController, 'YouTube URL', Icons.link),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isTimed ? 'TIMED' : 'REPS', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        Switch(
                          value: isTimed,
                          onChanged: (val) => setState(() => isTimed = val),
                          activeColor: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                    if (isTimed)
                      _buildPopupField(minsController, 'Duration (Mins)', Icons.timer)
                    else
                      Row(
                        children: [
                          Expanded(child: _buildPopupField(setsController, 'Sets', Icons.repeat)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildPopupField(repsController, 'Reps', Icons.numbers)),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  onPressed: () async {
                    if (titleController.text.isNotEmpty && linkController.text.isNotEmpty) {
                      await _database.child('assigned_workouts/$uid').push().set({
                        'name': titleController.text.trim(),
                        'link': linkController.text.trim(),
                        'isTimed': isTimed,
                        'sets': setsController.text.trim(),
                        'reps': repsController.text.trim(),
                        'minutes': minsController.text.trim(),
                        'status': 'pending',
                        'timestamp': ServerValue.timestamp,
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Assign', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildPopupField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white24, size: 18),
        filled: true, fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  void _viewAssignedWorkouts(String uid, String memberEmail) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0C10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<DatabaseEvent>(
              stream: _database.child('assigned_workouts/$uid').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const Center(child: Text('No workouts assigned.', style: TextStyle(color: Colors.white24)));
                }
                final Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final items = data.entries.toList();

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10))),
                    const Padding(padding: EdgeInsets.all(24), child: Text('Track Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index].value as Map;
                          final status = item['status'] as String? ?? 'pending';
                          final isDone = status == 'done';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(isDone ? Icons.check_circle_rounded : Icons.pending_actions_rounded, color: isDone ? const Color(0xFF8B5CF6) : Colors.white24),
                              title: Text(item['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.white38 : Colors.white)),
                              subtitle: Text(status.toUpperCase(), style: TextStyle(color: isDone ? const Color(0xFF8B5CF6) : Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _database.child('assigned_workouts/$uid/${items[index].key}').remove()),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MEMBERS HUB')),
      body: StreamBuilder<DatabaseEvent>(
        stream: _database.child('users').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const Center(child: Text('No members found.'));

          final Map<dynamic, dynamic> users = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final approvedMembers = users.entries.where((e) => (e.value as Map)['status'] == 'approved').toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: approvedMembers.length,
            itemBuilder: (context, index) {
              final uid = approvedMembers[index].key as String;
              final data = approvedMembers[index].value as Map;
              final email = data['email'] as String? ?? 'member@fitness.com';
              final name = data['name'] as String? ?? email.split('@')[0].toUpperCase();
              final firstChar = name[0].toUpperCase();

              return FadeInLeft(
                duration: Duration(milliseconds: 400 + (index * 100)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.03))),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(backgroundColor: Colors.black26, child: Text(firstChar, style: TextStyle(color: Theme.of(context).primaryColor))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 14)),
                                Text(email, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(Icons.show_chart, Colors.cyanAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WeightChartView(userId: uid)))),
                          _buildActionButton(Icons.restaurant_menu_rounded, const Color(0xFF10B981), () => _showAssignDiet(uid, name)),
                          _buildActionButton(Icons.insights_rounded, const Color(0xFF8B5CF6), () => _viewAssignedWorkouts(uid, name)),
                          _buildActionButton(Icons.add_task_rounded, Colors.white24, () => _showAddPersonalWorkout(uid, name)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)));
  }
}
