import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/file_model.dart';
import '../widgets/file_card.dart';

class HomeScreen extends StatefulWidget {
  final String serverUrl;
  final VoidCallback onSettingsPressed;

  const HomeScreen({
    super.key,
    required this.serverUrl,
    required this.onSettingsPressed,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late ApiService _api;
  List<FileModel> _files = [];
  StatsModel? _stats;
  bool _loading = true;
  bool _uploading = false;
  String _error = '';
  String _searchQuery = '';
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.serverUrl);
    _loadData();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl != widget.serverUrl) {
      _api = ApiService(widget.serverUrl);
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final files = await _api.getFiles(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        category: _selectedCategory != 'all' ? _selectedCategory : null,
      );
      final stats = await _api.getStats();

      if (mounted) {
        setState(() {
          _files = files;
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not connect to server.\nMake sure the server is running at:\n${widget.serverUrl}';
        });
      }
    }
  }

  Future<void> _uploadFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _uploading = true);

      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();

      await _api.uploadFiles(files);

      if (mounted) {
        _showSnackBar('${files.length} file(s) uploaded!', Icons.check_circle, const Color(0xFF22C55E));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Upload failed', Icons.error, const Color(0xFFEF4444));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadFile(FileModel file) async {
    try {
      _showSnackBar('Starting download for ${file.originalName}...', Icons.download, const Color(0xFF6366F1));
      await _api.downloadFile(file.id, file.originalName);
      // Removed the 'Saved to $path' snackbar because flutter_downloader will show a system notification
    } catch (e) {
      if (mounted) {
        _showSnackBar('Download failed to start', Icons.error, const Color(0xFFEF4444));
      }
    }
  }

  Future<void> _deleteFile(FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 32),
        ),
        title: const Text('Delete File?'),
        content: Text(
          '"${file.originalName}" will be permanently deleted.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deleteFile(file.id);
        if (mounted) {
          _showSnackBar('File deleted', Icons.check_circle, const Color(0xFF22C55E));
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Delete failed', Icons.error, const Color(0xFFEF4444));
        }
      }
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- App Bar ---
          SliverAppBar(
            floating: true,
            snap: true,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'FileVault',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: widget.onSettingsPressed,
              ),
            ],
          ),

          // --- Stats Cards ---
          if (_stats != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _StatCard(
                      icon: Icons.folder_rounded,
                      label: 'Files',
                      value: '${_stats!.totalFiles}',
                      color: const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.storage_rounded,
                      label: 'Storage',
                      value: _stats!.totalSizeFormatted,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ),
            ),

          // --- Search & Filter ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search files...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.3)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadData();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _loadData();
                },
              ),
            ),
          ),

          // --- Category Filter Chips ---
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(label: 'All', value: 'all', selected: _selectedCategory, onSelected: _onCategoryChanged),
                  _FilterChip(label: 'Images', value: 'image', selected: _selectedCategory, onSelected: _onCategoryChanged),
                  _FilterChip(label: 'Videos', value: 'video', selected: _selectedCategory, onSelected: _onCategoryChanged),
                  _FilterChip(label: 'Audio', value: 'audio', selected: _selectedCategory, onSelected: _onCategoryChanged),
                  _FilterChip(label: 'Docs', value: 'document', selected: _selectedCategory, onSelected: _onCategoryChanged),
                  _FilterChip(label: 'Archives', value: 'archive', selected: _selectedCategory, onSelected: _onCategoryChanged),
                ],
              ),
            ),
          ),

          // --- Section Title ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Your Files',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_files.length})',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),

          // --- Content ---
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_error.isNotEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_files.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),
                    Text(
                      'No files yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to upload your first file',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FileCard(
                      file: _files[index],
                      previewUrl: _files[index].category == 'image'
                          ? _api.getPreviewUrl(_files[index].id)
                          : null,
                      onDownload: () => _downloadFile(_files[index]),
                      onDelete: () => _deleteFile(_files[index]),
                    ),
                  ),
                  childCount: _files.length,
                ),
              ),
            ),
        ],
      ),

      // --- FAB ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _uploadFiles,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: _uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: Text(_uploading ? 'Uploading...' : 'Upload'),
      ),
    );
  }

  void _onCategoryChanged(String category) {
    setState(() => _selectedCategory = category);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// --- Stat Card Widget ---
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Filter Chip Widget ---
class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
        checkmarkColor: const Color(0xFF6366F1),
        backgroundColor: Colors.white.withValues(alpha: 0.03),
        side: BorderSide(
          color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
        ),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.5),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
