// Optimized Chat Widgets to Prevent Unnecessary Rebuilds
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../core/state/chat_state_manager.dart';
import '../core/themes/app_theme_extension.dart';

// Optimized Message List with Proper Keys and Minimal Rebuilds
class OptimizedMessageList extends StatefulWidget {
  final ChatStateManager stateManager;
  
  const OptimizedMessageList({
    super.key,
    required this.stateManager,
  });

  @override
  State<OptimizedMessageList> createState() => _OptimizedMessageListState();
}

class _OptimizedMessageListState extends State<OptimizedMessageList> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    widget.stateManager.addListener(_onMessagesChanged);
  }
  
  @override
  void dispose() {
    widget.stateManager.removeListener(_onMessagesChanged);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onMessagesChanged() {
    // Auto-scroll to bottom when new messages arrive
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.stateManager,
      builder: (context, child) {
        final messages = widget.stateManager.allMessages;
        
        if (messages.isEmpty) {
          return const Center(
            child: Text('No messages yet'),
          );
        }
        
        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isPending = widget.stateManager.pendingMessages.contains(message);
            final isFailed = widget.stateManager.failedMessages.contains(message);
            
            return OptimizedMessageBubble(
              key: ValueKey(message.id), // Critical for performance
              message: message,
              isPending: isPending,
              isFailed: isFailed,
              uploadProgress: widget.stateManager.uploadProgress[message.id],
              onRetry: isFailed ? () => widget.stateManager.retryMessage(message) : null,
            );
          },
        );
      },
    );
  }
}

// Optimized Message Bubble with Minimal Rebuilds
class OptimizedMessageBubble extends StatelessWidget {
  final Message message;
  final bool isPending;
  final bool isFailed;
  final double? uploadProgress;
  final VoidCallback? onRetry;
  
