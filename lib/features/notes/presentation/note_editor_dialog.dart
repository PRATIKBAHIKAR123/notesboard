import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'widgets/markdown_text_editing_controller.dart';
import 'widgets/note_content_renderer.dart';

class NoteEditorDialog extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final int initialColorIndex;
  final String titleText;

  const NoteEditorDialog({
    super.key,
    this.initialTitle = '',
    this.initialContent = '',
    this.initialColorIndex = 0,
    this.titleText = 'Edit Note',
  });

  static Future<NoteEditResult?> show(
    BuildContext context, {
    String initialTitle = '',
    String initialContent = '',
    int initialColorIndex = 0,
    String titleText = 'Edit Note',
  }) {
    return showDialog<NoteEditResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => NoteEditorDialog(
        initialTitle: initialTitle,
        initialContent: initialContent,
        initialColorIndex: initialColorIndex,
        titleText: titleText,
      ),
    );
  }

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class NoteEditResult {
  final String title;
  final String content;
  final int colorIndex;

  NoteEditResult({
    required this.title,
    required this.content,
    required this.colorIndex,
  });
}

class _NoteTemplate {
  final String label;
  final IconData icon;
  final String defaultTitle;
  final String content;
  final int colorIndex;

  const _NoteTemplate({
    required this.label,
    required this.icon,
    required this.defaultTitle,
    required this.content,
    required this.colorIndex,
  });
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  late int _selectedColorIndex;
  bool _isPreviewMode = false;

  static const List<_NoteTemplate> _templates = [
    _NoteTemplate(
      label: 'Checklist',
      icon: Icons.checklist_rounded,
      defaultTitle: 'Sprint Tasks',
      content: '- [ ] Priority task 1\n- [ ] Priority task 2\n- [ ] Follow up review',
      colorIndex: 1,
    ),
    _NoteTemplate(
      label: 'Idea',
      icon: Icons.lightbulb_outline_rounded,
      defaultTitle: 'Core Concept',
      content: '## Concept\nWhat needs solving and why.\n\n**Benefits:**\n- Key advantage 1\n- Key advantage 2\n\n- [ ] Validate hypothesis',
      colorIndex: 2,
    ),
    _NoteTemplate(
      label: 'Pros & Cons',
      icon: Icons.balance_rounded,
      defaultTitle: 'Architecture Decision',
      content: '**Pros:**\n- Fast local persistence\n- Clean reactive state\n\n**Cons:**\n- Extra initial setup',
      colorIndex: 3,
    ),
    _NoteTemplate(
      label: 'Meeting',
      icon: Icons.groups_outlined,
      defaultTitle: 'Team Sync',
      content: '## Attendees\nTeam members\n\n**Discussion:**\n- Design system progress\n- Canvas gesture optimizations\n\n**Action Items:**\n- [ ] Ship text features\n- [ ] Validate mapping workflows',
      colorIndex: 4,
    ),
    _NoteTemplate(
      label: 'SWOT',
      icon: Icons.grid_view_rounded,
      defaultTitle: 'SWOT Analysis',
      content: '## Strengths\n- Fast execution\n\n## Weaknesses\n- Limited scope\n\n## Opportunities\n- Visual mind mapping\n\n## Threats\n- Complex UX',
      colorIndex: 5,
    ),
    _NoteTemplate(
      label: 'Standup',
      icon: Icons.timer_outlined,
      defaultTitle: 'Daily Standup',
      content: '> [!NOTE] Progress Update\n\n**Yesterday:**\n- Completed grid snapping\n\n**Today:**\n- Implement text styles and mapping\n\n**Blockers:**\n- None #in_progress',
      colorIndex: 1,
    ),
  ];

