import 'package:flutter/material.dart';

import 'govuk_focus.dart';
import 'govuk_tag.dart';
import 'govuk_tokens.dart';

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _text(BuildContext c) => _dark(c) ? GovukColours.darkText : GovukColours.text;
Color _secondary(BuildContext c) => _dark(c) ? GovukColours.darkSecondaryText : GovukColours.secondaryText;
Color _border(BuildContext c) => _dark(c) ? GovukColours.darkBorder : GovukColours.border;
Color _error(BuildContext c) => _dark(c) ? GovukColours.darkError : GovukColours.error;
Color _success(BuildContext c) => _dark(c) ? GovukColours.darkSuccess : GovukColours.success;
Color _surface(BuildContext c) => _dark(c) ? GovukColours.darkSurface : GovukColours.bodyBackground;

TextStyle _body(BuildContext c, {bool bold = false, Color? color}) =>
    GovukType.style(c, GovukType.p19, bold: bold, color: color ?? _text(c));

// ---------------------------------------------------------------------------
// Headings and captions
// ---------------------------------------------------------------------------

enum GovukHeadingSize { xl, l, m, s }

/// GOV.UK heading (xl 48, l 36, m 24, s 19) with an optional caption above.
class GovukHeading extends StatelessWidget {
  const GovukHeading(this.text, {super.key, this.size = GovukHeadingSize.l, this.caption, this.bottomSpacing});

  final String text;
  final GovukHeadingSize size;
  final String? caption;
  final double? bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final p = switch (size) {
      GovukHeadingSize.xl => GovukType.p48,
      GovukHeadingSize.l => GovukType.p36,
      GovukHeadingSize.m => GovukType.p24,
      GovukHeadingSize.s => GovukType.p19,
    };
    final cp = switch (size) {
      GovukHeadingSize.xl => GovukType.p27,
      GovukHeadingSize.l => GovukType.p24,
      _ => GovukType.p19,
    };
    final spacing = bottomSpacing ??
        switch (size) {
          GovukHeadingSize.xl || GovukHeadingSize.l => GovukSpacing.of(context, 6),
          GovukHeadingSize.m => GovukSpacing.of(context, 4),
          GovukHeadingSize.s => GovukSpacing.of(context, 4),
        };
    return Padding(
      padding: EdgeInsets.only(bottom: spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(caption!, style: GovukType.style(context, cp, color: _secondary(context))),
            ),
          Semantics(
            header: true,
            child: Text(text, style: GovukType.style(context, p, bold: true, color: _text(context))),
          ),
        ],
      ),
    );
  }
}

/// GOV.UK section break: 1px border-coloured line with spacing.
class GovukSectionBreak extends StatelessWidget {
  const GovukSectionBreak({super.key, this.size = 6, this.visible = true});

  /// Responsive spacing unit above and below (GOV.UK m = 4, l = 6, xl = 8).
  final int size;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final s = GovukSpacing.of(context, size);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s),
      child: visible ? Divider(height: 1, thickness: 1, color: _border(context)) : const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Inset text, warning text, panel, details
// ---------------------------------------------------------------------------

/// GOV.UK inset text: 10px left border. Use for quotes, examples and
/// supporting information (e.g. dose formulas and their source).
class GovukInsetText extends StatelessWidget {
  const GovukInsetText({super.key, this.text, this.child, this.borderColor})
      : assert(text != null || child != null);

  final String? text;
  final Widget? child;

  /// Defaults to the border colour; pass [GovukColours.brand] for brand accent.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GovukSpacing.s3),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: borderColor ?? _border(context), width: GovukLayout.borderWidthWide),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: _body(context),
        child: child ?? Text(text!, style: _body(context)),
      ),
    );
  }
}

/// GOV.UK warning text: black circle with "!" and bold text. The hidden
/// "Warning" prefix is announced by screen readers.
class GovukWarningText extends StatelessWidget {
  const GovukWarningText(this.text, {super.key, this.assistivePrefix = 'Warning', this.child});

  final String text;
  final String assistivePrefix;

