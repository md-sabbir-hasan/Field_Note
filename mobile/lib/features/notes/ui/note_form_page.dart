import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/permissions/permission_flow.dart';
import '../../sites/data/site.dart';
import '../bloc/note_bloc.dart';
import '../bloc/note_event.dart';
import '../data/note.dart';
import '../data/note_status.dart';

/// Create (note == null) and edit.
class NoteFormPage extends StatefulWidget {
  const NoteFormPage({
    super.key,
    this.note,
    required this.sites,
    required this.defaultStatus,
  });

  final Note? note;
  final List<Site> sites;

  /// From Settings. Only applied to new notes.
  final NoteStatus defaultStatus;

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  static final _dateFormat = DateFormat('d MMM y, h:mm a');

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String? _siteId;
  late NoteStatus _status;
  late DateTime _notedAt;
  double? _latitude;
  double? _longitude;
  bool _locating = false;

  // Photo: _photoPath is the current local file (null = none).
  // _photoChanged stays false until the user adds or removes a photo.
  String? _photoPath;
  bool _photoChanged = false;

  bool get _isEdit => widget.note != null;

  bool get _showsServerPhoto => !_photoChanged && (widget.note?.hasPhoto ?? false);

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleController = TextEditingController(text: n?.title);
    _descriptionController = TextEditingController(text: n?.description);
    _status = n?.status ?? widget.defaultStatus;
    _notedAt = n?.notedAt.toLocal() ?? DateTime.now();
    _latitude = n?.latitude;
    _longitude = n?.longitude;
    _photoPath = n?.localPhotoPath;

    // Keep the old site only if it is still in the list.
    _siteId = widget.sites.any((s) => s.id == n?.siteId) ? n?.siteId : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------------ date & time

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _notedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_notedAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _notedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // --------------------------------------------------------------- location

  Future<void> _useCurrentLocation() async {
    if (!await PermissionFlow.ensureLocation(context)) return;
    if (!mounted) return;

    setState(() => _locating = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        // 6 decimals is about 10 cm, plenty for a field note.
        _latitude = double.parse(position.latitude.toStringAsFixed(6));
        _longitude = double.parse(position.longitude.toStringAsFixed(6));
      });
    } on TimeoutException {
      if (mounted) _snack('Could not get a GPS fix. Try again outdoors.');
    } catch (_) {
      if (mounted) _snack('Could not read your location');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ------------------------------------------------------------------ photo

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    // The gallery uses the system photo picker and needs no permission.
    if (source == ImageSource.camera && !await PermissionFlow.ensureCamera(context)) return;
    if (!mounted) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80, // compress to JPEG
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      setState(() {
        _photoPath = file.path;
        _photoChanged = true;
      });
    } catch (_) {
      if (mounted) _snack('Could not open the photo');
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoChanged = true;
    });
  }

  // ------------------------------------------------------------------- save

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.read<NoteBloc>().add(NoteSaved(
      id: widget.note?.id,
      siteId: _siteId!,
      title: _titleController.text,
      description: _descriptionController.text,
      latitude: _latitude,
      longitude: _longitude,
      notedAt: _notedAt,
      status: _status,
      photoChanged: _photoChanged,
      photoSourcePath: _photoPath,
    ));
    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit note' : 'New note')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _siteId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Site',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in widget.sites)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.siteName} · ${s.customerName}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _siteId = v),
                  validator: (v) => v == null ? 'Select a site' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Title is required';
                    if (value.length > 200) return 'Title is too long';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 10000,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<NoteStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in NoteStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date & time',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.edit_calendar_outlined),
                    ),
                    child: Text(_dateFormat.format(_notedAt)),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLocationSection(),
                const SizedBox(height: 16),
                _buildPhotoSection(),
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: Text(_isEdit ? 'Update' : 'Save')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    final hasLocation = _latitude != null && _longitude != null;
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
      child: Row(
        children: [
          Expanded(
            child: Text(hasLocation
                ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                : 'Not set'),
          ),
          if (_locating)
            const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            IconButton(
              tooltip: 'Use current location',
              icon: const Icon(Icons.my_location),
              onPressed: _useCurrentLocation,
            ),
            if (hasLocation)
              IconButton(
                tooltip: 'Clear location',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _latitude = null;
                  _longitude = null;
                }),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    final hasLocalPhoto = _photoPath != null;
    final hasAnyPhoto = hasLocalPhoto || _showsServerPhoto;

    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Photo (optional)', border: OutlineInputBorder()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasLocalPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_photoPath!),
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 80,
                  child: Center(child: Text('Photo file not found')),
                ),
              ),
            )
          else if (_showsServerPhoto)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('A photo is saved with this note.'),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _choosePhotoSource,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(hasAnyPhoto ? 'Replace' : 'Add photo'),
              ),
              if (hasAnyPhoto)
                TextButton.icon(
                  onPressed: _removePhoto,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}