  static const List<Color> _colors = [
    Colors.white,
    AppColors.noteYellow,
    AppColors.noteBlue,
    AppColors.noteGreen,
    AppColors.notePurple,
    AppColors.noteRose,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = MarkdownTextEditingController(text: widget.initialContent);
    _selectedColorIndex = widget.initialColorIndex;
    // Listen for content changes to update preview
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (_isPreviewMode) {
      setState(() {}); // Refresh preview
    }
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Color _getCardColor(int colorIndex) {
    if (colorIndex >= 0 && colorIndex < _colors.length) {
      return _colors[colorIndex];
    }
    return Colors.white;
  }

  /// Subtle tinted version of the selected color for the dialog chrome
  Color _getTintedSurface(int colorIndex) {
    final base = _getCardColor(colorIndex);
    if (base == Colors.white) return Colors.white;
    return Color.lerp(Colors.white, base, 0.3)!;
  }

  void _applyTemplate(_NoteTemplate template) {
    setState(() {
      if (_titleController.text.trim().isEmpty || _titleController.text == 'New Note') {
        _titleController.text = template.defaultTitle;
      }
      _contentController.text = template.content;
      _selectedColorIndex = template.colorIndex;
    });
  }

  void _insertFormatting(String prefix, [String suffix = '']) {
    final selection = _contentController.selection;
    final text = _contentController.text;

    if (!selection.isValid) {
      final newText = '$text$prefix$suffix';
      _contentController.text = newText;
      _contentController.selection = TextSelection.collapsed(
        offset: newText.length - suffix.length,
      );
      _contentFocusNode.requestFocus();
      return;
    }

    final start = selection.start;
    final end = selection.end;

    if (start != end) {
      final selectedText = text.substring(start, end);
      final newText = text.replaceRange(start, end, '$prefix$selectedText$suffix');
      _contentController.text = newText;
      _contentController.selection = TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: end + prefix.length,
      );
    } else {
      final newText = text.replaceRange(start, end, '$prefix$suffix');
      _contentController.text = newText;
      _contentController.selection = TextSelection.collapsed(
        offset: start + prefix.length,
      );
    }

    _contentFocusNode.requestFocus();
  }

  void _onSave() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop(
      NoteEditResult(
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        colorIndex: _selectedColorIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNewNote = widget.initialTitle.isEmpty && widget.initialContent.isEmpty;
    final dialogBg = _getTintedSurface(_selectedColorIndex);
    final cardColor = _getCardColor(_selectedColorIndex);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedColorIndex == 0
                ? AppColors.border
                : cardColor.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.15),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            const BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Color indicator dot
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: cardColor == Colors.white
                                ? AppColors.textMuted
                                : cardColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(widget.titleText, style: AppTextStyles.titleLarge),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),