  /// Optional extra content under the bold text (e.g. a source line).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final fg = _text(context);
    final bg = _dark(context) ? GovukColours.darkBackground : GovukColours.white;
    return Semantics(
      container: true,
      label: '$assistivePrefix: $text',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: GovukSpacing.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle, border: Border.all(color: fg, width: 3)),
                child: Text('!',
                    style: TextStyle(
                      fontFamily: GovukType.fontFamily,
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: bg,
                    )),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: _body(context, bold: true)),
                      if (child != null) ...[const SizedBox(height: 5), child!],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum GovukPanelVariant { confirmation, brand, interruption }

/// GOV.UK panel: confirmation (green), brand (AImesis sky tint) or
/// interruption (brand blue, left-aligned).
class GovukPanel extends StatelessWidget {
  const GovukPanel({super.key, required this.title, this.body, this.child, this.variant = GovukPanelVariant.confirmation});

  final String title;
  final String? body;
  final Widget? child;
  final GovukPanelVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      GovukPanelVariant.confirmation => (GovukColours.success, GovukColours.white),
      GovukPanelVariant.brand => (GovukColours.brandTint, GovukColours.black),
      GovukPanelVariant.interruption => (GovukColours.brand, GovukColours.white),
    };
    final centred = variant == GovukPanelVariant.confirmation;
    final large = GovukLayout.isTablet(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(large ? 35 : 15),
      color: bg,
      child: Column(
        crossAxisAlignment: centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title,
                textAlign: centred ? TextAlign.center : TextAlign.start,
                style: GovukType.style(context, variant == GovukPanelVariant.interruption ? GovukType.p36 : GovukType.p48,
                    bold: true, color: fg)),
          ),
          if (body != null) ...[
            SizedBox(height: large ? 20 : 15),
            Text(body!,
                textAlign: centred ? TextAlign.center : TextAlign.start,
                style: GovukType.style(context, GovukType.p24, color: fg)),
          ],
          if (child != null) ...[
            const SizedBox(height: 15),
            DefaultTextStyle.merge(style: TextStyle(color: fg), child: child!),
          ],
        ],
      ),
    );
  }
}

/// GOV.UK details: a link-styled summary with a triangle that reveals more
/// content, indented with a 5px left border.
class GovukDetails extends StatefulWidget {
  const GovukDetails({super.key, required this.summary, required this.child, this.initiallyOpen = false});

  final String summary;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<GovukDetails> createState() => _GovukDetailsState();
}

class _GovukDetailsState extends State<GovukDetails> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final link = dark ? GovukColours.darkLink : GovukColours.link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          expanded: _open,
          child: GovukFocusRing.builder(
            onTap: () => setState(() => _open = !_open),
            builder: (context, focused, hovered) {
              final c = focused ? GovukColours.focusText : (hovered ? (dark ? GovukColours.darkLinkHover : GovukColours.linkHover) : link);
              final row = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_open ? Icons.arrow_drop_down : Icons.arrow_right, color: c, size: 26),
                  Flexible(
                    child: Text(widget.summary,
                        style: _body(context, color: c).copyWith(
                          decoration: focused ? TextDecoration.none : TextDecoration.underline,
                          decorationColor: c,
                          decorationThickness: hovered ? 3 : 1.5,
                        )),
                  ),
                ],
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: focused ? GovukFocusedText(child: row) : row,
              );
            },
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 5, left: 0),
            padding: const EdgeInsets.fromLTRB(15, 15, 0, 15),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: _border(context), width: GovukLayout.borderWidth)),
            ),
            child: DefaultTextStyle.merge(style: _body(context), child: widget.child),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notification banner, error summary, error message
// ---------------------------------------------------------------------------

enum GovukNotificationType { important, success }

/// GOV.UK notification banner. Default (important) uses the AImesis brand blue;
/// success uses GOV.UK green. Title bar text is white, body on white.
class GovukNotificationBanner extends StatelessWidget {
  const GovukNotificationBanner({
    super.key,
    this.title,
    this.heading,
    this.text,
    this.child,
    this.type = GovukNotificationType.important,
    this.onDismiss,
  });

  const GovukNotificationBanner.success({
    super.key,
    this.title,
    this.heading,
    this.text,
    this.child,
    this.onDismiss,
  }) : type = GovukNotificationType.success;

  /// Defaults to "Important" / "Success".
  final String? title;

