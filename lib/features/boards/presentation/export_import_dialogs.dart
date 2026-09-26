import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../data/board_export_service.dart';
import '../domain/board.dart';

class ExportBoardDialog extends StatefulWidget {
  final Board board;
  final String jsonContent;
  final String markdownContent;

  const ExportBoardDialog({
    super.key,
    required this.board,
    required this.jsonContent,
    required this.markdownContent,
  });

  static Future<void> show(BuildContext context, WidgetRef ref, Board board) async {
    final service = ref.read(boardExportServiceProvider);
    final jsonStr = await service.exportBoardToJson(board.id);
    final mdStr = await service.exportBoardToMarkdown(board.id);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => ExportBoardDialog(
          board: board,
          jsonContent: jsonStr,
          markdownContent: mdStr,
        ),
      );
    }
  }

  @override
  State<ExportBoardDialog> createState() => _ExportBoardDialogState();
}

class _ExportBoardDialogState extends State<ExportBoardDialog> {
  bool _isMarkdown = false;
  bool _copied = false;

  String get _currentContent => _isMarkdown ? widget.markdownContent : widget.jsonContent;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _currentContent));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _saveToFile() async {
    final ext = _isMarkdown ? 'md' : 'notesboard.json';
    final allowedExt = _isMarkdown ? ['md'] : ['json'];
    final fileName = '${widget.board.name.replaceAll(RegExp(r'[\s/\\?%*:|"<>]'), '_')}.$ext';

    try {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: _isMarkdown ? 'Save Markdown Document' : 'Save Board Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: allowedExt,
        bytes: utf8.encode(_currentContent),
      );

      if (outputFile != null && !kIsWeb) {
        final file = File(outputFile);
        await file.writeAsString(_currentContent);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Board exported as ${_isMarkdown ? "Markdown" : "JSON"} successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Export Board', style: AppTextStyles.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Format selector
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.canvasBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isMarkdown = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isMarkdown ? AppColors.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_isMarkdown
                                ? [const BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.data_object_rounded,
                                size: 16,
                                color: !_isMarkdown ? AppColors.primary : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'JSON Backup',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: !_isMarkdown ? FontWeight.w600 : FontWeight.w500,
                                  color: !_isMarkdown ? AppColors.primaryDark : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isMarkdown = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isMarkdown ? AppColors.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _isMarkdown
                                ? [const BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 16,
                                color: _isMarkdown ? AppColors.primary : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Markdown (.md)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _isMarkdown ? FontWeight.w600 : FontWeight.w500,
                                  color: _isMarkdown ? AppColors.primaryDark : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                _isMarkdown
                    ? 'Export board contents, note checklists, and relationship connections formatted as clean Markdown document.'
                    : 'Export all notes, images, groups, and connections for "${widget.board.name}" as a portable JSON backup file.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: Icon(_copied ? Icons.check : Icons.copy_rounded, size: 18),
                      label: Text(_copied ? 'Copied!' : (_isMarkdown ? 'Copy Markdown' : 'Copy JSON')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveToFile,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(_isMarkdown ? 'Save File (.md)' : 'Save File (.json)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImportBoardDialog extends StatefulWidget {
  const ImportBoardDialog({super.key});

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (context) => const ImportBoardDialog(),
    );
  }

  @override
  State<ImportBoardDialog> createState() => _ImportBoardDialogState();
}

class _ImportBoardDialogState extends State<ImportBoardDialog> {
  final TextEditingController _jsonController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content;
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          content = await File(file.path!).readAsString();
        } else {
          throw Exception('Unable to read selected file');
        }

        _jsonController.text = content;
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load file: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onImport(ConsumerStatefulWidget? _) async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please select a file or paste JSON data');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final service = container.read(boardExportServiceProvider);
      final importedBoard = await service.importBoardFromJson(text);

      if (mounted) {
        Navigator.of(context).pop();
        context.go('/boards/${importedBoard.id}?name=${Uri.encodeComponent(importedBoard.name)}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Invalid format: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Import Board Backup', style: AppTextStyles.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Restore a board from a .notesboard.json backup file.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Pick File button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: const Text('Pick .json File from Device'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              const SizedBox(height: 14),
              const Text('Or paste JSON content directly:', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),

              TextField(
                controller: _jsonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '{\n  "format": "notesboard",\n  ...\n}',
                ),
                style: AppTextStyles.bodySmall,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _onImport(null),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Import Board'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
