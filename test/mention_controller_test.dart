import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/features/journal/mention_controller.dart';

void main() {
  test(
    'readable editor labels preserve IDs, repeated names and Markdown escaping',
    () {
      final source =
          'Worked at ${mentionMarkdown('@Base [east] \\ gate', 'location', 'loc-1')} and ${mentionMarkdown('@Base [east] \\ gate', 'project', 'proj-2')}.';
      final c = MentionController(source);
      addTearDown(c.dispose);
      expect(c.text, r'Worked at @Base [east] \ gate and @Base [east] \ gate.');
      expect(c.markdown, source);
      expect(c.ids('location'), {'loc-1'});
      expect(c.ids('project'), {'proj-2'});
    },
  );
  test(
    'typing before/after shifts links; editing inside unlinks only that mention',
    () {
      final c = MentionController(
        'Hi ${mentionMarkdown('@River', 'location', 'l')} and ${mentionMarkdown('@Bridge', 'project', 'p')}',
      );
      addTearDown(c.dispose);
      c.value = TextEditingValue(
        text: 'Hello ${c.text}',
        selection: const TextSelection.collapsed(offset: 6),
      );
      expect(
        c.markdown,
        'Hello Hi ${mentionMarkdown('@River', 'location', 'l')} and ${mentionMarkdown('@Bridge', 'project', 'p')}',
      );
      c.text = c.text.replaceFirst('@River', '@Rivers');
      expect(c.ids('location'), isEmpty);
      expect(c.ids('project'), {'p'});
      c.text = c.text.replaceFirst('@Bridge', '');
      expect(c.ids('project'), isEmpty);
    },
  );
  test(
    'replacing a typed query preserves surrounding text and multiple links',
    () {
      final c = MentionController('Before @riv after');
      addTearDown(c.dispose);
      c.insertMention(7, 11, 'River base', 'location', 'l');
      expect(c.text, 'Before @River base  after');
      expect(c.selection.extentOffset, 19);
      expect(
        c.markdown,
        'Before ${mentionMarkdown('@River base', 'location', 'l')}  after',
      );
      c.value = c.value.copyWith(
        selection: const TextSelection.collapsed(offset: 0),
      );
      expect(c.ids('location'), {'l'});
    },
  );
  test('Markdown formatting around a whole mention preserves its link', () {
    final c = MentionController(mentionMarkdown('@River', 'location', 'l'));
    addTearDown(c.dispose);
    c.value = TextEditingValue(
      text: '${c.text}**',
      selection: TextSelection.collapsed(offset: c.text.length),
    );
    c.value = TextEditingValue(
      text: '**${c.text}',
      selection: const TextSelection.collapsed(offset: 2),
    );
    expect(c.markdown, '**${mentionMarkdown('@River', 'location', 'l')}**');
  });
  test('escaped record punctuation does not hide later mentions', () {
    final source =
        '${mentionMarkdown('@A ` gate_*', 'location', 'l')} then ${mentionMarkdown('@Bridge', 'project', 'p')}';
    final c = MentionController(source);
    addTearDown(c.dispose);
    expect(c.ids('location'), {'l'});
    expect(c.ids('project'), {'p'});
    expect(c.markdown, source);
  });
  test('code samples stay literal and normal Markdown is unchanged', () {
    final link = mentionMarkdown('@Example', 'project', 'example');
    final source = '**bold** `$link`\n```\n$link\n```\n$link';
    final c = MentionController(source);
    addTearDown(c.dispose);
    expect(c.mentions, hasLength(1));
    expect(c.markdown, source);
  });
}
