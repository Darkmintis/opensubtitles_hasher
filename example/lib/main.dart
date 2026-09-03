import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opensubtitles_hasher/opensubtitles_hasher.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'opensubtitles_hasher',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _pathController = TextEditingController();

  /// Android picker mode. Default matches package default.
  MoviePickerMode _mode = MoviePickerMode.systemDocuments;

  /// 0 = filter off.
  int _minDurationMinutes = 0;

  /// 0 = filter off.
  int _minSizeMb = 0;

  /// Selected MIME keys. Empty / only all → video/*.
  final Set<String> _mimeKeys = {'all'};

  String? _hash;
  int? _fileSize;
  String? _info;
  String? _error;
  bool _loading = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static const _mimeChoices = <String, String>{
    'all': 'video/*',
    'mp4': 'video/mp4',
    'mkv': 'video/x-matroska',
    'webm': 'video/webm',
    'avi': 'video/x-msvideo',
  };

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  MoviePickerOptions get _options {
    final mimes = _mimeKeys.contains('all') || _mimeKeys.isEmpty
        ? MoviePickerOptions.defaultMimeTypes
        : _mimeKeys.map((k) => _mimeChoices[k]!).toList();

    return MoviePickerOptions(
      mode: _mode,
      mimeTypes: mimes,
      minDuration: _minDurationMinutes > 0
          ? Duration(minutes: _minDurationMinutes)
          : null,
      minSizeBytes: _minSizeMb > 0 ? _minSizeMb * 1024 * 1024 : null,
    );
  }

  Future<void> _computeHash() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _error = 'Enter a file path or content:// URI';
        _hash = null;
        _fileSize = null;
        _info = null;
      });
      return;
    }
    await _runHash(path);
  }

  Future<void> _pickAndHash() async {
    setState(() {
      _loading = true;
      _error = null;
      _hash = null;
      _fileSize = null;
      _info = null;
    });

    try {
      final picked = await OpenSubtitlesHasher.pickAndHash(options: _options);
      if (picked == null) {
        setState(() => _info = 'Cancelled');
        return;
      }

      _pathController.text = picked.movie.effectivePath;
      final duration = picked.movie.duration;
      setState(() {
        _hash = picked.hash.hash;
        _fileSize = picked.hash.fileSize;
        _info = [
          picked.movie.name ?? 'Selected video',
          if (duration != null) _formatDuration(duration),
        ].join(' · ');
      });
    } on MovieFilterException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } on UnsupportedError catch (e) {
      setState(() => _error = e.message);
    } on PlatformException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _runHash(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _hash = null;
      _fileSize = null;
      _info = null;
    });

    try {
      final result = await OpenSubtitlesHasher.computeHashResult(path);
      setState(() {
        _hash = result.hash;
        _fileSize = result.fileSize;
      });
    } on FileSystemException catch (e) {
      setState(() => _error = 'File error: ${e.message}');
    } on InvalidFileException catch (e) {
      setState(() => _error = e.message);
    } on PlatformException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _nudgeDuration(int delta) {
    setState(() {
      _minDurationMinutes = (_minDurationMinutes + delta).clamp(0, 300);
    });
  }

  void _nudgeSize(int delta) {
    setState(() {
      _minSizeMb = (_minSizeMb + delta).clamp(0, 5000);
    });
  }

  void _toggleMime(String key) {
    setState(() {
      if (key == 'all') {
        _mimeKeys
          ..clear()
          ..add('all');
        return;
      }
      _mimeKeys.remove('all');
      if (!_mimeKeys.add(key)) {
        _mimeKeys.remove(key);
      }
      if (_mimeKeys.isEmpty) {
        _mimeKeys.add('all');
      }
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('opensubtitles_hasher')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hash from path', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Path or content:// URI',
              hintText: '/path/to/movie.mp4',
            ),
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _loading ? null : _computeHash,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Compute hash'),
          ),
          const SizedBox(height: 28),
          Text(
            'Movie picker',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            _isAndroid
                ? 'systemDocuments: system file UI (Play-safe).\n'
                    'safFolder: grant one folder, then branded video browser '
                    '(Play-safe). Use ⋮ Change folder to pick again.\n'
                    'mediaStore: whole-device browser (needs READ_MEDIA_VIDEO '
                    'in the host app + runtime grant; not for Play).'
                : 'System file dialog filtered by video extension. '
                    'Duration / size filters are Android-only.',
            style: theme.textTheme.bodySmall,
          ),
          if (_isAndroid) ...[
            const SizedBox(height: 12),
            Text('Android mode', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MoviePickerMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(mode.name),
                  selected: _mode == mode,
                  onSelected: (_) => setState(() => _mode = mode),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            _StepperRow(
              label: 'Min duration',
              valueLabel:
                  _minDurationMinutes == 0 ? 'Off' : '$_minDurationMinutes min',
              onDecrement: () => _nudgeDuration(-15),
              onIncrement: () => _nudgeDuration(15),
            ),
            const SizedBox(height: 8),
            _StepperRow(
              label: 'Min size',
              valueLabel: _minSizeMb == 0 ? 'Off' : '$_minSizeMb MB',
              onDecrement: () => _nudgeSize(-50),
              onIncrement: () => _nudgeSize(50),
            ),
            const SizedBox(height: 12),
            Text('Types', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mimeChoices.keys.map((key) {
                final selected = _mimeKeys.contains(key);
                return FilterChip(
                  label: Text(key == 'all' ? 'All videos' : key.toUpperCase()),
                  selected: selected,
                  onSelected: (_) => _toggleMime(key),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : _pickAndHash,
            icon: const Icon(Icons.movie_outlined),
            label: const Text('Pick movie + hash'),
          ),
          const SizedBox(height: 24),
          if (_info != null) Text(_info!),
          if (_hash != null) ...[
            Text('Hash', style: theme.textTheme.titleMedium),
            SelectableText(_hash!, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$_fileSize bytes'),
            const SizedBox(height: 4),
            SelectableText(
              '{moviehash: $_hash, moviebytesize: $_fileSize}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.valueLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String valueLabel;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        IconButton.filledTonal(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove),
          tooltip: 'Decrease',
        ),
        SizedBox(
          width: 88,
          child: Text(
            valueLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton.filledTonal(
          onPressed: onIncrement,
          icon: const Icon(Icons.add),
          tooltip: 'Increase',
        ),
      ],
    );
  }
}