  /// Bold 24px heading in the body.
  final String? heading;
  final String? text;
  final Widget? child;
  final GovukNotificationType type;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final success = type == GovukNotificationType.success;
    final colour = success ? GovukColours.success : GovukColours.brand;
    final t = title ?? (success ? 'Success' : 'Important');
    final large = GovukLayout.isTablet(context);
    final pad = large ? 20.0 : 15.0;
    return Semantics(
      container: true,
      liveRegion: success,
      label: t,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: colour, width: GovukLayout.borderWidth)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: colour,
              padding: EdgeInsets.fromLTRB(pad - 5, 2, pad - 5, 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t, style: GovukType.style(context, GovukType.p19, bold: true, color: GovukColours.white)),
                  ),
                  if (onDismiss != null)
                    GovukFocusRing(
                      onTap: onDismiss,
                      semanticLabel: 'Dismiss',
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 20, color: GovukColours.white),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: _surface(context),
              padding: EdgeInsets.all(pad - 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (heading != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: text != null || child != null ? 15 : 0),
                      child: Text(heading!, style: GovukType.style(context, GovukType.p24, bold: true, color: _text(context))),
                    ),
                  if (text != null) Text(text!, style: _body(context)),
                  if (child != null) ...[
                    if (text != null) const SizedBox(height: 10),
                    DefaultTextStyle.merge(style: _body(context), child: child!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry in a [GovukErrorSummary].
class GovukErrorItem {
  const GovukErrorItem(this.message, {this.onTap});

  /// Same wording as the error message next to the field.
  final String message;

  /// Usually focuses the field (`focusNode.requestFocus()`).
  final VoidCallback? onTap;
}

/// GOV.UK error summary: "There is a problem", red 5px border, a list of
/// links to the fields. Put it at the top of the page and focus it.
class GovukErrorSummary extends StatefulWidget {
  const GovukErrorSummary({
    super.key,
    required this.errors,
    this.title = 'There is a problem',
    this.description,
    this.autofocus = true,
  });

  final List<GovukErrorItem> errors;
  final String title;
  final String? description;

  /// Move keyboard focus to the summary when it appears (GOV.UK behaviour).
  final bool autofocus;

  @override
  State<GovukErrorSummary> createState() => _GovukErrorSummaryState();
}

class _GovukErrorSummaryState extends State<GovukErrorSummary> {
  final FocusNode _node = FocusNode(debugLabel: 'GovukErrorSummary');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = _error(context);
    final large = GovukLayout.isTablet(context);
    return Focus(
      focusNode: _node,
      onFocusChange: (v) => setState(() => _focused = v),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: widget.title,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(large ? 20 : 15),
          decoration: BoxDecoration(
            color: _surface(context),
            border: Border.all(color: err, width: GovukLayout.borderWidth),
          ),
          foregroundDecoration: _focused
              ? BoxDecoration(border: Border.all(color: GovukColours.focus, width: GovukLayout.focusWidth))
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(widget.title, style: GovukType.style(context, GovukType.p24, bold: true, color: _text(context))),
              ),
              SizedBox(height: large ? 20 : 15),
              if (widget.description != null) ...[
                Text(widget.description!, style: _body(context)),
                const SizedBox(height: 10),
              ],
              for (final e in widget.errors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: e.onTap == null
                      ? Text(e.message, style: _body(context, bold: true, color: err))
                      : GovukLink(e.message, onTap: e.onTap, style: _body(context, bold: true, color: err).copyWith(color: err)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// GOV.UK error message shown above the field: bold red, hidden "Error:" prefix.
class GovukErrorMessage extends StatelessWidget {
  const GovukErrorMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Error: $message',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: GovukSpacing.s3),
        child: Text(message, style: _body(context, bold: true, color: _error(context))),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary list and table
// ---------------------------------------------------------------------------

/// A row of a [GovukSummaryList].
class GovukSummaryRow {
  const GovukSummaryRow({required this.key, this.value, this.valueWidget, this.actionLabel, this.onAction});

  final String key;
  final String? value;
  final Widget? valueWidget;

  /// e.g. "Change" (a visually hidden suffix with [key] is added).
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// GOV.UK summary list: bold key (30%), value, optional action (20%) with a
/// 1px divider per row. Stacks key over value below 641px.
class GovukSummaryList extends StatelessWidget {
  const GovukSummaryList({super.key, required this.rows, this.noBorder = false, this.keyWidthFraction = 0.3});

  final List<GovukSummaryRow> rows;
  final bool noBorder;
  final double keyWidthFraction;

  @override
  Widget build(BuildContext context) {
    final border = _border(context);
    final hasActions = rows.any((r) => r.onAction != null);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= GovukLayout.tablet - 120;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rows)
            Container(
              decoration: BoxDecoration(
                border: noBorder ? null : Border(bottom: BorderSide(color: border)),
              ),
              padding: EdgeInsets.symmetric(vertical: wide ? 10 : 8),
              child: wide ? _wideRow(context, r, c.maxWidth, hasActions) : _narrowRow(context, r),
            ),
        ],
      );
    });
  }

  Widget _value(BuildContext context, GovukSummaryRow r) =>
      r.valueWidget ?? Text(r.value ?? '—', style: _body(context));

  Widget? _action(BuildContext context, GovukSummaryRow r) => r.onAction == null
      ? null
      : Semantics(
          label: '${r.actionLabel ?? 'Change'} ${r.key}',
          excludeSemantics: true,
          child: GovukLink(r.actionLabel ?? 'Change', onTap: r.onAction),
        );

  Widget _wideRow(BuildContext context, GovukSummaryRow r, double width, bool hasActions) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: width * keyWidthFraction,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(r.key, style: _body(context, bold: true)),
          ),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.only(right: 20), child: _value(context, r))),
        if (hasActions)
          SizedBox(
            width: width * 0.2,
            child: Align(alignment: Alignment.topRight, child: _action(context, r) ?? const SizedBox.shrink()),
          ),
      ],
    );
  }

  Widget _narrowRow(BuildContext context, GovukSummaryRow r) {
    final a = _action(context, r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.key, style: _body(context, bold: true)),
        const SizedBox(height: 5),
        _value(context, r),
        if (a != null) ...[const SizedBox(height: 10), a],
      ],
    );
  }
}

