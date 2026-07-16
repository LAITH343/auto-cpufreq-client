import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// A surface card with the design's border, radius and padding.
class AppCard extends StatelessWidget {
  final Palette p;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? radius;
  final Border? border;
  final Color? color;

  const AppCard({
    super.key,
    required this.p,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.radius,
    this.border,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: radius ?? BorderRadius.circular(12),
        border: border ?? Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

/// Uppercase, wide-tracked section label.
class SectionLabel extends StatelessWidget {
  final Palette p;
  final String text;
  const SectionLabel(this.p, this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppFonts.sectionLabel(p.textFaint));
}

/// A pill segmented selector, used for governor/turbo/tabs.
class SegmentOption<T> {
  final T value;
  final String label;
  const SegmentOption(this.value, this.label);
}

class SegmentedControl<T> extends StatelessWidget {
  final Palette p;
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final bool expand;
  final EdgeInsets itemPadding;

  const SegmentedControl({
    super.key,
    required this.p,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expand = true,
    this.itemPadding = const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
  });

  @override
  Widget build(BuildContext context) {
    final children = options.map((o) {
      final active = o.value == selected;
      final seg = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(o.value),
        child: Container(
          padding: itemPadding,
          decoration: BoxDecoration(
            color: active ? p.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.center,
          child: Text(
            o.label,
            style: AppFonts.sans(
              size: 13,
              weight: FontWeight.w700,
              color: active ? Colors.white : p.textDim,
            ),
          ),
        ),
      );
      return expand ? Expanded(child: seg) : seg;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// The pill toggle switch from the design.
class AppSwitch extends StatelessWidget {
  final Palette p;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  const AppSwitch({
    super.key,
    required this.p,
    required this.value,
    required this.onChanged,
    this.width = 42,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = height - 6;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? p.success : p.surface2,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              top: 3,
              left: value ? width - thumb - 3 : 3,
              child: Container(
                width: thumb,
                height: thumb,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label/value row (used in the dashboard rails and lists).
class StatRow extends StatelessWidget {
  final Palette p;
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  const StatRow({
    super.key,
    required this.p,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: AppFonts.sans(size: 12, color: p.textDim))),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: mono
                ? AppFonts.mono(size: 12.5, weight: FontWeight.w700, color: valueColor ?? p.text)
                : AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: valueColor ?? p.text),
          ),
        ),
      ],
    );
  }
}

/// A read-only lock chip / note.
class LockNote extends StatelessWidget {
  final Palette p;
  final String text;
  const LockNote(this.p, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 13, color: p.textFaint),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: AppFonts.sans(size: 12.5, color: p.textDim))),
        ],
      ),
    );
  }
}

/// A filled accent button.
class PrimaryButton extends StatelessWidget {
  final Palette p;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool expand;
  const PrimaryButton({
    super.key,
    required this.p,
    required this.label,
    required this.onPressed,
    this.color,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: color ?? p.accent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// An outlined/ghost button.
class GhostButton extends StatelessWidget {
  final Palette p;
  final String label;
  final VoidCallback? onPressed;
  final Color? textColor;
  final Color? borderColor;
  const GhostButton({
    super.key,
    required this.p,
    required this.label,
    required this.onPressed,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor ?? p.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: AppFonts.sans(size: 13, weight: FontWeight.w600, color: textColor ?? p.text),
          ),
        ),
      ),
    );
  }
}

/// A text field styled to match the design's inputs.
class AppTextField extends StatelessWidget {
  final Palette p;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const AppTextField({
    super.key,
    required this.p,
    this.controller,
    this.hint,
    this.obscure = false,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: AppFonts.sans(size: 14, color: p.text),
      cursorColor: p.accent,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppFonts.sans(size: 13.5, color: p.textFaint),
        filled: true,
        fillColor: p.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.accent),
        ),
      ),
    );
  }
}

/// A styled dropdown matching the design's `select`.
class AppDropdown<T> extends StatelessWidget {
  final Palette p;
  final T value;
  final List<T> items;
  final String Function(T)? labelOf;
  final ValueChanged<T?>? onChanged;

  const AppDropdown({
    super.key,
    required this.p,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: p.surface2,
          iconEnabledColor: p.textDim,
          borderRadius: BorderRadius.circular(8),
          style: AppFonts.sans(size: 13, color: p.text),
          onChanged: onChanged,
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(labelOf?.call(e) ?? '$e'),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
