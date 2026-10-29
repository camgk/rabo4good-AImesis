import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/onboarding_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/breadcrumbs.dart';
import '../../widgets/common.dart';
import '../../widgets/page_frame.dart';
import 'onboarding_page.dart';

const diagnosisGroups = {
  'ALL': 'ALL',
  'AML': 'AML',
  'lymphoma': 'Lymphoma',
  'solid': 'Solid tumour',
  'CNS': 'CNS tumour',
  'other': 'Other',
};

const familyLanguages = {'nl': 'Nederlands', 'fr': 'Français', 'en': 'English'};

/// `/patients/new` — patient onboarding: who the patient is. Saving creates
/// the profile; cycles are started from there. Also `/patients/:id/edit`
/// for patients created here.
class PatientFormPage extends StatefulWidget {
  const PatientFormPage({super.key, this.patientId});

  /// Null for a new patient.
  final String? patientId;

  @override
  State<PatientFormPage> createState() => _PatientFormPageState();
}

class _PatientFormPageState extends State<PatientFormPage> {
  final _form = GlobalKey<FormState>();
  late final PatientRecord? _existing =
      widget.patientId == null ? null : AppScope.read(context).onboarding.patient(widget.patientId!);
  late final PatientProfile _pr = _existing?.profile ?? PatientProfile();

  late final _alias = TextEditingController(text: _pr.alias);
  late final _age = TextEditingController(text: _pr.age?.toString() ?? '');
  late final _diagnosis = TextEditingController(text: _pr.diagnosis);
  late final _formulation = TextEditingController(text: _pr.formulationPreference);
  late final _helps = TextEditingController(text: _pr.whatHelps);
  late String? _sex = _pr.sex;
  late String _language = _pr.language;
  late String? _group = _pr.diagnosisGroup;
  bool _tried = false;

  @override
  void dispose() {
    for (final c in [_alias, _age, _diagnosis, _formulation, _helps]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    setState(() => _tried = true);
    if (!(_form.currentState?.validate() ?? false)) return;
    final app = AppScope.read(context);
    final profile = (_existing?.profile ?? PatientProfile())
      ..alias = _alias.text.trim()
      ..age = int.tryParse(_age.text.trim())
      ..sex = _sex
      ..language = _language
      ..diagnosis = _diagnosis.text.trim()
      ..diagnosisGroup = _group
      ..formulationPreference = _formulation.text.trim()
      ..whatHelps = _helps.text.trim();
    final PatientRecord rec;
    if (_existing != null) {
      rec = _existing;
      // A changed profile (e.g. age) makes open suggestions out of date.
      for (final c in rec.cycles.where((c) => !c.isSent)) {
        c.touchInputs();
      }
      app.onboarding.save(rec);
    } else {
      rec = app.onboarding.createPatient(profile, createdBy: app.account?.displayName ?? '');
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(_existing == null ? '${rec.displayName} added' : 'Profile saved'),
    ));
    context.go('/patients/${rec.id}');
  }

  @override
  Widget build(BuildContext context) {
    final editing = _existing != null;
    if (widget.patientId != null && _existing == null) {
      return const EmptyView(icon: Icons.person_search_outlined, title: 'Patient not found');
    }
    return PageFrame(
      title: editing ? 'Edit ${_existing.displayName}' : 'New patient',
      subtitle: editing
          ? 'Changes apply to every cycle'
          : 'Patient details only · chemotherapy is added per cycle from the profile',
      maxWidth: 900,
      breadcrumbs: [
        const Crumb('Patients', '/patients'),
        if (editing) Crumb(_existing.displayName, '/patients/${_existing.id}'),
        Crumb(editing ? 'Edit' : 'New patient'),
      ],
      children: [
        Form(
          key: _form,
          autovalidateMode: _tried ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionCard(
              title: 'Patient',
              subtitle: 'Use a pseudonym or initials, not the full name',
              icon: Icons.person_outline_rounded,
              child: Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.end, children: [
                FieldSlot(
                  child: TextFormField(
                    key: const Key('field-alias'),
                    controller: _alias,
                    decoration: const InputDecoration(labelText: 'Alias', hintText: 'e.g. Casus 5'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
                FieldSlot(
                  width: 120,
                  child: TextFormField(
                    key: const Key('field-age'),
                    controller: _age,
                    decoration: const InputDecoration(labelText: 'Age', suffixText: 'yrs'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Required';
                      return n > 25 ? 'Up to 25' : null;
                    },
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sex', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'F', label: Text('Female')),
                      ButtonSegment(value: 'M', label: Text('Male')),
                    ],
                    selected: _sex == null ? const <String>{} : {_sex!},
                    onSelectionChanged: (s) => setState(() => _sex = s.isEmpty ? null : s.first),
                  ),
                ]),
                FieldSlot(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _language,
                    decoration: const InputDecoration(labelText: 'Family language'),
                    items: [for (final e in familyLanguages.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => setState(() => _language = v ?? 'nl'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Diagnosis',
              icon: Icons.assignment_outlined,
              child: Wrap(spacing: 16, runSpacing: 16, children: [
                FieldSlot(
                  width: 320,
                  child: TextFormField(
                    key: const Key('field-diagnosis'),
                    controller: _diagnosis,
                    decoration: const InputDecoration(labelText: 'Diagnosis', hintText: 'e.g. Ewing sarcoma'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
                FieldSlot(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _group,
                    decoration: const InputDecoration(labelText: 'Diagnosis group'),
                    items: [for (final e in diagnosisGroups.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => setState(() => _group = v),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Preferences',
              subtitle: 'Optional · can also be filled in during a cycle’s patient session',
              icon: Icons.favorite_border_rounded,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _formulation,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Formulation and taste',
                    hintText: 'e.g. prefers liquid, dislikes mint flavour',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _helps,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'What helps, what to avoid',
                    hintText: 'e.g. small cold meals, no strong smells',
                  ),
                ),
              ]),
            ),
            StepFooter(
              back: TextButton(
                onPressed: () => context.go(editing ? '/patients/${_existing.id}' : '/patients'),
                child: const Text('Cancel'),
              ),
              primary: FilledButton.icon(
                key: const Key('save-patient'),
                onPressed: _submit,
                icon: Icon(editing ? Icons.check_rounded : Icons.person_add_alt_1_rounded),
                label: Text(editing ? 'Save profile' : 'Create patient'),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
