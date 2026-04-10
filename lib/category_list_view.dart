import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';
import 'exercise_video_view.dart';
import 'theme.dart';
import 'dart:ui';

class CategoryListView extends StatefulWidget {
  final bool isAdmin;
  final String path;
  final String title;

  const CategoryListView({
    super.key,
    required this.isAdmin,
    this.path = 'workouts',
    this.title = 'Gym Library',
  });

  @override
  State<CategoryListView> createState() => _CategoryListViewState();
}

class _CategoryListViewState extends State<CategoryListView> {
  final _database = FirebaseDatabase.instance.ref();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  void _addItem(bool isVideo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(isVideo ? 'NEW WORKOUT' : 'NEW SUB-CATEGORY', style: const TextStyle(letterSpacing: 1.5, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: isVideo ? 'Workout Name' : 'Folder Name (e.g. Chest)',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            if (isVideo) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Video URL (YouTube)',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                final newItem = {
                  'name': name,
                  'type': isVideo ? 'video' : 'folder',
                  if (isVideo) 'link': _urlController.text.trim(),
                };
                _database.child(widget.path).push().set(newItem);
                _nameController.clear();
                _urlController.clear();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black),
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String itemKey, String itemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('DELETE?', style: TextStyle(letterSpacing: 1.5, fontSize: 16)),
        content: Text('Remove "$itemName" from the library forever?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('KEEP')),
          TextButton(
            onPressed: () {
              _database.child('${widget.path}/$itemKey').remove();
              Navigator.pop(context);
            }, 
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nuclear Option: Force explicit dark brightness for this specific view chain
    return Theme(
      data: SlimFitnessTheme.darkTheme.copyWith(
        useMaterial3: false, // De-tune Material 3 surface tints
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF080808)),
        child: Scaffold(
          backgroundColor: Colors.transparent, // Let DecoratedBox show through
          appBar: widget.path != 'workouts'
              ? AppBar(
                  backgroundColor: const Color(0xFF080808),
                  elevation: 0,
                  title: Text(widget.title.toUpperCase(), style: const TextStyle(fontSize: 14, letterSpacing: 2)),
                )
              : null,
          body: Container(
            color: const Color(0xFF080808),
            child: SafeArea(
              child: StreamBuilder<DatabaseEvent>(
                stream: _database.child(widget.path).onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white24));
                  }

                  final rawData = snapshot.data?.snapshot.value;
                  if (rawData == null || rawData is! Map) {
                    return _buildEmptyState();
                  }

                  final data = rawData as Map<dynamic, dynamic>;
                  // Robust Filtering: Only take keys that are actually item objects (not 'name' or 'type' of the parent folder)
                  final keys = data.keys.where((k) {
                    final v = data[k];
                    return v is Map && v.containsKey('type');
                  }).toList();

                  if (keys.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    itemCount: keys.length,
                    itemBuilder: (context, index) {
                      final key = keys[index];
                      final item = data[key] as Map;
                      final bool isVideo = item['type'] == 'video';

                      return FadeInLeft(
                        duration: Duration(milliseconds: 200 + (index * 50)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            onTap: () {
                              if (isVideo) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseVideoView(exerciseName: item['name'] ?? 'Workout', videoUrl: item['link'] ?? '')));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryListView(isAdmin: widget.isAdmin, path: '${widget.path}/$key', title: item['name'] ?? '')));
                              }
                            },
                            onLongPress: widget.isAdmin ? () => _confirmDelete(key, item['name'] ?? 'Item') : null,
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isVideo ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                isVideo ? Icons.play_circle_fill_rounded : Icons.folder_copy_rounded,
                                color: isVideo ? Theme.of(context).primaryColor : Colors.white60,
                                size: 28,
                              ),
                            ),
                            title: Text(
                              item['name']?.toUpperCase() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: Colors.white),
                            ),
                            subtitle: Text(
                              isVideo ? 'VIDEO ROUTINE' : 'FOLDER',
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          floatingActionButton: widget.isAdmin ? _buildFab(context) : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('NO EXERCISES YET', style: TextStyle(color: Colors.white.withOpacity(0.3), letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Your trainer is adding routines...', style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'add_folder_${widget.path}',
          onPressed: () => _addItem(false),
          backgroundColor: Colors.white12,
          child: const Icon(Icons.create_new_folder_rounded, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'add_video_${widget.path}',
          onPressed: () => _addItem(true),
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.video_call_rounded, color: Colors.black),
        ),
      ],
    );
  }
}
