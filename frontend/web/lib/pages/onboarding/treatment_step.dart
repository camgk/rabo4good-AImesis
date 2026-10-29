import 'dart:convert';

import 'package:aimesis_client/aimesis_client.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../onboarding/onboarding_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/common.dart';
import 'onboarding_page.dart';
import 'patient_form_page.dart' show familyLanguages;

const _knownDrugs = [
  'asparaginase', 'busulfan', 'carboplatin', 'cisplatin', 'cyclophosphamide', 'cytarabine',
  'dactinomycin', 'daunorubicin', 'doxorubicin', 'etoposide', 'ifosfamide', 'irinotecan',
  'melphalan', 'mercaptopurine', 'methotrexate', 'temozolomide', 'thiotepa', 'topotecan',
  'vinblastine', 'vincristine',
];

/// Step 1 — the doctor prepares this cycle's chemotherapy. Patient details
/// come from the profile and are not edited here.
class TreatmentStep extends StatefulWidget {
  const TreatmentStep({super.key, required this.cycleRef});
  final CycleRef cycleRef;

  @override
  State<TreatmentStep> createState() => _TreatmentStepState();
}

class _ChemoCtl {
  _ChemoCtl([ChemoRow? r])
      : drug = TextEditingController(text: r?.drug ?? ''),
        dose = TextEditingController(text: r == null || r.doseMgM2 == 0 ? '' : fmtNum(r.doseMgM2, decimals: 2)),
        days = TextEditingController(text: r == null ? '' : daysText(r.days)),
        focus = FocusNode();

  final TextEditingController drug, dose, days;
  final FocusNode focus;

  bool get isBlank => drug.text.trim().isEmpty && dose.text.trim().isEmpty && days.text.trim().isEmpty;

  ChemoRow? toRow() {
    final d = double.tryParse(dose.text.trim().replaceAll(',', '.'));
    final ds = parseDays(days.text);
    if (drug.text.trim().isEmpty || d == null || d <= 0 || ds == null) return null;
    return ChemoRow(drug: drug.text.trim().toLowerCase(), doseMgM2: d, days: ds);
  }

  void dispose() {
    drug.dispose();
    dose.dispose();
    days.dispose();
    focus.dispose();
  }
}

class _TreatmentStepState extends State<TreatmentStep> {
  final _form = GlobalKey<FormState>();
  late final PatientRecord _p = widget.cycleRef.patient;
  late final CycleRecord _c = widget.cycleRef.cycle;
  late final PatientProfile _pr = _p.profile;
  late final CycleIntake _i = _c.intake;

  /// No cycles before this one on the profile: ask whether it is the
  /// patient's first chemotherapy at all.
  late final bool _noHistory = _p.imported.isEmpty && _p.before(_c).isEmpty;
  late final CycleIntake? _last = _p.before(_c).lastOrNull?.intake;

  late final _weight = TextEditingController(text: _i.weightKg == null ? '' : fmtNum(_i.weightKg!));
  late final _height = TextEditingController(text: _i.heightCm == null ? '' : fmtNum(_i.heightCm!));
  late final _protocol = TextEditingController(text: _i.protocol);
  late final _cycle = TextEditingController(text: _i.cycle);
  final _med = TextEditingController();

  late DateTime? _cycleStart = _i.cycleStart;
  late bool _firstCycle = _i.firstCycle;
  late final List<String> _meds = [..._i.activeMeds];
  late final List<_ChemoCtl> _chemo = _i.chemo.isEmpty ? [_ChemoCtl()] : [for (final r in _i.chemo) _ChemoCtl(r)];

  bool _triedContinue = false;