                // ── Templates Bar (new notes only) ──
                if (isNewNote) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Quick Starters & Templates:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _templates.map((tpl) {
                      return ActionChip(
                        avatar: Icon(tpl.icon, size: 14, color: AppColors.primary),
                        label: Text(tpl.label, style: const TextStyle(fontSize: 11)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.primaryMuted,
                        side: BorderSide.none,
                        onPressed: () => _applyTemplate(tpl),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Title Field ──
                TextField(
                  controller: _titleController,
                  autofocus: widget.initialTitle.isEmpty,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter note title...',
                    filled: true,
                    fillColor: cardColor == Colors.white
                        ? Colors.white
                        : cardColor.withOpacity(0.25),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _selectedColorIndex == 0
                            ? AppColors.border
                            : cardColor.withOpacity(0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _selectedColorIndex == 0
                            ? AppColors.primary
                            : cardColor,
                        width: 1.8,
                      ),
                    ),
                  ),
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 12),

                // ── Formatting Toolbar + Write/Preview Toggle ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.canvasBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Format buttons (only active in write mode)
                      Expanded(
                        child: Opacity(
                          opacity: _isPreviewMode ? 0.35 : 1.0,
                          child: IgnorePointer(
                            ignoring: _isPreviewMode,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildFormatButton(
                                    icon: Icons.format_bold_rounded,
                                    tooltip: 'Bold (**text**)',
                                    onPressed: () => _insertFormatting('**', '**'),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.format_italic_rounded,
                                    tooltip: 'Italic (*text*)',
                                    onPressed: () => _insertFormatting('*', '*'),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.format_strikethrough_rounded,
                                    tooltip: 'Strikethrough (~~text~~)',
                                    onPressed: () => _insertFormatting('~~', '~~'),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.highlight_rounded,
                                    tooltip: 'Highlight (==text==)',
                                    onPressed: () => _insertFormatting('==', '=='),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.checklist_rounded,
                                    tooltip: 'Checklist (- [ ])',
                                    onPressed: () => _insertFormatting('- [ ] '),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.format_list_bulleted_rounded,
                                    tooltip: 'Bullet List (- )',
                                    onPressed: () => _insertFormatting('- '),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.title_rounded,
                                    tooltip: 'Heading (## )',
                                    onPressed: () => _insertFormatting('## '),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.format_quote_rounded,
                                    tooltip: 'Quote / Callout (> )',
                                    onPressed: () => _insertFormatting('> '),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.tag_rounded,
                                    tooltip: 'Tag (#tag)',
                                    onPressed: () => _insertFormatting('#'),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.horizontal_rule_rounded,
                                    tooltip: 'Divider (---)',
                                    onPressed: () => _insertFormatting('\n---\n'),
                                  ),
                                  _buildFormatButton(
                                    icon: Icons.code_rounded,
                                    tooltip: 'Code (`code`)',
                                    onPressed: () => _insertFormatting('`', '`'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Write / Preview Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildModeTab(
                              label: 'Write',
                              icon: Icons.edit_note_rounded,
                              isActive: !_isPreviewMode,
                              onTap: () => setState(() => _isPreviewMode = false),
                            ),
                            _buildModeTab(
                              label: 'Preview',
                              icon: Icons.visibility_rounded,
                              isActive: _isPreviewMode,
                              onTap: () => setState(() => _isPreviewMode = true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Content Area: Write or Preview ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: cardColor == Colors.white
                        ? Colors.white
                        : cardColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedColorIndex == 0
                          ? AppColors.border
                          : cardColor.withOpacity(0.5),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isPreviewMode
                        ? _buildPreviewPane()
                        : _buildWritePane(cardColor),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Color Selection Row ──
                Row(
                  children: [
                    const Text('Color:', style: AppTextStyles.labelMedium),
                    const SizedBox(width: 12),
                    ...List.generate(_colors.length, (index) {
                      final isSelected = _selectedColorIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          width: isSelected ? 30 : 26,
                          height: isSelected ? 30 : 26,
                          decoration: BoxDecoration(
                            color: _colors[index],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 2.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _colors[index] == Colors.white
                                          ? AppColors.primary.withOpacity(0.3)
                                          : _colors[index].withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: AppColors.primary)
                              : null,
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Action Buttons ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _onSave,
                      child: const Text('Save Note'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Rich text editor pane — shows live markdown formatting
  Widget _buildWritePane(Color cardColor) {
    return TextField(
      key: const ValueKey('write'),
      controller: _contentController,
      focusNode: _contentFocusNode,
      maxLines: 8,
      decoration: const InputDecoration(
        hintText: 'Type your notes… Use toolbar or markdown syntax.',
        alignLabelWithHint: true,
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: EdgeInsets.all(14),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      style: AppTextStyles.bodyMedium.copyWith(
        fontSize: 13.5,
        height: 1.6,
      ),
    );
  }

  /// Live rendered preview pane
  Widget _buildPreviewPane() {
    final content = _contentController.text;
    final title = _titleController.text.trim();

    return Container(
      key: const ValueKey('preview'),
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(14),
      child: content.isEmpty && title.isEmpty
          ? Text(
              'Nothing to preview yet…',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: AppTextStyles.noteTitle.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    color: AppColors.border.withOpacity(0.5),
                    height: 1,
                  ),
                  const SizedBox(height: 8),
                ],
                NoteContentRenderer(content: content),
              ],
            ),
    );
  }

  /// Write / Preview tab button
  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
