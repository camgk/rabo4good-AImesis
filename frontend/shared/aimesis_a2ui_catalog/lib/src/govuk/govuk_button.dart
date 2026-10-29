import 'package:flutter/material.dart';

import 'govuk_focus.dart';
import 'govuk_tokens.dart';

enum GovukButtonVariant { primary, secondary, warning, start, inverse }

/// GOV.UK button with the AImesis brand layer: square, 2px solid bottom
/// shadow, moves down 2px when pressed, yellow focus with black underline.
///
/// * primary: brand blue #426A92, white text, #2B4A6B shadow
/// * secondary: light grey, black text
/// * warning: red #D4351C; use sparingly and add a confirmation step
/// * start: primary, bold 24px, with arrow
/// * inverse: white on dark backgrounds
class GovukButton extends StatefulWidget {
  const GovukButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GovukButtonVariant.primary,
    this.icon,
    this.fullWidth = false,
    this.large = false,
    this.busy = false,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
  });

  const GovukButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.large = false,
    this.busy = false,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
  }) : variant = GovukButtonVariant.secondary;

  const GovukButton.warning({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.large = false,
    this.busy = false,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
  }) : variant = GovukButtonVariant.warning;

  const GovukButton.start({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.large = false,
    this.busy = false,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
  })  : variant = GovukButtonVariant.start,
        icon = null;

  final String label;
  final VoidCallback? onPressed;
  final GovukButtonVariant variant;
  final IconData? icon;

  /// Stretch to the available width (GOV.UK buttons are full width on phones).
  final bool fullWidth;

  /// 64px tall touch target for one-tap mobile actions.
  final bool large;

  /// Shows a small spinner and ignores taps (prevents double submission).
  final bool busy;
  final String? semanticLabel;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<GovukButton> createState() => _GovukButtonState();
}

class _GovukButtonState extends State<GovukButton> {
  bool _pressed = false;

  ({Color bg, Color hover, Color fg, Color shadow}) _colours(bool dark) {
    switch (widget.variant) {
      case GovukButtonVariant.primary:
      case GovukButtonVariant.start:
        return dark
            ? (
                bg: GovukColours.brandOnDark,
                hover: const Color(0xFFB4CDE3),
                fg: GovukColours.black,
                shadow: GovukColours.brandTint
              )
            : (
                bg: GovukColours.brand,
                hover: GovukColours.brandHover,
                fg: GovukColours.white,
                shadow: GovukColours.brandDark
              );
      case GovukButtonVariant.secondary:
        return dark
            ? (
                bg: GovukColours.darkSurfaceHigh,
                hover: const Color(0xFF2E4560),
                fg: GovukColours.white,
                shadow: GovukColours.darkBorder
              )
            : (
                bg: GovukColours.secondaryButton,
                hover: GovukColours.secondaryButtonHover,
                fg: GovukColours.black,
                shadow: GovukColours.secondaryButtonShadow
              );
      case GovukButtonVariant.warning:
        return dark
            ? (
                bg: GovukColours.darkError,
                hover: const Color(0xFFF5A99E),
                fg: GovukColours.black,
                shadow: const Color(0xFF8C2A1C)
              )
            : (
                bg: GovukColours.warningButton,
                hover: GovukColours.warningButtonHover,
                fg: GovukColours.white,
                shadow: GovukColours.warningButtonShadow
              );
      case GovukButtonVariant.inverse:
        return (
          bg: GovukColours.white,
          hover: GovukColours.brandTintLight,
          fg: GovukColours.brandDark,
          shadow: GovukColours.brandDark
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = _colours(dark);
    final enabled = widget.onPressed != null && !widget.busy;
    final start = widget.variant == GovukButtonVariant.start;
    final base = GovukType.style(context, start ? GovukType.p24 : GovukType.p19, bold: start);

    return Opacity(
      opacity: widget.onPressed == null ? 0.5 : 1,
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GovukFocusRing.builder(
          onTap: enabled ? widget.onPressed : null,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          semanticLabel: widget.semanticLabel,
          mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          builder: (context, focused, hovered) {
            final showFocus = focused && !_pressed && !hovered;
            final bg = showFocus ? GovukColours.focus : (hovered && enabled ? c.hover : c.bg);
            final fg = showFocus ? GovukColours.focusText : c.fg;
            final shadow = showFocus ? GovukColours.focusText : c.shadow;
            final children = <Widget>[
              if (widget.busy) ...[
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                const SizedBox(width: 10),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: base.copyWith(color: fg, height: 1.1),
                ),
              ),
              if (start) ...[
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 26, color: fg),
              ],
            ];
            final minHeight = widget.large ? GovukLayout.touchTargetLarge : GovukLayout.touchTarget;
            return Padding(
              // Reserve the shadow height; when pressed the face moves down.
              padding: EdgeInsets.only(
                top: _pressed ? GovukLayout.buttonShadow : 0,
                bottom: _pressed ? 0 : GovukLayout.buttonShadow,
              ),
              child: Container(
                constraints: BoxConstraints(minHeight: minHeight - GovukLayout.buttonShadow),
                width: widget.fullWidth ? double.infinity : null,
                padding: EdgeInsets.symmetric(horizontal: start ? 20 : 15, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  border: focused ? Border.all(color: GovukColours.focus, width: 2) : null,
                  boxShadow: _pressed
                      ? null
                      : [BoxShadow(color: shadow, offset: const Offset(0, GovukLayout.buttonShadow))],
                ),
                child: Row(
                  mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lays buttons (and links) out with GOV.UK button-group spacing: in a row
/// that wraps on wide screens, stacked full-width on phones.
class GovukButtonGroup extends StatelessWidget {
  const GovukButtonGroup({super.key, required this.children, this.stackOnMobile = true});

  final List<Widget> children;
  final bool stackOnMobile;

  @override
  Widget build(BuildContext context) {
    if (stackOnMobile && !GovukLayout.isTablet(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: GovukSpacing.s3),
            children[i],
          ],
        ],
      );
    }
    return Wrap(
      spacing: GovukSpacing.s3,
      runSpacing: GovukSpacing.s3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
