import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'govuk_content.dart';
import 'govuk_focus.dart';
import 'govuk_theme.dart';
import 'govuk_tokens.dart';

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _text(BuildContext c) => _dark(c) ? GovukColours.darkText : GovukColours.text;
Color _error(BuildContext c) => _dark(c) ? GovukColours.darkError : GovukColours.error;

/// Wraps a form field in a GOV.UK form group: when [errorMessage] is set,
/// a 5px red left border and the error message above the control.
class GovukFormGroup extends StatelessWidget {
  const GovukFormGroup({super.key, required this.child, this.errorMessage});

  final Widget child;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null) return child;
    return Container(
      padding: const EdgeInsets.only(left: 15),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _error(context), width: GovukLayout.borderWidthFormGroupError)),
      ),
      child: child,
    );
  }
}

/// GOV.UK text input: label above (bold when [labelBold]), optional hint,
/// error message, 2px black border, yellow focus outline + 4px border.
class GovukTextInput extends StatelessWidget {
  const GovukTextInput({
    super.key,
    required this.label,
    this.hint,
    this.errorMessage,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autofocus = false,
    this.width,
    this.labelBold = false,
    this.labelSize = GovukHeadingSize.s,
    this.suffix,
    this.prefixText,
    this.suffixText,
    this.inputFormatters,
    this.enabled = true,
    this.maxLines = 1,
  });

  final String label;
  final String? hint;
  final String? errorMessage;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autofocus;

  /// Fixed width (GOV.UK width classes: 5.5em ≈ 110, 10 ≈ 220, 20 ≈ 400…).
  final double? width;
  final bool labelBold;

  /// Label as page heading (l/m) or regular (s).
  final GovukHeadingSize labelSize;
  final Widget? suffix;
  final String? prefixText;
  final String? suffixText;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final labelStyle = switch (labelSize) {
      GovukHeadingSize.xl => GovukType.style(context, GovukType.p48, bold: true, color: _text(context)),
      GovukHeadingSize.l => GovukType.style(context, GovukType.p36, bold: true, color: _text(context)),
      GovukHeadingSize.m => GovukType.style(context, GovukType.p24, bold: true, color: _text(context)),
      GovukHeadingSize.s => GovukType.style(context, GovukType.p19, bold: labelBold, color: _text(context)),
    };
    final hasError = errorMessage != null;
    final inputBorderColour = hasError ? _error(context) : (_dark(context) ? GovukColours.darkText : GovukColours.inputBorder);
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      enabled: enabled,
      maxLines: maxLines,
      style: GovukType.style(context, GovukType.p19, color: _text(context)),
      cursorColor: _text(context),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: inputBorderColour, width: 2),
        ),
        focusedBorder: GovukFocusedInputBorder(
            borderColor: _dark(context) ? GovukColours.darkText : GovukColours.inputBorder),
        suffixIcon: suffix,
        prefixText: prefixText,
        suffixText: suffixText,
      ),
    );
    return GovukFormGroup(
      errorMessage: errorMessage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(label, style: labelStyle)),
          if (hint != null) GovukHint(hint!, large: true),
          if (hasError) GovukErrorMessage(errorMessage!),
          Semantics(
            label: label,
            hint: [hint, if (hasError) 'Error: $errorMessage'].whereType<String>().join('. '),
            child: width == null ? field : SizedBox(width: width, child: field),
          ),
        ],
      ),
    );
  }
}

/// An option of [GovukRadios] / [GovukCheckboxes].
class GovukOption<T> {
  const GovukOption({required this.value, required this.label, this.hint});
  final T value;
  final String label;
  final String? hint;
}

/// GOV.UK fieldset legend + hint + error wrapper for choice controls.
class _Fieldset extends StatelessWidget {
  const _Fieldset({required this.legend, this.hint, this.errorMessage, required this.child, this.legendSize = GovukHeadingSize.m});

  final String legend;
  final String? hint;
  final String? errorMessage;
  final Widget child;
  final GovukHeadingSize legendSize;

  @override
  Widget build(BuildContext context) {
    final p = switch (legendSize) {
      GovukHeadingSize.xl => GovukType.p48,
      GovukHeadingSize.l => GovukType.p36,
      GovukHeadingSize.m => GovukType.p24,
      GovukHeadingSize.s => GovukType.p19,
    };
    return GovukFormGroup(
      errorMessage: errorMessage,
      child: Semantics(
        container: true,
        label: legend,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(legend, style: GovukType.style(context, p, bold: legendSize != GovukHeadingSize.s, color: _text(context))),
            ),
            if (hint != null) GovukHint(hint!, large: true),
            if (errorMessage != null) GovukErrorMessage(errorMessage!),
            child,
          ],
        ),
      ),
    );
  }
}

