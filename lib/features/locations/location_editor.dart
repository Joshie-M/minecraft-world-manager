import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/labeled_field.dart';
import '../../core/database/app_database.dart';
import 'location_repository.dart';

Future<bool?> showLocationEditor(
  BuildContext context, {
  required String worldId,
  Location? location,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => LocationEditor(worldId: worldId, location: location),
);

class LocationEditor extends ConsumerStatefulWidget {
  const LocationEditor({super.key, required this.worldId, this.location});
  final String worldId;
  final Location? location;
  @override
  ConsumerState<LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends ConsumerState<LocationEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.location?.name ?? '');
  late final x = TextEditingController(
    text: widget.location?.x.toString() ?? '',
  );
  late final y = TextEditingController(
    text: widget.location?.y.toString() ?? '',
  );
  late final z = TextEditingController(
    text: widget.location?.z.toString() ?? '',
  );
  late final notes = TextEditingController(text: widget.location?.notes ?? '');
  late String dimension = widget.location?.dimension ?? 'Overworld';
  late final custom = TextEditingController(
    text: dimensions.contains(dimension) ? '' : dimension,
  );
  bool saving = false, allowLeave = false;
  String? error;
  bool get dirty =>
      name.text != (widget.location?.name ?? '') ||
      x.text != (widget.location?.x.toString() ?? '') ||
      y.text != (widget.location?.y.toString() ?? '') ||
      z.text != (widget.location?.z.toString() ?? '') ||
      notes.text != (widget.location?.notes ?? '') ||
      dimension != (widget.location?.dimension ?? 'Overworld') ||
      custom.text !=
          (dimensions.contains(widget.location?.dimension ?? 'Overworld')
              ? ''
              : widget.location!.dimension);
  @override
  void initState() {
    super.initState();
    for (final c in [name, x, y, z, notes, custom]) {
      c.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    for (final c in [name, x, y, z, notes, custom]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> leave(bool saved) async {
    setState(() => allowLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, saved);
  }

  Future<void> close() async {
    if (saving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    await leave(false);
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(locationRepositoryProvider)
          .save(
            worldId: widget.worldId,
            id: widget.location?.id,
            name: name.text,
            x: int.parse(x.text.trim()),
            y: int.parse(y.text.trim()),
            z: int.parse(z.text.trim()),
            dimension: dimensions.contains(dimension) ? dimension : custom.text,
            notes: notes.text,
          );
      if (mounted) await leave(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not save this location. Your changes are still here; please try again.';
        });
      }
    }
  }

  String? validateCoordinate(String? text) {
    final clean = text?.trim() ?? '';
    final value = RegExp(r'^[-+]?[0-9]+$').hasMatch(clean)
        ? int.tryParse(clean)
        : null;
    return value == null || value < -2147483648 || value > 2147483647
        ? 'Enter a 32-bit whole number.'
        : null;
  }

  Widget coordinate(String label, TextEditingController controller) =>
      LabeledField(
        label: label,
        child: TextFormField(
          key: ValueKey('coordinate-$label'),
          controller: controller,
          enabled: !saving,
          validator: validateCoordinate,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
        ),
      );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowLeave || (!dirty && !saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): save,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): save,
      },
      child: AlertDialog(
        title: Text(widget.location == null ? 'New location' : 'Edit location'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LabeledField(
                    label: 'Location name',
                    child: TextFormField(
                      key: const ValueKey('location-name'),
                      controller: name,
                      autofocus: true,
                      enabled: !saving,
                      maxLength: 100,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Give this location a name.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (_, constraints) => constraints.maxWidth < 350
                        ? Column(
                            children: [
                              coordinate('X', x),
                              const SizedBox(height: 12),
                              coordinate('Y', y),
                              const SizedBox(height: 12),
                              coordinate('Z', z),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: coordinate('X', x)),
                              const SizedBox(width: 12),
                              Expanded(child: coordinate('Y', y)),
                              const SizedBox(width: 12),
                              Expanded(child: coordinate('Z', z)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Dimension',
                    child: DropdownButtonFormField<String>(
                      initialValue: dimensions.contains(dimension)
                          ? dimension
                          : 'Custom',
                      items: [...dimensions, 'Custom']
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => setState(() => dimension = value!),
                    ),
                  ),
                  if (!dimensions.contains(dimension)) ...[
                    const SizedBox(height: 12),
                    LabeledField(
                      label: 'Custom dimension',
                      child: TextFormField(
                        key: const ValueKey('custom-dimension'),
                        controller: custom,
                        enabled: !saving,
                        maxLength: 100,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Name this dimension.'
                            : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Notes (optional)',
                    child: TextFormField(
                      controller: notes,
                      enabled: !saving,
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : close,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save location'),
          ),
        ],
      ),
    ),
  );
}