  @override
  void dispose() {
    for (final c in [_weight, _height, _protocol, _cycle, _med]) {
      c.dispose();
    }
    for (final c in _chemo) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Writes the form into the cycle. True when the inputs changed.
  bool _writeBack() {
    final before = jsonEncode(_i.toJson());
    _i
      ..weightKg = _num(_weight)
      ..heightCm = _num(_height)
      ..protocol = _protocol.text.trim()
      ..cycle = _cycle.text.trim()
      ..cycleStart = _cycleStart
      ..firstCycle = _firstCycle
      ..activeMeds = [..._meds]
      ..chemo = [for (final c in _chemo) c.toRow()].whereType<ChemoRow>().toList();
    return jsonEncode(_i.toJson()) != before;
  }

  void _save({required bool advance}) {
    final store = AppScope.read(context).onboarding;
    final c = _c;
    if (advance) {
      setState(() => _triedContinue = true);
      final chemoOk = _chemo.any((c) => !c.isBlank) && _chemo.every((c) => c.isBlank || c.toRow() != null);
      if (!(_form.currentState?.validate() ?? false) || !chemoOk) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Some details are missing or need checking.'),
        ));
        return;
      }
    }
    if (_writeBack()) c.touchInputs();
    if (advance && c.stage.index < OnboardingStage.session.index) c.stage = OnboardingStage.session;
    store.save(_p, c);
    context.go(advance ? OnboardingPage.path(c.id, OnboardingStage.session) : '/patients/${_p.id}');
  }

  String? _range(String? v, num min, num max, {bool integer = false}) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = integer ? int.tryParse(v.trim()) : double.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null) return 'Enter a number';
    if (n < min || n > max) return 'Between ${fmtNum(min)} and ${fmtNum(max)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      autovalidateMode: _triedContinue ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _profileSummary(context),
        const SizedBox(height: 16),
        _cycleCard(context),
        const SizedBox(height: 16),
        _chemoCard(context),
        const SizedBox(height: 16),
        _medsCard(context),
        StepFooter(
          back: TextButton(onPressed: () => _save(advance: false), child: const Text('Save and exit')),
          primary: FilledButton.icon(
            key: const Key('onboarding-continue'),
            onPressed: () => _save(advance: true),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue to patient session'),
          ),
        ),
      ]),
    );
  }

  /// The patient this cycle belongs to, from the profile.
  Widget _profileSummary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sex = switch (_pr.sex) { 'F' => 'female', 'M' => 'male', _ => null };
    final previous = _p.cycleCount - _p.cycles.length + _p.before(_c).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        Icon(Icons.badge_outlined, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              [_pr.alias, if (_pr.age != null) '${_pr.age} yrs', if (sex != null) sex].join(' · '),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              [if (_pr.diagnosis.isNotEmpty) _pr.diagnosis, familyLanguages[_pr.language] ?? _pr.language,
                '$previous previous cycle${previous == 1 ? '' : 's'} on the profile'].join(' · '),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _cycleCard(BuildContext context) {
    final start = _cycleStart;
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final lastW = _last?.weightKg, lastH = _last?.heightCm;
    return SectionCard(
      title: 'This cycle',
      subtitle: _last == null
          ? 'Protocol, dates and measurements for this cycle'
          : 'Carried over from the previous cycle · measure weight and height again',
      icon: Icons.event_repeat_outlined,
      child: Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FieldSlot(
          width: 150,
          child: TextFormField(
            key: const Key('field-weight'),
            controller: _weight,
            decoration: InputDecoration(
              labelText: 'Weight',
              suffixText: 'kg',
              helperText: lastW == null ? null : 'Last: ${fmtNum(lastW)} kg',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: digits,
            validator: (v) => _range(v, 1, 200),
          ),
        ),
        FieldSlot(
          width: 150,
          child: TextFormField(
            key: const Key('field-height'),
            controller: _height,
            decoration: InputDecoration(
              labelText: 'Height',
              suffixText: 'cm',
              helperText: lastH == null ? null : 'Last: ${fmtNum(lastH)} cm',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: digits,
            validator: (v) => _range(v, 30, 220),
          ),
        ),
        FieldSlot(
          width: 300,
          child: TextFormField(
            controller: _protocol,
            decoration: const InputDecoration(labelText: 'Protocol', hintText: 'e.g. iEuroEwing · IE'),
          ),
        ),
        FieldSlot(
          width: 140,
          child: TextFormField(
            key: const Key('field-cycle'),
            controller: _cycle,
            decoration: InputDecoration(labelText: 'Cycle', hintText: 'e.g. ${_p.numberOf(_c)}'),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: start ?? now,
              firstDate: now.subtract(const Duration(days: 60)),
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _cycleStart = picked);
          },
          icon: const Icon(Icons.event_outlined),
          label: Text(start == null ? 'Cycle start date' : 'Starts ${DateFormat('d MMM yyyy').format(start)}'),
        ),
        if (_noHistory)
          FieldSlot(
            width: 320,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('First chemotherapy cycle'),
              value: _firstCycle,
              onChanged: (v) => setState(() => _firstCycle = v),
            ),
          ),
      ]),
    );
  }

  Widget _chemoCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final noRows = _triedContinue && !_chemo.any((c) => !c.isBlank);
    return SectionCard(
      title: 'Chemotherapy',
      subtitle: 'One row per drug · days like "1-3" or "1, 8, 15"',
      icon: Icons.science_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < _chemo.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FieldSlot(width: 260, child: _drugField(i)),
              FieldSlot(
                width: 150,
                child: TextFormField(
                  key: Key('chemo-dose-$i'),
                  controller: _chemo[i].dose,
                  decoration: const InputDecoration(labelText: 'Dose', suffixText: 'mg/m²'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  validator: (v) {
                    if (_chemo[i].isBlank) return null;
                    final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                    return (n == null || n <= 0) ? 'Enter a dose' : null;
                  },
                ),
              ),
              FieldSlot(
                width: 170,
                child: TextFormField(
                  key: Key('chemo-days-$i'),
                  controller: _chemo[i].days,
                  decoration: const InputDecoration(labelText: 'Days', hintText: '1-3'),
                  validator: (v) {
                    if (_chemo[i].isBlank) return null;
                    return parseDays(v ?? '') == null ? 'e.g. 1-3 or 1, 8' : null;
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove drug',
                onPressed: _chemo.length == 1
                    ? null
                    : () => setState(() => _chemo.removeAt(i).dispose()),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
            ]),
          ),
        if (noRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Add at least one chemotherapy drug.', style: TextStyle(color: cs.error, fontSize: 12.5)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _chemo.add(_ChemoCtl())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add drug'),
          ),
        ),
      ]),
    );
  }

  Widget _drugField(int i) {
    final c = _chemo[i];
    return RawAutocomplete<String>(
      textEditingController: c.drug,
      focusNode: c.focus,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return _knownDrugs.where((d) => d.startsWith(q) && d != q);
      },
      fieldViewBuilder: (context, ctl, focus, onSubmit) => TextFormField(
        key: Key('chemo-drug-$i'),
        controller: ctl,
        focusNode: focus,
        decoration: const InputDecoration(labelText: 'Drug'),
        onFieldSubmitted: (_) => onSubmit(),
        validator: (v) => !c.isBlank && (v ?? '').trim().isEmpty ? 'Enter the drug' : null,
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 260),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _medsCard(BuildContext context) {
    void add() {
      final v = _med.text.trim().toLowerCase();
      if (v.isEmpty || _meds.contains(v)) return;
      setState(() {
        _meds.add(v);
        _med.clear();
      });
    }

    return SectionCard(
      title: 'Other medications',
      subtitle: 'Used for the interaction check',
      icon: Icons.medication_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_meds.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in _meds) InputChip(label: Text(m), onDeleted: () => setState(() => _meds.remove(m))),
          ]),
          const SizedBox(height: 12),
        ],
        Row(children: [
          FieldSlot(
            width: 260,
            child: TextField(
              controller: _med,
              decoration: const InputDecoration(labelText: 'Add medication', hintText: 'e.g. voriconazole'),
              onSubmitted: (_) => add(),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: add, child: const Text('Add')),
        ]),
      ]),
    );
  }
}
