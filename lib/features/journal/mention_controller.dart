import 'package:flutter/material.dart';

class Mention {
  const Mention({
    required this.start,
    required this.end,
    required this.kind,
    required this.id,
  });
  final int start, end;
  final String kind, id;
  Mention shift(int amount) =>
      Mention(start: start + amount, end: end + amount, kind: kind, id: id);
}

final mentionPattern = RegExp(
  r'\[((?:\\.|[^\]\\])*)\]\(world-manager://(location|project)/([a-zA-Z0-9-]+)\)',
);
final codePattern = RegExp(
  r'(?<!\\)(?:```[\s\S]*?(?:```|$)|~~~[\s\S]*?(?:~~~|$)|`[^`\n]*(?:`|$))',
);
bool inCode(String text, int offset) => codePattern
    .allMatches(text)
    .any((m) => m.start <= offset && offset < m.end);
String mentionMarkdown(String label, String kind, String id) =>
    '[${label.replaceAllMapped(RegExp(r'[\\`*_{}\[\]()#+\-.!>]'), (m) => '\\${m[0]}')}](world-manager://$kind/$id)';

/// Keeps the editor readable while saving stable record IDs in Markdown links.
class MentionController extends TextEditingController {
  MentionController(String markdown) {
    setMarkdown(markdown);
  }
  List<Mention> mentions = [];
  bool replacing = false;
  void setMarkdown(String markdown) {
    final out = StringBuffer();
    final links = <Mention>[];
    int cursor = 0;
    for (final m in mentionPattern.allMatches(markdown)) {
      if (inCode(markdown, m.start)) continue;
      out.write(markdown.substring(cursor, m.start));
      final label = m[1]!.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
      final start = out.length;
      out.write(label);
      links.add(Mention(start: start, end: out.length, kind: m[2]!, id: m[3]!));
      cursor = m.end;
    }
    out.write(markdown.substring(cursor));
    replacing = true;
    mentions = links;
    value = TextEditingValue(
      text: out.toString(),
      selection: TextSelection.collapsed(offset: out.length),
    );
    replacing = false;
  }

  String get markdown {
    final out = StringBuffer();
    int cursor = 0;
    for (final m in mentions) {
      out.write(text.substring(cursor, m.start));
      out.write(mentionMarkdown(text.substring(m.start, m.end), m.kind, m.id));
      cursor = m.end;
    }
    out.write(text.substring(cursor));
    return out.toString();
  }

  Set<String> ids(String kind) =>
      mentions.where((m) => m.kind == kind).map((m) => m.id).toSet();
  @override
  set value(TextEditingValue next) {
    if (!replacing && next.text != text) {
      final old = text;
      int start = 0;
      while (start < old.length &&
          start < next.text.length &&
          old[start] == next.text[start]) {
        start++;
      }
      int oldEnd = old.length, newEnd = next.text.length;
      while (oldEnd > start &&
          newEnd > start &&
          old[oldEnd - 1] == next.text[newEnd - 1]) {
        oldEnd--;
        newEnd--;
      }
      final delta = newEnd - oldEnd;
      mentions = [
        for (final m in mentions)
          if (m.end <= start &&
              !(m.end == start &&
                  oldEnd == start &&
                  newEnd > start &&
                  RegExp(
                    r'[^\s.,;:!?()\[\]{}*`_#~<>\\]',
                  ).hasMatch(next.text[start])))
            m
          else if (m.start >= oldEnd)
            m.shift(delta),
      ];
    }
    super.value = next;
  }

  void insertMention(int start, int end, String name, String kind, String id) {
    final label = '@$name';
    // Apply the normal edit first so other mention ranges follow the replacement.
    value = TextEditingValue(
      text: text.replaceRange(start, end, '$label '),
      selection: TextSelection.collapsed(offset: start + label.length + 1),
    );
    mentions.add(
      Mention(start: start, end: start + label.length, kind: kind, id: id),
    );
    mentions.sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in mentions) {
      spans.add(TextSpan(text: text.substring(cursor, m.start)));
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      );
      cursor = m.end;
    }
    spans.add(TextSpan(text: text.substring(cursor)));
    // Preserve IME composing decoration rather than splitting its range.
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: true,
      );
    }
    return TextSpan(style: style, children: spans);
  }
}