/// A column of a [GovukTable].
class GovukTableColumn {
  const GovukTableColumn(this.label, {this.numeric = false, this.flex = 1, this.width});

  final String label;
  final bool numeric;
  final int flex;

  /// Fixed width; overrides [flex].
  final double? width;
}

/// GOV.UK table: bold caption, bold headers, 1px row dividers, numeric
/// columns right-aligned with tabular figures. Cells are widgets or strings.
/// Scrolls horizontally if it does not fit.
class GovukTable extends StatelessWidget {
  const GovukTable({
    super.key,
    required this.columns,
    required this.rows,
    this.caption,
    this.captionSize = GovukHeadingSize.m,
    this.minWidth = 0,
    this.smallText = false,
    this.onRowTap,
  });

  final List<GovukTableColumn> columns;

  /// Each cell is a [String] or a [Widget].
  final List<List<Object?>> rows;
  final String? caption;
  final GovukHeadingSize captionSize;

  /// Table scrolls horizontally below this width.
  final double minWidth;
  final bool smallText;
  final void Function(int index)? onRowTap;

  @override
  Widget build(BuildContext context) {
    final border = _border(context);
    final textStyle = GovukType.style(context, smallText ? GovukType.p16 : GovukType.p19, color: _text(context));
    final numStyle = textStyle.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    Widget cell(Object? v, GovukTableColumn col, {bool header = false}) {
      final style = header ? textStyle.copyWith(fontWeight: FontWeight.w700) : (col.numeric ? numStyle : textStyle);
      final Widget content = v is Widget ? v : Text(v?.toString() ?? '', style: style);
      final aligned = Align(alignment: col.numeric ? Alignment.topRight : Alignment.topLeft, child: content);
      final padded = Padding(padding: const EdgeInsets.fromLTRB(0, 10, 20, 10), child: aligned);
      return col.width != null ? SizedBox(width: col.width, child: padded) : Expanded(flex: col.flex, child: padded);
    }

    Widget row(List<Object?> cells, {bool header = false, int? index}) {
      final r = Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var i = 0; i < columns.length; i++) cell(i < cells.length ? cells[i] : null, columns[i], header: header)],
        ),
      );
      if (header) return Semantics(header: true, child: r);
      if (onRowTap != null && index != null) {
        return GovukFocusRing(onTap: () => onRowTap!(index), outline: true, child: r);
      }
      return r;
    }

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null)
          GovukHeading(caption!, size: captionSize, bottomSpacing: 10),
        row([for (final c in columns) c.label], header: true),
        for (var i = 0; i < rows.length; i++) row(rows[i], index: i),
      ],
    );
    if (minWidth <= 0) return table;
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= minWidth) return table;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: minWidth, child: table),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Navigation: back link, phase banner, header, footer, tabs
// ---------------------------------------------------------------------------

