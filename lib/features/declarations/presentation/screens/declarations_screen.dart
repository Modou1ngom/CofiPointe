import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../providers/app_providers.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/feedback/app_toast.dart';

class DeclarationsScreen extends ConsumerStatefulWidget {
  const DeclarationsScreen({
    super.key,
    this.initialType,
    this.initialDate,
    this.nonPointageMode = false,
    this.pointageManquant,
  });

  static const routePath = '/declarations';

  /// Préremplissage depuis l’historique (bouton R).
  final String? initialType;
  final DateTime? initialDate;
  final bool nonPointageMode;
  /// `entree` | `sortie` | null (choix utilisateur si les deux manquent)
  final String? pointageManquant;

  @override
  ConsumerState<DeclarationsScreen> createState() => _DeclarationsScreenState();
}

class _DeclarationsScreenState extends ConsumerState<DeclarationsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _types = const [];
  String? _error;

  final _motifCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  String _type = 'permission_exceptionnelle';
  DateTime _dateDebut = DateTime.now();
  DateTime? _dateFin;
  TimeOfDay? _heureDebut;
  TimeOfDay? _heureFin;
  /// Allaitement : `entree` | `sortie`
  String _allaitementSens = 'entree';
  String? _justificatifPath;
  String? _justificatifName;
  String? _pointageManquant;
  late final bool _nonPointageMode;

  /// Types du formulaire (Régularisation = flux non-pointage uniquement).
  static const _fallbackTypes = [
    {'value': 'absence', 'label': 'Absence'},
    {'value': 'conge_annuel', 'label': 'Congé annuel'},
    {'value': 'conge_maladie', 'label': 'Congé maladie'},
    {'value': 'permission_exceptionnelle', 'label': 'Permission exceptionnelle'},
    {'value': 'allaitement', 'label': 'Allaitement'},
    {'value': 'mission', 'label': 'Mission'},
    {'value': 'formation', 'label': 'Formation'},
  ];

  bool get _needsDateRange =>
      !_nonPointageMode &&
      const {
        'absence',
        'conge_annuel',
        'conge_maladie',
        'permission_exceptionnelle',
        'allaitement',
        'mission',
        'formation',
        'conge',
      }.contains(_type);

  bool get _needsHeures =>
      (!_nonPointageMode && _type == 'permission_exceptionnelle') ||
      (_nonPointageMode &&
          (_pointageManquant == 'entree' || _pointageManquant == 'sortie'));

  bool get _needsAllaitement => !_nonPointageMode && _type == 'allaitement';

  bool get _needsLieu => !_nonPointageMode && _type == 'mission';

  String get _dateDebutLabel {
    if (_type == 'mission') return 'Date de départ';
    if (_needsDateRange) return 'Date de début';
    return 'Date concernée';
  }

  String get _dateFinLabel => _type == 'mission' ? 'Date de retour' : 'Date de fin';

  String get _allaitementHeureLabel =>
      _allaitementSens == 'sortie' ? 'Heure de sortie *' : 'Heure d’entrée *';

  @override
  void initState() {
    super.initState();
    _nonPointageMode = widget.nonPointageMode;
    if (widget.initialDate != null) {
      _dateDebut = widget.initialDate!;
    }
    if (widget.initialType != null && widget.initialType!.isNotEmpty) {
      final t = widget.initialType!;
      _type = switch (t) {
        'retard' => 'permission_exceptionnelle',
        'conge' => 'conge_annuel',
        _ => t,
      };
    }
    if (_nonPointageMode) {
      _type = 'regularisation';
      _pointageManquant = widget.pointageManquant;
      _applyNonPointageMotif();
    }
    _load();
  }

  void _applyNonPointageMotif() {
    if (_pointageManquant == 'entree') {
      _motifCtrl.text = 'Non pointage — entrée';
    } else if (_pointageManquant == 'sortie') {
      _motifCtrl.text = 'Non pointage — sortie';
    } else if (_motifCtrl.text.trim().isEmpty) {
      _motifCtrl.text = 'Non pointage';
    }
  }

  @override
  void dispose() {
    _motifCtrl.dispose();
    _commentCtrl.dispose();
    _lieuCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDateApi(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final mois =
          '${_dateDebut.year.toString().padLeft(4, '0')}-${_dateDebut.month.toString().padLeft(2, '0')}';
      final res = await dio.get<Map<String, dynamic>>(
        ApiEndpoints.declarations,
        queryParameters: {'mois': mois},
      );
      final data = res.data?['data'];
      final apiTypes = res.data?['types'];
      final parsedTypes = apiTypes is List
          ? apiTypes
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((t) => t['value']?.toString() != 'regularisation')
              .toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _items = data is List
            ? data
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
        _types = parsedTypes.isNotEmpty
            ? parsedTypes
            : List<Map<String, dynamic>>.from(_fallbackTypes);
      });
    } catch (e) {
      setState(() {
        _error = mapDioException(e).message;
        _types = List<Map<String, dynamic>>.from(_fallbackTypes);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool fin}) async {
    final initial = fin ? (_dateFin ?? _dateDebut) : _dateDebut;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (fin) {
        _dateFin = picked;
      } else {
        _dateDebut = picked;
        if (_dateFin != null && _dateFin!.isBefore(_dateDebut)) {
          _dateFin = _dateDebut;
        }
      }
    });
  }

  Future<void> _pickTime({required bool fin}) async {
    final initial = fin
        ? (_heureFin ?? const TimeOfDay(hour: 9, minute: 0))
        : (_heureDebut ?? const TimeOfDay(hour: 8, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (fin) {
        _heureFin = picked;
      } else {
        _heureDebut = picked;
      }
    });
  }

  Future<void> _takePhoto() async {
    final x = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (x == null) return;
    setState(() {
      _justificatifPath = x.path;
      _justificatifName = x.name;
    });
  }

  Future<void> _pickGallery() async {
    final x = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (x == null) return;
    setState(() {
      _justificatifPath = x.path;
      _justificatifName = x.name;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final file = result?.files.single;
    if (file?.path == null) return;
    setState(() {
      _justificatifPath = file!.path;
      _justificatifName = file.name;
    });
  }

  Future<void> _submit() async {
    final motif = _motifCtrl.text.trim();
    if (motif.isEmpty) {
      showAppToast(context, 'Le motif est obligatoire.', type: ToastType.error);
      return;
    }
    if (_nonPointageMode && (_pointageManquant != 'entree' && _pointageManquant != 'sortie')) {
      showAppToast(
        context,
        'Indiquez le pointage manquant (entrée ou sortie).',
        type: ToastType.error,
      );
      return;
    }
    if (_needsDateRange && _dateFin == null) {
      showAppToast(context, 'La date de fin est obligatoire.', type: ToastType.error);
      return;
    }
    if (_needsHeures &&
        !_nonPointageMode &&
        (_heureDebut == null || _heureFin == null)) {
      showAppToast(
        context,
        'Heure début et fin obligatoires pour une permission exceptionnelle.',
        type: ToastType.error,
      );
      return;
    }
    if (_needsAllaitement && _heureDebut == null) {
      showAppToast(
        context,
        _allaitementSens == 'sortie'
            ? 'Indiquez l’heure de sortie autorisée.'
            : 'Indiquez l’heure d’entrée autorisée.',
        type: ToastType.error,
      );
      return;
    }
    if (_nonPointageMode && _pointageManquant == 'entree' && _heureDebut == null) {
      showAppToast(context, 'Indiquez l’heure d’entrée déclarée.', type: ToastType.error);
      return;
    }
    if (_nonPointageMode && _pointageManquant == 'sortie' && _heureFin == null) {
      showAppToast(context, 'Indiquez l’heure de sortie déclarée.', type: ToastType.error);
      return;
    }
    if (_needsLieu && _lieuCtrl.text.trim().isEmpty) {
      showAppToast(context, 'Le lieu est obligatoire pour une mission.', type: ToastType.error);
      return;
    }

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final map = <String, dynamic>{
        'type': _type,
        'date_concernee': _fmtDateApi(_dateDebut),
        'motif': motif,
        if (_commentCtrl.text.trim().isNotEmpty) 'commentaire': _commentCtrl.text.trim(),
        if (_needsDateRange && _dateFin != null) 'date_fin': _fmtDateApi(_dateFin!),
        if (_needsAllaitement) ...{
          'sens': _allaitementSens,
          if (_heureDebut != null) 'heure_debut': _fmtTime(_heureDebut!),
        } else ...{
          if (_heureDebut != null) 'heure_debut': _fmtTime(_heureDebut!),
          if (_heureFin != null) 'heure_fin': _fmtTime(_heureFin!),
        },
        if (_needsLieu) 'lieu': _lieuCtrl.text.trim(),
      };

      if (_justificatifPath != null) {
        map['justificatif'] = await MultipartFile.fromFile(
          _justificatifPath!,
          filename: _justificatifName ?? File(_justificatifPath!).uri.pathSegments.last,
        );
      }

      final res = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.declarations,
        data: FormData.fromMap(map),
      );

      _motifCtrl.clear();
      _commentCtrl.clear();
      _lieuCtrl.clear();
      setState(() {
        _dateFin = null;
        _heureDebut = null;
        _heureFin = null;
        _justificatifPath = null;
        _justificatifName = null;
      });

      final msg = res.data?['message']?.toString() ?? 'Déclaration envoyée.';
      if (mounted) {
        showAppToast(context, msg, type: ToastType.success);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        showAppToast(context, mapDioException(e).message, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeItems = (_types.isEmpty ? _fallbackTypes : _types)
        .map(
          (t) => DropdownMenuItem<String>(
            value: t['value']?.toString() ?? '',
            child: Text(t['label']?.toString() ?? t['value']?.toString() ?? ''),
          ),
        )
        .where((e) => e.value!.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_nonPointageMode ? 'Régularisation pointage' : 'Déclarations'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                    ),
                  Text(
                    _nonPointageMode
                        ? 'Déclarer un non-pointage'
                        : 'Nouvelle déclaration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_nonPointageMode) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Régularisation d’une entrée ou sortie manquante — validation N+1 puis RH.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  if (_nonPointageMode) ...[
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        'Régularisation',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      value: _pointageManquant,
                      decoration: const InputDecoration(
                        labelText: 'Pointage manquant *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'entree', child: Text('Entrée')),
                        DropdownMenuItem(value: 'sortie', child: Text('Sortie')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _pointageManquant = v;
                          if (v == 'entree') {
                            _heureFin = null;
                          } else if (v == 'sortie') {
                            _heureDebut = null;
                          }
                          _applyNonPointageMotif();
                        });
                      },
                    ),
                  ] else
                    DropdownButtonFormField<String>(
                      value: typeItems.any((e) => e.value == _type) ? _type : typeItems.first.value,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: typeItems,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _type = v;
                          if (!_needsDateRange) _dateFin = null;
                          if (!_needsHeures && !_needsAllaitement) {
                            _heureDebut = null;
                            _heureFin = null;
                          }
                          if (_needsAllaitement) {
                            _heureFin = null;
                            _allaitementSens = 'entree';
                          }
                          if (!_needsLieu) _lieuCtrl.clear();
                        });
                      },
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_dateDebutLabel),
                    subtitle: Text(_fmtDate(_dateDebut)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _nonPointageMode ? null : () => _pickDate(fin: false),
                  ),
                  if (_needsDateRange)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_dateFinLabel),
                      subtitle: Text(_dateFin == null ? 'Choisir…' : _fmtDate(_dateFin!)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _pickDate(fin: true),
                    ),
                  if (_needsAllaitement) ...[
                    DropdownButtonFormField<String>(
                      value: _allaitementSens,
                      decoration: const InputDecoration(
                        labelText: 'Sens horaire *',
                        border: OutlineInputBorder(),
                        helperText:
                            'Entrée : retard après heure + tolérance. Sortie : pointage ramené à 17:00.',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'entree', child: Text('Entrée')),
                        DropdownMenuItem(value: 'sortie', child: Text('Sortie')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _allaitementSens = v;
                          _heureFin = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_allaitementHeureLabel),
                      subtitle: Text(_heureDebut == null ? 'Choisir…' : _fmtTime(_heureDebut!)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _pickTime(fin: false),
                    ),
                  ],
                  if (_needsHeures && !_nonPointageMode) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Heure début *'),
                      subtitle: Text(_heureDebut == null ? 'Choisir…' : _fmtTime(_heureDebut!)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _pickTime(fin: false),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Heure fin *'),
                      subtitle: Text(_heureFin == null ? 'Choisir…' : _fmtTime(_heureFin!)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _pickTime(fin: true),
                    ),
                  ],
                  if (_nonPointageMode && _pointageManquant == 'entree')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Heure d’entrée déclarée *'),
                      subtitle: Text(_heureDebut == null ? 'Choisir…' : _fmtTime(_heureDebut!)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _pickTime(fin: false),
                    ),
                  if (_nonPointageMode && _pointageManquant == 'sortie')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Heure de sortie déclarée *'),
                      subtitle: Text(_heureFin == null ? 'Choisir…' : _fmtTime(_heureFin!)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _pickTime(fin: true),
                    ),
                  if (_needsLieu) ...[
                    TextField(
                      controller: _lieuCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Lieu *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  TextField(
                    controller: _motifCtrl,
                    readOnly: _nonPointageMode,
                    decoration: const InputDecoration(
                      labelText: 'Motif *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Commentaire',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Justificatif (photo ou fichier)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galerie'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Fichier'),
                      ),
                      if (_justificatifName != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _justificatifPath = null;
                            _justificatifName = null;
                          }),
                          child: Text(
                            'Retirer ($_justificatifName)',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Envoyer',
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                  if (!_nonPointageMode) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Mes déclarations du mois',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_items.isEmpty)
                      const Text('Aucune déclaration pour ce mois.'),
                    ..._items.map((d) {
                      final typeLabel = d['type_label'] ?? d['type'] ?? '';
                      final debut = d['date_concernee'] ?? '';
                      final fin = d['date_fin'];
                      final periode = fin == null || '$fin'.isEmpty ? '$debut' : '$debut → $fin';
                      final lieu = d['lieu'];
                      String heures = '';
                      if (d['type'] == 'allaitement') {
                        final sens = d['sens'] == 'sortie' ? 'Sortie' : 'Entrée';
                        final h = d['heure'] ?? d['heure_debut'] ?? d['heure_fin'];
                        if (h != null) heures = ' ($sens $h)';
                      } else if (d['heure_debut'] != null && d['heure_fin'] != null) {
                        heures = ' (${d['heure_debut']}–${d['heure_fin']})';
                      }
                      return Card(
                        child: ListTile(
                          title: Text('$typeLabel — ${d['statut'] ?? ''}'),
                          subtitle: Text(
                            '$periode$heures\n${d['motif'] ?? ''}${lieu != null && '$lieu'.isNotEmpty ? '\nLieu : $lieu' : ''}${d['has_justificatif'] == true ? '\nJustificatif joint' : ''}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}
