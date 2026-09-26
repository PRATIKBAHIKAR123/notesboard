import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Renders note content with interactive checklists, bullet lists, headings, and markdown inline formatting.
class NoteContentRenderer extends StatelessWidget {
  final String content;
  final void Function(int lineIndex)? onToggleChecklist;

  const NoteContentRenderer({
    super.key,
    required this.content,
    this.onToggleChecklist,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = content.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(lines.length, (index) {
        final line = lines[index];
        return _buildLine(context, line, index);
      }),
    );
  }

  Widget _buildLine(BuildContext context, String line, int lineIndex) {
    final trimmed = line.trim();

    // 1. Checklist Item: unchecked
    if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('[ ] ') || trimmed.startsWith('* [ ] ')) {
      final taskText = trimmed
          .replaceFirst(RegExp(r'^(- \[[ xX]\]|\[[ xX]\]|\* \[[ xX]\])\s*'), '');
      return _buildChecklistItem(
        isChecked: false,
        text: taskText,
        lineIndex: lineIndex,
      );
    }

    // 2. Checklist Item: checked
    if (trimmed.startsWith('- [x] ') ||
        trimmed.startsWith('- [X] ') ||
        trimmed.startsWith('[x] ') ||
        trimmed.startsWith('[X] ') ||
        trimmed.startsWith('* [x] ') ||
        trimmed.startsWith('* [X] ')) {
      final taskText = trimmed
          .replaceFirst(RegExp(r'^(- \[[ xX]\]|\[[ xX]\]|\* \[[ xX]\])\s*'), '');
      return _buildChecklistItem(
        isChecked: true,
        text: taskText,
        lineIndex: lineIndex,
      );
    }

    // 3. Heading 2: starts with "## " — MUST check before "# "
    if (trimmed.startsWith('## ')) {
      final headingText = trimmed.substring(3);
      return Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 1),
        child: _buildRichText(
          headingText,
          AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
    }

    // 4. Heading 1: starts with "# "
    if (trimmed.startsWith('# ')) {
      final headingText = trimmed.substring(2);
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: _buildRichText(
          headingText,
          AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      );
    }

    // 5. Heading 3: starts with "### "
    if (trimmed.startsWith('### ')) {
      final headingText = trimmed.substring(4);
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 1),
        child: _buildRichText(
          headingText,
          AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    // 6. Bullet Item: starts with "- " or "• "
    //    For "* " we must exclude "**" (bold) to avoid eating bold lines
    if (trimmed.startsWith('- ') ||
        trimmed.startsWith('• ') ||
        (trimmed.startsWith('* ') && !trimmed.startsWith('**'))) {
      final bulletText = trimmed.substring(2);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6, right: 6, left: 2),
              width: 4.5,
              height: 4.5,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: _buildRichText(bulletText, AppTextStyles.noteContent),
            ),
          ],
        ),
      );
    }

    // 7. Divider line: --- or ***
    if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(
          height: 2,
          thickness: 1,
          color: AppColors.border,
        ),
      );
    }

    // 8. Blockquote or Callout: starts with "> "
    if (trimmed.startsWith('> ')) {
      final quoteText = trimmed.substring(2).trim();
      return _buildCalloutOrQuote(context, quoteText);
    }

    // 9. Empty Line
    if (trimmed.isEmpty) {
      return const SizedBox(height: 4);
    }

    // 10. Regular paragraph line with inline markdown support
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: _buildRichText(line, AppTextStyles.noteContent),
    );
  }

  Widget _buildCalloutOrQuote(BuildContext context, String text) {
    // Check for callouts like [!NOTE], [!TIP], [!WARNING], [!IMPORTANT]
    Color accentColor = AppColors.primary;
    IconData icon = Icons.format_quote_rounded;
    String displayText = text;

    if (text.startsWith('[!NOTE]')) {
      accentColor = const Color(0xFF3B82F6);
      icon = Icons.info_outline_rounded;
      displayText = text.substring(7).trim();
    } else if (text.startsWith('[!TIP]')) {
      accentColor = const Color(0xFF10B981);
      icon = Icons.lightbulb_outline_rounded;
      displayText = text.substring(6).trim();
    } else if (text.startsWith('[!WARNING]')) {
      accentColor = const Color(0xFFF59E0B);
      icon = Icons.warning_amber_rounded;
      displayText = text.substring(10).trim();
    } else if (text.startsWith('[!IMPORTANT]')) {
      accentColor = const Color(0xFF8B5CF6);
      icon = Icons.priority_high_rounded;
      displayText = text.substring(12).trim();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: accentColor, width: 3.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 6),
            child: Icon(icon, size: 12, color: accentColor),
          ),
          Expanded(
            child: _buildRichText(
              displayText.isEmpty ? text : displayText,
              AppTextStyles.noteContent.copyWith(
                fontSize: 11.5,
                color: AppColors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required bool isChecked,
    required String text,
    required int lineIndex,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: InkWell(
        onTap: onToggleChecklist != null
            ? () => onToggleChecklist!(lineIndex)
            : null,
        borderRadius: BorderRadius.circular(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Interactive Checkbox Icon
            Padding(
              padding: const EdgeInsets.only(top: 1.5, right: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isChecked ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(3.5),
                  border: Border.all(
                    color: isChecked ? AppColors.primary : AppColors.textMuted,
                    width: 1.4,
                  ),
                ),
                child: isChecked
                    ? const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            Expanded(
              child: _buildRichText(
                text,
                AppTextStyles.noteContent.copyWith(
                  decoration: isChecked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppColors.textMuted,
                  color: isChecked ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Parses inline bold `**text**`, italic `*text*`, strikethrough `~~text~~`,
  /// highlight `==text==`, code `` `code` ``, and hashtags `#tag`
  Widget _buildRichText(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|~~[^~]+~~|==[^=]+==|`[^`]+`|#[a-zA-Z0-9_\-]+)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (matchedText.startsWith('~~') && matchedText.endsWith('~~')) {
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.textMuted,
            color: AppColors.textMuted,
          ),
        ));
      } else if (matchedText.startsWith('==') && matchedText.endsWith('==')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              matchedText.substring(2, matchedText.length - 2),
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ));
      } else if (matchedText.startsWith('#') && matchedText.length > 1) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 0.8),
            ),
            child: Text(
              matchedText,
              style: baseStyle.copyWith(
                fontSize: (baseStyle.fontSize ?? 12) * 0.85,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              matchedText.substring(1, matchedText.length - 1),
              style: baseStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 12) * 0.9,
              ),
            ),
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
      overflow: TextOverflow.fade,
    );
  }
}
