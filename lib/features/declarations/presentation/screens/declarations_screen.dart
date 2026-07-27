import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../providers/app_providers.dart';
import '../../../../widgets/buttons/primary_button.dart';
import '../../../../widgets/feedback/app_toast.dart';

class DeclarationsScreen extends ConsumerStatefulWidget {
  const DeclarationsScreen({super.key});

  static const routePath = '/declarations';

  @override
  ConsumerState<DeclarationsScreen> createState() => _DeclarationsScreenState();
}

class _DeclarationsScreenState extends ConsumerState<DeclarationsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _items = [];
  String? _error;

  final _motifCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String _type = 'retard';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _motifCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final mois =
          '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}';
      final res = await dio.get<Map<String, dynamic>>(
        ApiEndpoints.declarations,
        queryParameters: {'mois': mois},
      );
      final data = res.data?['data'];
      setState(() {
        _items = data is List
            ? data
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
      });
    } catch (e) {
      setState(() => _error = mapDioException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final motif = _motifCtrl.text.trim();
    if (motif.isEmpty) {
      showAppToast(context, 'Le motif est obligatoire.', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post<Map<String, dynamic>>(
        ApiEndpoints.declarations,
        data: {
          'type': _type,
          'date_concernee':
              '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
          'motif': motif,
          'commentaire': _commentCtrl.text.trim().isEmpty
              ? null
              : _commentCtrl.text.trim(),
        },
      );
      _motifCtrl.clear();
      _commentCtrl.clear();
      if (mounted) {
        showAppToast(context, 'Déclaration envoyée.', type: ToastType.success);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Déclarations')),
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
                    'Nouvelle déclaration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'retard', child: Text('Retard')),
                      DropdownMenuItem(value: 'absence', child: Text('Absence')),
                      DropdownMenuItem(value: 'conge', child: Text('Congé')),
                      DropdownMenuItem(
                          value: 'regularisation', child: Text('Régularisation')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date concernée'),
                    subtitle: Text(
                      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  TextField(
                    controller: _motifCtrl,
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
                  PrimaryButton(
                    label: 'Envoyer',
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Mes déclarations du mois',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_items.isEmpty)
                    const Text('Aucune déclaration pour ce mois.'),
                  ..._items.map((d) {
                    return Card(
                      child: ListTile(
                        title: Text('${d['type'] ?? ''} — ${d['statut'] ?? ''}'),
                        subtitle: Text(
                          '${d['date_concernee'] ?? ''}\n${d['motif'] ?? ''}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