  const OptimizedMessageBubble({
    super.key,
    required this.message,
    required this.isPending,
    required this.isFailed,
    this.uploadProgress,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    final colors = context.appTheme;
    final isMe = message.fromId == APIs.me!.id;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(),
          if (!isMe) const SizedBox(width: 8),
          _buildMessageContainer(context, colors, isMe),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }
  
  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 12,
      backgroundColor: Colors.grey[300],
      child: Text(
        message.fromId.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
  
  Widget _buildMessageContainer(BuildContext context, ColorScheme colors, bool isMe) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isFailed ? Border.all(color: colors.error, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessageContent(context),
          if (uploadProgress != null) _buildUploadProgress(),
          const SizedBox(height: 4),
          _buildMessageInfo(context, colors, isMe),
        ],
      ),
    );
  }
  
  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case Type.text:
        return SelectableText(
          message.msg,
          style: TextStyle(
            color: message.fromId == APIs.me!.id ? Colors.white : Colors.black,
          ),
        );
      case Type.image:
        return _buildImageMessage();
      case Type.video:
        return _buildVideoMessage();
      case Type.file:
        return _buildFileMessage();
      default:
        return Text(message.msg);
    }
  }
  
  Widget _buildImageMessage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        message.msg,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            child: const Center(
              child: Icon(Icons.error),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildVideoMessage() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_fill,
          size: 64,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildFileMessage() {
    return Row(
      children: [
        const Icon(Icons.attach_file),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message.msg.split('/').last,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: () {
            // Handle file download
          },
        ),
      ],
    );
  }
  
  Widget _buildUploadProgress() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          LinearProgressIndicator(value: uploadProgress),
          const SizedBox(height: 4),
          Text(
            '${((uploadProgress ?? 0) * 100).toInt()}%',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageInfo(BuildContext context, ColorScheme colors, bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.sent),
          style: TextStyle(
            fontSize: 12,
            color: isMe ? Colors.white70 : Colors.grey[600],
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _buildMessageStatus(colors),
        ],
        if (isFailed) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Icon(
              Icons.refresh,
              size: 16,
              color: colors.error,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildMessageStatus(ColorScheme colors) {
    IconData icon;
    Color color;
    
    if (isPending) {
      icon = Icons.access_time;
      color = Colors.white70;
    } else if (isFailed) {
      icon = Icons.error;
      color = colors.error;
    } else if (message.read.isNotEmpty) {
      icon = Icons.done_all;
      color = Colors.blue;
    } else {
      icon = Icons.done;
      color = Colors.white70;
    }
    
    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }
  
  String _formatTime(String timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
    return "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}

// Optimized Input Area with Separate State Management
class OptimizedInputArea extends StatefulWidget {
  final ChatStateManager stateManager;
  final ChatUIStateManager uiStateManager;
  
  const OptimizedInputArea({
    super.key,
    required this.stateManager,
    required this.uiStateManager,
  });

  @override
  State<OptimizedInputArea> createState() => _OptimizedInputAreaState();
}

class _OptimizedInputAreaState extends State<OptimizedInputArea> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }
  
  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      widget.uiStateManager.hideEmoji();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildMainInputRow(),
          _buildEmojiPicker(),
        ],
      ),
    );
  }
  
  Widget _buildMainInputRow() {
    return Row(
      children: [
        _buildAttachmentButton(),
        const SizedBox(width: 8),
        _buildTextInput(),
        const SizedBox(width: 8),
        _buildSendButton(),
      ],
    );
  }
  
  Widget _buildAttachmentButton() {
    return IconButton(
      icon: const Icon(Icons.attach_file),
      onPressed: () => _showAttachmentOptions(),
    );
  }
  
  Widget _buildTextInput() {
    return Expanded(
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Type a message...',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.emoji_emotions),
            onPressed: () => widget.uiStateManager.toggleEmoji(),
          ),
        ),
        onChanged: (text) {
          // Only rebuild send button, not entire input area
          setState(() {});
        },
        onSubmitted: (text) => _sendMessage(),
      ),
    );
  }
  
  Widget _buildSendButton() {
    return ListenableBuilder(
      listenable: widget.uiStateManager,
      builder: (context, child) {
        final isEmpty = _textController.text.trim().isEmpty;
        final isRecording = widget.uiStateManager.isRecording;
        
        return IconButton(
          icon: Icon(
            isEmpty ? Icons.mic : Icons.send,
            color: isRecording ? Colors.red : null,
          ),
          onPressed: isEmpty ? _startRecording : _sendMessage,
        );
      },
    );
  }
  
  Widget _buildEmojiPicker() {
    return ListenableBuilder(
      listenable: widget.uiStateManager,
      builder: (context, child) {
        if (!widget.uiStateManager.showEmoji) {
          return const SizedBox.shrink();
        }
        
        return SizedBox(
          height: 250,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              _textController.text += emoji.emoji;
              setState(() {});
            },
          ),
        );
      },
    );
  }
  
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      _textController.clear();
      widget.stateManager.sendMessage(text);
      widget.uiStateManager.hideEmoji();
    }
  }
  
  void _startRecording() {
    widget.uiStateManager.startRecording();
    // TODO: Implement voice recording
  }
  
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AttachmentOptionsSheet(
        stateManager: widget.stateManager,
      ),
    );
  }
}

// Attachment Options Sheet that doesn't rebuild main chat
class AttachmentOptionsSheet extends StatelessWidget {
  final ChatStateManager stateManager;
  
  const AttachmentOptionsSheet({
    super.key,
    required this.stateManager,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAttachmentOption(
            icon: Icons.photo,
            label: 'Photo',
            onTap: () => _pickImage(context),
          ),
          _buildAttachmentOption(
            icon: Icons.videocam,
            label: 'Video',
            onTap: () => _pickVideo(context),
          ),
          _buildAttachmentOption(
            icon: Icons.attach_file,
            label: 'File',
            onTap: () => _pickFile(context),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
  
  void _pickImage(BuildContext context) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      stateManager.sendFile(image.path, Type.image);
    }
  }
  
  void _pickVideo(BuildContext context) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      stateManager.sendFile(video.path, Type.video);
    }
  }
  
  void _pickFile(BuildContext context) async {
    Navigator.pop(context);
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      stateManager.sendFile(result.files.first.path!, Type.file);
    }
  }
}

// Optimized App Bar that doesn't rebuild unnecessarily
class OptimizedChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ChatUser user;
  
  const OptimizedChatAppBar({
    super.key,
    required this.user,
  });
  
  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: user.image.isNotEmpty 
                ? NetworkImage(user.image)
                : null,
            child: user.image.isEmpty 
                ? Text(user.name.substring(0, 1).toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  user.isOnline ? 'Online' : 'Last seen recently',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () {
            // Handle video call
          },
        ),
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: () {
            // Handle voice call
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // Handle more options
          },
        ),
      ],
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Import statements for external packages
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../api/apis.dart';