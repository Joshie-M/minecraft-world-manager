import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MinecraftBlock {
  const MinecraftBlock({
    required this.name,
    required this.id,
    required this.stackSize,
    required this.aliases,
  });
  final String name, id;
  final int stackSize;
  final List<String> aliases;
}

class BlockCatalog {
  BlockCatalog(this.blocks);
  final List<MinecraftBlock> blocks;
  static Future<BlockCatalog> load() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/catalog/blocks.json'))
            as Map<String, dynamic>;
    return BlockCatalog(
      (data['blocks'] as List).map((value) {
        final row = value as Map<String, dynamic>;
        return MinecraftBlock(
          name: row['name'] as String,
          id: row['id'] as String,
          stackSize: row['stackSize'] as int,
          aliases: List<String>.from(row['aliases'] as List),
        );
      }).toList(),
    );
  }

  List<MinecraftBlock> search(String query) {
    final words = query
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'));
    if (query.trim().isEmpty) return [];
    bool matches(MinecraftBlock b) => words.every(
      ('${b.name} ${b.aliases.join(' ')}'.toLowerCase().replaceAll(
        '_',
        ' ',
      )).contains,
    );
    final found = blocks.where(matches).toList();
    final needle = query.trim().toLowerCase();
    found.sort((a, b) {
      final prefix = (a.name.toLowerCase().startsWith(needle) ? 0 : 1)
          .compareTo(b.name.toLowerCase().startsWith(needle) ? 0 : 1);
      return prefix != 0 ? prefix : a.name.compareTo(b.name);
    });
    return found.take(12).toList();
  }

  MinecraftBlock? match(String name) {
    final needle = name.trim().toLowerCase().replaceFirst('minecraft:', '');
    for (final block in blocks) {
      if (block.name.toLowerCase() == needle ||
          block.aliases.contains(needle)) {
        return block;
      }
    }
    return null;
  }
}

final blockCatalogProvider = FutureProvider((ref) => BlockCatalog.load());

String stackQuantity(int quantity, int size) {
  if (quantity < 0 || ![1, 16, 64].contains(size)) {
    throw ArgumentError('Invalid stack quantity.');
  }
  if (size == 1) {
    return '$quantity ${quantity == 1 ? 'item' : 'items'} (unstackable)';
  }
  final stacks = quantity ~/ size, loose = quantity % size;
  if (stacks == 0) return '$loose ${loose == 1 ? 'item' : 'items'}';
  final full = '$stacks × stacks of $size';
  return loose == 0 ? full : '$full + $loose ${loose == 1 ? 'item' : 'items'}';
}
