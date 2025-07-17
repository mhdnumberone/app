// lib/screens/camouflage/fake_apps/notes_app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/themes/app_themes.dart';
import '../../../core/themes/app_theme_extension.dart';
import '../../../core/managers/settings_manager.dart';
import '../../auth/login_screen.dart';

class NotesApp extends StatefulWidget {
  const NotesApp({super.key});

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  List<Note> _notes = [
    Note(
      id: '1',
      title: 'قائمة التسوق',
      content: 'حليب\nخبز\nبيض\nفواكه\nخضروات',
      lastModified: DateTime.now().subtract(const Duration(hours: 2)),
      color: Colors.yellow[100]!,
    ),
    Note(
      id: '2',
      title: 'اجتماع المشروع',
      content: 'مناقشة خطة المشروع الجديد\nالموعد: الثلاثاء 2:00 م\nالمكان: قاعة الاجتماعات',
      lastModified: DateTime.now().subtract(const Duration(days: 1)),
      color: Colors.blue[100]!,
    ),
    Note(
      id: '3',
      title: 'أفكار التطبيق',
      content: 'ميزة جديدة: تذكير بالمهام\nتحسين واجهة المستخدم\nإضافة الوضع الليلي',
      lastModified: DateTime.now().subtract(const Duration(days: 3)),
      color: Colors.green[100]!,
    ),
  ];

  int _secretTapCount = 0;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    List<Note> filteredNotes = _notes.where((note) {
      return note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             note.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green[600],
        elevation: 0,
        title: const Text(
          'المذكرات',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showSearch,
            icon: const Icon(Icons.search, color: Colors.white),
          ),
          IconButton(
            onPressed: _showMenu,
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty) _buildSearchBar(),
          Expanded(
            child: filteredNotes.isEmpty
                ? _buildEmptyState()
                : _buildNotesList(filteredNotes),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewNote,
        backgroundColor: Colors.green[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.green[50],
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'البحث في المذكرات...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.clear),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد مذكرات',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'جرب كلمات مختلفة للبحث'
                : 'اضغط على + لإضافة مذكرة جديدة',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildNoteCard(note);
      },
    );
  }

  Widget _buildNoteCard(Note note) {
    return GestureDetector(
      onTap: () => _openNote(note),
      onDoubleTap: () => _accessRealApp(),
      onLongPress: () => _showNoteOptions(note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: note.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.push_pin_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _formatDate(note.lastModified),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearch() {
    setState(() {
      _searchQuery = _searchQuery.isEmpty ? ' ' : '';
    });
  }

  void _showMenu() {
    _secretTapCount++;
    if (_secretTapCount >= 5) {
      _accessRealApp();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.green),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                _showSettings();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.green),
              title: const Text('الأرشيف'),
              onTap: () {
                Navigator.pop(context);
                _showArchive();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.green),
              title: const Text('النسخ الاحتياطي'),
              onTap: () {
                Navigator.pop(context);
                _showBackup();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.green),
              title: const Text('حول التطبيق'),
              onTap: () {
                Navigator.pop(context);
                _showAbout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openNote(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          note: note,
          onSave: (updatedNote) {
            setState(() {
              int index = _notes.indexWhere((n) => n.id == note.id);
              if (index != -1) {
                _notes[index] = updatedNote;
              }
            });
          },
        ),
      ),
    );
  }

  void _addNewNote() {
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'مذكرة جديدة',
      content: '',
      lastModified: DateTime.now(),
      color: Colors.yellow[100]!,
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          note: newNote,
          onSave: (savedNote) {
            setState(() {
              _notes.insert(0, savedNote);
            });
          },
        ),
      ),
    );
  }

  void _showNoteOptions(Note note) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.pop(context);
                _openNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('مشاركة'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteNote(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNote(Note note) {
    setState(() {
      _notes.removeWhere((n) => n.id == note.id);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم حذف المذكرة'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            setState(() {
              _notes.add(note);
            });
          },
        ),
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات المذكرات'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.palette),
              title: Text('لون المذكرات الافتراضي'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: Icon(Icons.text_fields),
              title: Text('حجم الخط'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showArchive() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الأرشيف'),
        content: const Text('لا توجد مذكرات مؤرشفة'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showBackup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('النسخ الاحتياطي'),
        content: const Text('سيتم إضافة النسخ الاحتياطي قريباً'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول تطبيق المذكرات'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار: 1.5.2'),
            SizedBox(height: 8),
            Text('تطبيق بسيط لحفظ المذكرات والأفكار'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'اليوم ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _accessRealApp() {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime lastModified;
  final Color color;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.lastModified,
    required this.color,
  });

  Note copyWith({
    String? title,
    String? content,
    DateTime? lastModified,
    Color? color,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      lastModified: lastModified ?? this.lastModified,
      color: color ?? this.color,
    );
  }
}

class NoteDetailScreen extends StatefulWidget {
  final Note note;
  final Function(Note) onSave;

  const NoteDetailScreen({
    super.key,
    required this.note,
    required this.onSave,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    
    _titleController.addListener(_markAsChanged);
    _contentController.addListener(_markAsChanged);
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.note.color,
      appBar: AppBar(
        backgroundColor: widget.note.color,
        elevation: 0,
        leading: IconButton(
          onPressed: _saveAndExit,
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        actions: [
          IconButton(
            onPressed: _shareNote,
            icon: const Icon(Icons.share, color: Colors.black87),
          ),
          IconButton(
            onPressed: _showNoteMenu,
            icon: const Icon(Icons.more_vert, color: Colors.black87),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              decoration: const InputDecoration(
                hintText: 'العنوان',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.black54),
              ),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  hintText: 'اكتب مذكرتك هنا...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAndExit() {
    if (_hasChanges) {
      final updatedNote = widget.note.copyWith(
        title: _titleController.text.trim().isEmpty 
            ? 'مذكرة بدون عنوان' 
            : _titleController.text.trim(),
        content: _contentController.text,
        lastModified: DateTime.now(),
      );
      widget.onSave(updatedNote);
    }
    Navigator.pop(context);
  }

  void _shareNote() {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ميزة المشاركة ستتوفر قريباً')),
    );
  }

  void _showNoteMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('تغيير اللون'),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ النص'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: _contentController.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ النص')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    final colors = [
      Colors.yellow[100]!,
      Colors.blue[100]!,
      Colors.green[100]!,
      Colors.pink[100]!,
      Colors.orange[100]!,
      Colors.purple[100]!,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر لوناً'),
        content: Wrap(
          spacing: 8,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  // Update note color
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}