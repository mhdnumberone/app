// lib/screens/camouflage/fake_apps/todo_app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/themes/app_themes.dart';
import '../../../core/themes/app_theme_extension.dart';
import '../../../core/managers/settings_manager.dart';
import '../../auth/login_screen.dart';

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  List<TodoItem> _todos = [
    TodoItem(
      id: '1',
      title: 'شراء الحليب والخبز',
      description: 'من السوبر ماركت القريب',
      isCompleted: false,
      priority: TodoPriority.high,
      dueDate: DateTime.now().add(const Duration(hours: 3)),
      category: 'تسوق',
    ),
    TodoItem(
      id: '2',
      title: 'موعد الطبيب',
      description: 'فحص دوري في الساعة 3:00 م',
      isCompleted: false,
      priority: TodoPriority.high,
      dueDate: DateTime.now().add(const Duration(days: 1)),
      category: 'صحة',
    ),
    TodoItem(
      id: '3',
      title: 'تنظيف المنزل',
      description: 'تنظيف شامل لغرفة المعيشة والمطبخ',
      isCompleted: true,
      priority: TodoPriority.medium,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      category: 'منزل',
    ),
    TodoItem(
      id: '4',
      title: 'إنهاء تقرير العمل',
      description: 'المراجعة النهائية وإرسال التقرير للمدير',
      isCompleted: false,
      priority: TodoPriority.high,
      dueDate: DateTime.now().add(const Duration(days: 2)),
      category: 'عمل',
    ),
    TodoItem(
      id: '5',
      title: 'قراءة كتاب',
      description: 'إنهاء الفصل الثالث من كتاب التطوير الذاتي',
      isCompleted: false,
      priority: TodoPriority.low,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      category: 'تعلم',
    ),
  ];

  int _secretTapCount = 0;
  String _selectedCategory = 'الكل';
  TodoFilter _currentFilter = TodoFilter.all;

  final List<String> _categories = [
    'الكل', 'عمل', 'منزل', 'صحة', 'تسوق', 'تعلم', 'ترفيه'
  ];

  @override
  Widget build(BuildContext context) {
    List<TodoItem> filteredTodos = _getFilteredTodos();

    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        backgroundColor: Colors.purple[600],
        elevation: 0,
        title: const Text(
          'قائمة المهام',
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
          _buildFilterTabs(),
          _buildCategoryFilter(),
          _buildStats(),
          Expanded(
            child: filteredTodos.isEmpty
                ? _buildEmptyState()
                : _buildTodoList(filteredTodos),
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () => _accessRealApp(),
        child: FloatingActionButton(
          onPressed: _addNewTodo,
          backgroundColor: Colors.purple[600],
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      color: Colors.purple[600],
      child: Row(
        children: [
          _buildFilterTab('الكل', TodoFilter.all),
          _buildFilterTab('النشطة', TodoFilter.active),
          _buildFilterTab('المكتملة', TodoFilter.completed),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String title, TodoFilter filter) {
    final isSelected = _currentFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentFilter = filter;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple[600] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.purple[600]!,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.purple[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats() {
    final totalTodos = _todos.length;
    final completedTodos = _todos.where((todo) => todo.isCompleted).length;
    final progress = totalTodos > 0 ? completedTodos / totalTodos : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'التقدم اليومي',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '$completedTodos/$totalTodos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[600]!),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% مكتمل',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مهام',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على + لإضافة مهمة جديدة',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList(List<TodoItem> todos) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return _buildTodoCard(todo);
      },
    );
  }

  Widget _buildTodoCard(TodoItem todo) {
    return GestureDetector(
      onTap: () => _editTodo(todo),
      onLongPress: () => _showTodoOptions(todo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getPriorityColor(todo.priority).withOpacity(0.3),
            width: 2,
          ),
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
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggleTodoCompletion(todo),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: todo.isCompleted 
                          ? Colors.green 
                          : _getPriorityColor(todo.priority),
                      width: 2,
                    ),
                    color: todo.isCompleted ? Colors.green : Colors.transparent,
                  ),
                  child: todo.isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            todo.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: todo.isCompleted ? Colors.grey : Colors.black87,
                              decoration: todo.isCompleted 
                                  ? TextDecoration.lineThrough 
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(todo.priority).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getPriorityText(todo.priority),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getPriorityColor(todo.priority),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (todo.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        todo.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: todo.isCompleted ? Colors.grey : Colors.grey[600],
                          decoration: todo.isCompleted 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(todo.dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            todo.category,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.purple[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleTodoCompletion(TodoItem todo) {
    setState(() {
      todo.isCompleted = !todo.isCompleted;
    });
    
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          todo.isCompleted ? 'تم إكمال المهمة' : 'تم إلغاء إكمال المهمة',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _addNewTodo() {
    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'مهمة جديدة',
      description: '',
      isCompleted: false,
      priority: TodoPriority.medium,
      dueDate: DateTime.now().add(const Duration(days: 1)),
      category: 'عمل',
    );
    
    _editTodo(newTodo, isNew: true);
  }

  void _editTodo(TodoItem todo, {bool isNew = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoEditDialog(
        todo: todo,
        categories: _categories.where((c) => c != 'الكل').toList(),
        onSave: (editedTodo) {
          setState(() {
            if (isNew) {
              _todos.insert(0, editedTodo);
            } else {
              int index = _todos.indexWhere((t) => t.id == todo.id);
              if (index != -1) {
                _todos[index] = editedTodo;
              }
            }
          });
        },
      ),
    );
  }

  void _showTodoOptions(TodoItem todo) {
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
                _editTodo(todo);
              },
            ),
            ListTile(
              leading: Icon(
                todo.isCompleted ? Icons.undo : Icons.check,
                color: todo.isCompleted ? Colors.orange : Colors.green,
              ),
              title: Text(todo.isCompleted ? 'إلغاء الإكمال' : 'تم الإكمال'),
              onTap: () {
                Navigator.pop(context);
                _toggleTodoCompletion(todo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteTodo(todo);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTodo(TodoItem todo) {
    setState(() {
      _todos.removeWhere((t) => t.id == todo.id);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم حذف المهمة'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            setState(() {
              _todos.add(todo);
            });
          },
        ),
      ),
    );
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: TodoSearchDelegate(_todos),
    );
  }

  void _showMenu() {
    _secretTapCount++;
    if (_secretTapCount >= 7) {
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
              leading: const Icon(Icons.settings, color: Colors.purple),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                _showSettings();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.purple),
              title: const Text('النسخ الاحتياطي'),
              onTap: () {
                Navigator.pop(context);
                _showBackup();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.purple),
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

  List<TodoItem> _getFilteredTodos() {
    List<TodoItem> filtered = _todos;
    
    // Filter by completion status
    switch (_currentFilter) {
      case TodoFilter.active:
        filtered = filtered.where((todo) => !todo.isCompleted).toList();
        break;
      case TodoFilter.completed:
        filtered = filtered.where((todo) => todo.isCompleted).toList();
        break;
      case TodoFilter.all:
        break;
    }
    
    // Filter by category
    if (_selectedCategory != 'الكل') {
      filtered = filtered.where((todo) => todo.category == _selectedCategory).toList();
    }
    
    return filtered;
  }

  Color _getPriorityColor(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return Colors.red;
      case TodoPriority.medium:
        return Colors.orange;
      case TodoPriority.low:
        return Colors.green;
    }
  }

  String _getPriorityText(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return 'عالي';
      case TodoPriority.medium:
        return 'متوسط';
      case TodoPriority.low:
        return 'منخفض';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'غداً';
    } else if (difference.inDays == -1) {
      return 'أمس';
    } else if (difference.inDays > 1) {
      return 'خلال ${difference.inDays} أيام';
    } else {
      return 'منذ ${-difference.inDays} أيام';
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات قائمة المهام'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('التذكيرات'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: Icon(Icons.palette),
              title: Text('المظهر'),
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
        title: const Text('حول تطبيق قائمة المهام'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار: 2.8.5'),
            SizedBox(height: 8),
            Text('تطبيق لإدارة المهام اليومية والتذكيرات'),
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

  void _accessRealApp() {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}

enum TodoPriority { high, medium, low }
enum TodoFilter { all, active, completed }

class TodoItem {
  final String id;
  String title;
  String description;
  bool isCompleted;
  TodoPriority priority;
  DateTime dueDate;
  String category;

  TodoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.priority,
    required this.dueDate,
    required this.category,
  });
}

class TodoEditDialog extends StatefulWidget {
  final TodoItem todo;
  final List<String> categories;
  final Function(TodoItem) onSave;

  const TodoEditDialog({
    super.key,
    required this.todo,
    required this.categories,
    required this.onSave,
  });

  @override
  State<TodoEditDialog> createState() => _TodoEditDialogState();
}

class _TodoEditDialogState extends State<TodoEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TodoPriority _selectedPriority;
  late DateTime _selectedDate;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(text: widget.todo.description);
    _selectedPriority = widget.todo.priority;
    _selectedDate = widget.todo.dueDate;
    _selectedCategory = widget.todo.category;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تعديل المهمة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان المهمة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'الفئة',
                border: OutlineInputBorder(),
              ),
              items: widget.categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TodoPriority>(
              value: _selectedPriority,
              decoration: const InputDecoration(
                labelText: 'الأولوية',
                border: OutlineInputBorder(),
              ),
              items: TodoPriority.values.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text(_getPriorityText(priority)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPriority = value;
                  });
                }
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTodo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTodo() {
    final editedTodo = TodoItem(
      id: widget.todo.id,
      title: _titleController.text.trim().isEmpty 
          ? 'مهمة بدون عنوان' 
          : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      isCompleted: widget.todo.isCompleted,
      priority: _selectedPriority,
      dueDate: _selectedDate,
      category: _selectedCategory,
    );
    
    widget.onSave(editedTodo);
    Navigator.pop(context);
  }

  String _getPriorityText(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.high:
        return 'عالي';
      case TodoPriority.medium:
        return 'متوسط';
      case TodoPriority.low:
        return 'منخفض';
    }
  }
}

class TodoSearchDelegate extends SearchDelegate<TodoItem?> {
  final List<TodoItem> todos;

  TodoSearchDelegate(this.todos);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = todos.where((todo) {
      return todo.title.toLowerCase().contains(query.toLowerCase()) ||
             todo.description.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final todo = results[index];
        return ListTile(
          title: Text(todo.title),
          subtitle: Text(todo.description),
          onTap: () {
            close(context, todo);
          },
        );
      },
    );
  }
}