/// One 40px radio/checkbox box with a 44px touch target and GOV.UK focus
/// (4px border + 4px yellow ring).
class _ChoiceItem extends StatelessWidget {
  const _ChoiceItem({required this.label, this.hint, required this.selected, required this.onTap, required this.round, this.small = false});

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;
  final bool round;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final fg = _text(context);
    final size = small ? 24.0 : 40.0;
    return Semantics(
      checked: round ? null : selected,
      selected: round ? selected : null,
      inMutuallyExclusiveGroup: round,
      label: label,
      hint: hint,
      excludeSemantics: true,
      child: GovukFocusRing.builder(
        onTap: onTap,
        builder: (context, focused, hovered) {
          final box = Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              color: _dark(context) ? GovukColours.darkSurface : GovukColours.white,
              border: Border.all(color: fg, width: focused ? 4 : 2),
              boxShadow: [
                if (focused) const BoxShadow(color: GovukColours.focus, spreadRadius: 4),
                if (hovered && !focused) BoxShadow(color: GovukColours.hover.withValues(alpha: 0.9), spreadRadius: 6),
              ],
            ),
            alignment: Alignment.center,
            child: selected
                ? (round
                    ? Container(
                        width: small ? 10 : 20,
                        height: small ? 10 : 20,
                        decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                      )
                    : Icon(Icons.check_rounded, size: small ? 18 : 30, color: fg, weight: 900))
                : null,
          );
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GovukLayout.touchTarget),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: GovukLayout.touchTarget,
                  height: GovukLayout.touchTarget,
                  child: Center(child: box),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: small ? 11 : 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: GovukType.style(context, GovukType.p19, color: fg)),
                        if (hint != null) ...[const SizedBox(height: 3), GovukHint(hint!, large: true)],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// GOV.UK radios: legend, hint, error and large 40px radio buttons.
class GovukRadios<T> extends StatelessWidget {
  const GovukRadios({
    super.key,
    required this.legend,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.errorMessage,
    this.inline = false,
    this.small = false,
    this.legendSize = GovukHeadingSize.m,
  });

  final String legend;
  final List<GovukOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? hint;
  final String? errorMessage;
  final bool inline;
  final bool small;
  final GovukHeadingSize legendSize;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final o in options)
        Padding(
          padding: EdgeInsets.only(bottom: 10, right: inline ? 20 : 0),
          child: _ChoiceItem(
            label: o.label,
            hint: o.hint,
            selected: o.value == value,
            round: true,
            small: small,
            onTap: onChanged == null ? null : () => onChanged!(o.value),
          ),
        ),
    ];
    return _Fieldset(
      legend: legend,
      hint: hint,
      errorMessage: errorMessage,
      legendSize: legendSize,
      child: inline && GovukLayout.isTablet(context)
          ? Wrap(children: [for (final i in items) IntrinsicWidth(child: i)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

/// GOV.UK checkboxes: legend, hint, error and large 40px checkboxes.
class GovukCheckboxes<T> extends StatelessWidget {
  const GovukCheckboxes({
    super.key,
    required this.legend,
    required this.options,
    required this.values,
    required this.onChanged,
    this.hint,
    this.errorMessage,
    this.small = false,
    this.legendSize = GovukHeadingSize.m,
  });

  final String legend;
  final List<GovukOption<T>> options;
  final Set<T> values;
  final ValueChanged<Set<T>>? onChanged;
  final String? hint;
  final String? errorMessage;
  final bool small;
  final GovukHeadingSize legendSize;

  @override
  Widget build(BuildContext context) {
    return _Fieldset(
      legend: legend,
      hint: hint,
      errorMessage: errorMessage,
      legendSize: legendSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GovukCheckbox(
                label: o.label,
                hint: o.hint,
                value: values.contains(o.value),
                small: small,
                onChanged: onChanged == null
                    ? null
                    : (v) {
                        final next = {...values};
                        v ? next.add(o.value) : next.remove(o.value);
                        onChanged!(next);
                      },
              ),
            ),
        ],
      ),
    );
  }
}

/// A single GOV.UK checkbox (e.g. "I have checked the plan").
class GovukCheckbox extends StatelessWidget {
  const GovukCheckbox({super.key, required this.label, required this.value, required this.onChanged, this.hint, this.small = false});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? hint;
  final bool small;

  @override
  Widget build(BuildContext context) => _ChoiceItem(
        label: label,
        hint: hint,
        selected: value,
        round: false,
        small: small,
        onTap: onChanged == null ? null : () => onChanged!(!value),
      );
}
