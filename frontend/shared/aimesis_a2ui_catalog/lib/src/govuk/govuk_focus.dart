import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'govuk_tokens.dart';

/// Builds a child that knows whether it has keyboard focus.
typedef GovukFocusBuilder = Widget Function(BuildContext context, bool focused, bool hovered);

/// Makes any widget focusable and activatable (Enter / Space / tap) and gives
/// it the GOV.UK focus style: yellow #FFDD00 background with a 4px black
/// #0B0C0C underline (links) or a 3px yellow outline (boxed controls).
///
/// Use [GovukFocusRing.builder] to restyle the child yourself when focused.
class GovukFocusRing extends StatefulWidget {
  const GovukFocusRing({
    super.key,
    required this.child,
    this.onTap,
    this.outline = false,
    this.semanticLabel,
    this.isButton = true,
    this.autofocus = false,
    this.focusNode,
    this.mouseCursor,
  }) : builder = null;

  const GovukFocusRing.builder({
    super.key,
    required GovukFocusBuilder this.builder,
    this.onTap,
    this.semanticLabel,
    this.isButton = true,
    this.autofocus = false,
    this.focusNode,
    this.mouseCursor,
  })  : child = null,
        outline = false;

  final Widget? child;
  final GovukFocusBuilder? builder;
  final VoidCallback? onTap;

  /// true: 3px yellow outline (boxed controls). false: yellow background +
  /// black underline (link style).
  final bool outline;
  final String? semanticLabel;
  final bool isButton;
  final bool autofocus;
  final FocusNode? focusNode;
  final MouseCursor? mouseCursor;

  @override
  State<GovukFocusRing> createState() => _GovukFocusRingState();
}

class _GovukFocusRingState extends State<GovukFocusRing> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final Widget content = widget.builder != null
        ? widget.builder!(context, _focused, _hovered)
        : _decorate(widget.child!);
    return Semantics(
      button: widget.isButton && enabled,
      link: !widget.isButton && enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        mouseCursor: enabled ? (widget.mouseCursor ?? SystemMouseCursors.click) : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: content,
        ),
      ),
    );
  }

  Widget _decorate(Widget child) {
    if (!_focused) return child;
    if (widget.outline) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: GovukColours.focus, width: GovukLayout.focusWidth),
        ),
        child: child,
      );
    }
    return GovukFocusedText(child: child);
  }
}

/// The GOV.UK "focused text" style: yellow background, black text, 4px black
/// underline. Wrap link-like content in it while it has keyboard focus.
class GovukFocusedText extends StatelessWidget {
  const GovukFocusedText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: GovukColours.focus,
        border: Border(bottom: BorderSide(color: GovukColours.focusText, width: 4)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: GovukColours.focusText, decoration: TextDecoration.none),
        child: IconTheme.merge(data: const IconThemeData(color: GovukColours.focusText), child: child),
      ),
    );
  }
}

/// An inline GOV.UK link: underlined link colour, visited/hover colours and
/// the yellow focus state.
class GovukLink extends StatelessWidget {
  const GovukLink(this.text, {super.key, required this.onTap, this.style, this.noVisited = true});

  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;
  final bool noVisited;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    return GovukFocusRing.builder(
      onTap: onTap,
      isButton: false,
      builder: (context, focused, hovered) {
        final colour = focused
            ? GovukColours.focusText
            : hovered
                ? (dark ? GovukColours.darkLinkHover : GovukColours.linkHover)
                : (dark ? GovukColours.darkLink : GovukColours.link);
        final t = Text(
          text,
          style: base?.copyWith(
            color: colour,
            decoration: focused ? TextDecoration.none : TextDecoration.underline,
            decorationColor: colour,
            decorationThickness: hovered ? 3 : 1.5,
          ),
        );
        return focused ? GovukFocusedText(child: t) : t;
      },
    );
  }
}