/// GOV.UK back link: 16px, underlined, left chevron.
class GovukBackLink extends StatelessWidget {
  const GovukBackLink({super.key, this.label = 'Back', required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GovukSpacing.s3),
      child: GovukFocusRing.builder(
        onTap: onTap,
        isButton: false,
        semanticLabel: label,
        builder: (context, focused, hovered) {
          final c = focused ? GovukColours.focusText : _text(context);
          final row = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left, size: 18, color: focused ? c : (dark ? GovukColours.darkSecondaryText : GovukColours.secondaryText)),
              Text(label,
                  style: GovukType.style(context, GovukType.p16, color: c).copyWith(
                    decoration: focused ? TextDecoration.none : TextDecoration.underline,
                    decorationColor: c,
                    decorationThickness: hovered ? 3 : 1.5,
                  )),
            ],
          );
          return focused ? GovukFocusedText(child: row) : row;
        },
      ),
    );
  }
}

/// GOV.UK phase banner: tag + short text, 16px, bottom border.
class GovukPhaseBanner extends StatelessWidget {
  const GovukPhaseBanner({
    super.key,
    this.phase = 'Prototype',
    this.text = 'This is a prototype. Not for clinical use.',
    this.trailing,
    this.maxWidth = GovukLayout.pageWidth,
  });

  final String phase;
  final String text;
  final Widget? trailing;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final gutter = GovukLayout.isTablet(context) ? GovukLayout.gutter : GovukLayout.gutterHalf;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _dark(context) ? GovukColours.darkBackground : GovukColours.white,
        border: Border(bottom: BorderSide(color: _border(context))),
      ),
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            children: [
              GovukTag(phase, colour: GovukTagColour.brand, small: true),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: GovukType.style(context, GovukType.p16, color: _text(context)))),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// AImesis header (GOV.UK header pattern, our brand): white background,
/// AImesis logo + service area name on the left, 10px brand-blue bottom
/// border. No crown, no GOV.UK logotype. Put navigation in [actions] or a
/// separate service navigation bar, not in the logo link.
class GovukHeader extends StatelessWidget implements PreferredSizeWidget {
  const GovukHeader({
    super.key,
    required this.serviceName,
    this.logo,
    this.onHomeTap,
    this.actions = const [],
    this.maxWidth,
    this.leading,
  });

  /// e.g. "Care team".
  final String serviceName;

  /// Usually `AimesisBrand.logo(height: 36)`.
  final Widget? logo;
  final VoidCallback? onHomeTap;
  final List<Widget> actions;

  /// Constrain the content to the page width (null = full width).
  final double? maxWidth;
  final Widget? leading;

  static const double height = GovukLayout.headerHeight + GovukLayout.borderWidthWide;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final narrow = !GovukLayout.isTablet(context);
    final gutter = narrow ? GovukLayout.gutterHalf : GovukLayout.gutter * 0.66;
    final name = Text(
      serviceName,
      overflow: TextOverflow.ellipsis,
      style: GovukType.style(context, narrow ? GovukType.p19 : GovukType.p24, bold: true, color: GovukColours.brandDark),
    );
    final home = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logo != null) logo!,
        if (logo != null) Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 12), color: GovukColours.midGrey),
        Flexible(child: name),
      ],
    );
    Widget content = Row(
      children: [
        if (leading != null) leading!,
        Flexible(
          child: onHomeTap == null
              ? home
              : GovukFocusRing(
                  onTap: onHomeTap,
                  isButton: false,
                  semanticLabel: 'AImesis $serviceName home',
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: home),
                ),
        ),
        const Spacer(),
        ...actions,
      ],
    );
    if (maxWidth != null) {
      content = Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth!), child: content));
    }
    return Material(
      color: GovukColours.white,
      child: Theme(
        // Header is always white, even in dark mode, so the logo reads.
        data: Theme.of(context).copyWith(
          brightness: Brightness.light,
          iconTheme: const IconThemeData(color: GovukColours.black),
        ),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: height,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GovukColours.brand, width: GovukLayout.borderWidthWide)),
            ),
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: DefaultTextStyle.merge(style: const TextStyle(color: GovukColours.black), child: content),
          ),
        ),
      ),
    );
  }
}

