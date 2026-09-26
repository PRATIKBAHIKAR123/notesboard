import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// A TextEditingController that renders inline markdown formatting
/// directly inside the TextField as you type.
///
/// Supports: **bold**, *italic*, `code`, ## headings, - [ ] checklists, - bullets
class MarkdownTextEditingController extends TextEditingController {
  MarkdownTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final text = this.text;

    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(text: '\n'));
      }
      final lineSpans = _parseLine(lines[i], baseStyle);
      spans.addAll(lineSpans);
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  List<InlineSpan> _parseLine(String line, TextStyle baseStyle) {
    final trimmed = line.trimLeft();
    final leadingSpaces = line.length - trimmed.length;
    final indent = leadingSpaces > 0 ? line.substring(0, leadingSpaces) : '';

    // Dim style for markdown syntax characters
    final dimStyle = baseStyle.copyWith(
      color: AppColors.textMuted.withOpacity(0.45),
      fontSize: (baseStyle.fontSize ?? 14) * 0.85,
    );

    // ── Heading ### ──
    if (trimmed.startsWith('### ')) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(text: '### ', style: dimStyle),
        ..._parseInlineFormatting(
          trimmed.substring(4),
          baseStyle.copyWith(fontWeight: FontWeight.w600, fontSize: (baseStyle.fontSize ?? 14) * 1.05),
        ),
      ];
    }

    // ── Heading ## ──
    if (trimmed.startsWith('## ')) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(text: '## ', style: dimStyle),
        ..._parseInlineFormatting(
          trimmed.substring(3),
          baseStyle.copyWith(fontWeight: FontWeight.w700, fontSize: (baseStyle.fontSize ?? 14) * 1.15),
        ),
      ];
    }

    // ── Heading # ──
    if (trimmed.startsWith('# ')) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(text: '# ', style: dimStyle),
        ..._parseInlineFormatting(
          trimmed.substring(2),
          baseStyle.copyWith(fontWeight: FontWeight.w800, fontSize: (baseStyle.fontSize ?? 14) * 1.25),
        ),
      ];
    }

    // ── Checklist: checked ──
    if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
      final taskText = trimmed.substring(6);
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(
          text: '- [x] ',
          style: dimStyle.copyWith(color: AppColors.primary.withOpacity(0.6)),
        ),
        ..._parseInlineFormatting(
          taskText,
          baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            color: AppColors.textMuted,
            decorationColor: AppColors.textMuted.withOpacity(0.6),
          ),
        ),
      ];
    }

    // ── Checklist: unchecked ──
    if (trimmed.startsWith('- [ ] ')) {
      final taskText = trimmed.substring(6);
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(
          text: '- [ ] ',
          style: dimStyle.copyWith(color: AppColors.primary.withOpacity(0.6)),
        ),
        ..._parseInlineFormatting(taskText, baseStyle),
      ];
    }

    // ── Bullet: - or • ──
    if (trimmed.startsWith('- ') && !trimmed.startsWith('- [')) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(
          text: '• ',
          style: baseStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        ..._parseInlineFormatting(trimmed.substring(2), baseStyle),
      ];
    }

    if (trimmed.startsWith('• ')) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(
          text: '• ',
          style: baseStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        ..._parseInlineFormatting(trimmed.substring(2), baseStyle),
      ];
    }

    // ── Bullet: * (but not **bold**) ──
    if (trimmed.startsWith('* ') && !trimmed.startsWith('**')) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(
          text: '• ',
          style: baseStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        ..._parseInlineFormatting(trimmed.substring(2), baseStyle),
      ];
    }

    // ── Blockquote: > ──
    if (trimmed.startsWith('> ')) {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(
          text: '▎ ',
          style: baseStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900),
        ),
        ..._parseInlineFormatting(
          trimmed.substring(2),
          baseStyle.copyWith(fontStyle: FontStyle.italic, color: AppColors.textPrimary),
        ),
      ];
    }

    // ── Divider: --- ──
    if (trimmed == '---' || trimmed == '***') {
      return [
        if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
        TextSpan(
          text: '─── ─ ───',
          style: dimStyle.copyWith(letterSpacing: 3),
        ),
      ];
    }

    // ── Regular line with inline formatting ──
    return [
      if (indent.isNotEmpty) TextSpan(text: indent, style: baseStyle),
      ..._parseInlineFormatting(trimmed, baseStyle),
    ];
  }

  /// Parses inline **bold**, *italic*, ~~strikethrough~~, ==highlight==, `code`, and #tags
  List<InlineSpan> _parseInlineFormatting(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [];

    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|~~[^~]+~~|==[^=]+==|`[^`]+`|#[a-zA-Z0-9_\-]+)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final matched = match.group(0)!;
      final dimMarker = baseStyle.copyWith(
        color: AppColors.textMuted.withOpacity(0.35),
        fontSize: (baseStyle.fontSize ?? 14) * 0.8,
      );

      if (matched.startsWith('**') && matched.endsWith('**') && matched.length > 4) {
        // **bold**
        final content = matched.substring(2, matched.length - 2);
        spans.add(TextSpan(text: '**', style: dimMarker));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
        spans.add(TextSpan(text: '**', style: dimMarker));
      } else if (matched.startsWith('*') && matched.endsWith('*') && matched.length > 2) {
        // *italic*
        final content = matched.substring(1, matched.length - 1);
        spans.add(TextSpan(text: '*', style: dimMarker));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
        spans.add(TextSpan(text: '*', style: dimMarker));
      } else if (matched.startsWith('~~') && matched.endsWith('~~') && matched.length > 4) {
        // ~~strikethrough~~
        final content = matched.substring(2, matched.length - 2);
        spans.add(TextSpan(text: '~~', style: dimMarker));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.textMuted,
            color: AppColors.textMuted,
          ),
        ));
        spans.add(TextSpan(text: '~~', style: dimMarker));
      } else if (matched.startsWith('==') && matched.endsWith('==') && matched.length > 4) {
        // ==highlight==
        final content = matched.substring(2, matched.length - 2);
        spans.add(TextSpan(text: '==', style: dimMarker));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            backgroundColor: const Color(0xFFFEF3C7),
            color: const Color(0xFF92400E),
            fontWeight: FontWeight.w600,
          ),
        ));
        spans.add(TextSpan(text: '==', style: dimMarker));
      } else if (matched.startsWith('#') && matched.length > 1) {
        // #tag
        spans.add(TextSpan(
          text: matched,
          style: baseStyle.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            backgroundColor: AppColors.primaryMuted.withOpacity(0.5),
          ),
        ));
      } else if (matched.startsWith('`') && matched.endsWith('`') && matched.length > 2) {
        // `code`
        final content = matched.substring(1, matched.length - 1);
        spans.add(TextSpan(text: '`', style: dimMarker));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.black.withOpacity(0.06),
            fontSize: (baseStyle.fontSize ?? 14) * 0.92,
          ),
        ));
        spans.add(TextSpan(text: '`', style: dimMarker));
      } else {
        // Fallback
        spans.add(TextSpan(text: matched, style: baseStyle));
      }

      lastEnd = match.end;
    }

    // Remaining text after the last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }
}