/// A link in a [GovukFooter].
class GovukFooterLink {
  const GovukFooterLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}

/// GOV.UK footer pattern with the AImesis brand: 10px brand top border, light
/// background, meta links and a short licence/credit line. No crown.
class GovukFooter extends StatelessWidget {
  const GovukFooter({
    super.key,
    this.links = const [],
    this.text = 'AImesis prototype · Hacking for Good 2026. Not for clinical use.',
    this.credit = 'Design based on the GOV.UK Design System (MIT licence).',
    this.maxWidth = GovukLayout.pageWidth,
  });

  final List<GovukFooterLink> links;
  final String text;
  final String? credit;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final small = GovukType.style(context, GovukType.p16, color: _text(context));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dark ? GovukColours.darkSurface : GovukColours.lightGrey,
        border: const Border(top: BorderSide(color: GovukColours.brand, width: GovukLayout.borderWidthWide)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: GovukLayout.isTablet(context) ? GovukLayout.gutter : GovukLayout.gutterHalf,
        vertical: GovukSpacing.of(context, 6),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (links.isNotEmpty) ...[
                Wrap(
                  spacing: 20,
                  runSpacing: 6,
                  children: [for (final l in links) GovukLink(l.label, onTap: l.onTap, style: small)],
                ),
                const SizedBox(height: 15),
              ],
              Text(text, style: small),
              if (credit != null) ...[const SizedBox(height: 5), Text(credit!, style: small)],
            ],
          ),
        ),
      ),
    );
  }
}

/// GOV.UK tabs: link-style tab labels, the selected tab boxed with a white
/// background and borders. Collapses to a list of links on phones.
class GovukTabs extends StatelessWidget {
  const GovukTabs({super.key, required this.labels, required this.selected, required this.onSelect, this.title = 'Contents'});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final String title;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final border = _border(context);
    final link = dark ? GovukColours.darkLink : GovukColours.link;
    if (!GovukLayout.isTablet(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _body(context)),
          const SizedBox(height: 10),
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Text('— ', style: _body(context)),
                i == selected
                    ? Text(labels[i], style: _body(context, bold: true))
                    : GovukLink(labels[i], onTap: () => onSelect(i)),
              ]),
            ),
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Semantics(
                  selected: i == selected,
                  child: GovukFocusRing.builder(
                    onTap: () => onSelect(i),
                    semanticLabel: labels[i],
                    builder: (context, focused, hovered) {
                      final sel = i == selected;
                      final label = Text(labels[i],
                          style: _body(context, color: focused ? GovukColours.focusText : (sel ? _text(context) : link)).copyWith(
                            decoration: sel || focused ? TextDecoration.none : TextDecoration.underline,
                            decorationColor: link,
                            decorationThickness: hovered ? 3 : 1.5,
                          ));
                      return Container(
                        padding: EdgeInsets.fromLTRB(20, sel ? 14 : 10, 20, sel ? 16 : 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? _surface(context)
                              : (dark ? GovukColours.darkSurfaceHigh : GovukColours.lightGrey),
                          border: sel
                              ? Border(
                                  top: BorderSide(color: border),
                                  left: BorderSide(color: border),
                                  right: BorderSide(color: border),
                                )
                              : null,
                        ),
                        child: focused ? GovukFocusedText(child: label) : label,
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Successful result text helper (green bold), e.g. "Saved".
class GovukSuccessText extends StatelessWidget {
  const GovukSuccessText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: _body(context, bold: true, color: _success(context)));
}

/// Secondary (grey) body text, 16px by default.
class GovukHint extends StatelessWidget {
  const GovukHint(this.text, {super.key, this.large = false});
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: GovukType.style(context, large ? GovukType.p19 : GovukType.p16, color: _secondary(context))),
      );
}

/// Convenience: a list of [GovukTag]s that wrap.
class GovukTagList extends StatelessWidget {
  const GovukTagList({super.key, required this.tags, this.small = true});

  final List<String> tags;
  final bool small;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final t in tags) GovukTag(t, colour: GovukMapping.patientTag(t), small: small)],
      );
}
