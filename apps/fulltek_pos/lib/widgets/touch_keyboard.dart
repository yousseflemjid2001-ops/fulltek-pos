import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fulltek_themes.dart';

enum TouchKeyboardMode { azerty, arabic, numeric }

/// Global controller for the built-in visual touch keyboard (AZERTY / Arabic / Numeric).
/// Automatically pops up whenever ANY [EditableText] receives focus on touch POS screens.
class TouchKeyboardController extends ChangeNotifier {
  TouchKeyboardController._();
  static final TouchKeyboardController instance = TouchKeyboardController._();

  /// Enabled by default on Web/POS touch terminals; disabled in headless unit tests unless toggled.
  bool autoOpenEnabled = kIsWeb;
  bool _visible = false;
  TouchKeyboardMode _mode = TouchKeyboardMode.azerty;
  bool _shift = false;
  EditableTextState? _activeEditable;

  bool get visible => _visible && _activeEditable != null && _activeEditable!.mounted;
  TouchKeyboardMode get mode => _mode;
  bool get shift => _shift;
  EditableTextState? get activeEditable => _activeEditable;

  void setAutoOpen(bool enabled) {
    autoOpenEnabled = enabled;
    if (!enabled) _visible = false;
    notifyListeners();
  }

  void setMode(TouchKeyboardMode next) {
    if (_mode == next) return;
    _mode = next;
    notifyListeners();
  }

  void toggleShift() {
    _shift = !_shift;
    notifyListeners();
  }

  void openForCurrentFocus({TouchKeyboardMode? forcedMode}) {
    final editable = _findFocusedEditable();
    if (editable != null) {
      _activeEditable = editable;
      _mode = forcedMode ?? _detectModeFor(editable);
      _visible = true;
      notifyListeners();
    }
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  void handleFocusChange() {
    final editable = _findFocusedEditable();
    if (editable == null) {
      if (_visible || _activeEditable != null) {
        _visible = false;
        _activeEditable = null;
        notifyListeners();
      }
      return;
    }
    final changedTarget = _activeEditable != editable;
    _activeEditable = editable;
    if (autoOpenEnabled) {
      if (changedTarget || !_visible) {
        _mode = _detectModeFor(editable);
        _shift = false;
        _visible = true;
      }
      notifyListeners();
    }
  }

  TouchKeyboardMode _detectModeFor(EditableTextState editable) {
    final kt = editable.widget.keyboardType;
    if (kt == TextInputType.number ||
        kt == const TextInputType.numberWithOptions(decimal: true) ||
        kt == const TextInputType.numberWithOptions(signed: true) ||
        kt == const TextInputType.numberWithOptions(decimal: true, signed: true) ||
        kt == TextInputType.phone) {
      return TouchKeyboardMode.numeric;
    }
    return TouchKeyboardMode.azerty;
  }

  EditableTextState? _findFocusedEditable() {
    final node = FocusManager.instance.primaryFocus;
    final ctx = node?.context;
    if (ctx == null) return null;
    if (ctx is StatefulElement && ctx.state is EditableTextState) {
      return ctx.state as EditableTextState;
    }
    final ancestor = ctx.findAncestorStateOfType<EditableTextState>();
    if (ancestor != null) return ancestor;
    EditableTextState? found;
    void visitor(Element el) {
      if (found != null) return;
      if (el is StatefulElement && el.state is EditableTextState) {
        found = el.state as EditableTextState;
        return;
      }
      el.visitChildren(visitor);
    }
    ctx.visitChildElements(visitor);
    return found;
  }

  void insertText(String text) {
    final editable = _activeEditable;
    if (editable == null || !editable.mounted) return;
    final val = editable.textEditingValue;
    final sel = val.selection;
    final start = sel.isValid ? sel.start : val.text.length;
    final end = sel.isValid ? sel.end : val.text.length;
    final outText = (_mode == TouchKeyboardMode.azerty && _shift)
        ? text.toUpperCase()
        : text;
    final nextText = val.text.replaceRange(start, end, outText);
    final nextOffset = start + outText.length;
    editable.userUpdateTextEditingValue(
      val.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextOffset),
        composing: TextRange.empty,
      ),
      SelectionChangedCause.keyboard,
    );
    if (_shift) {
      _shift = false;
    }
    notifyListeners();
  }

  void backspace() {
    final editable = _activeEditable;
    if (editable == null || !editable.mounted) return;
    final val = editable.textEditingValue;
    final sel = val.selection;
    final start = sel.isValid ? sel.start : val.text.length;
    final end = sel.isValid ? sel.end : val.text.length;
    if (start != end) {
      final nextText = val.text.replaceRange(start, end, '');
      editable.userUpdateTextEditingValue(
        val.copyWith(
          text: nextText,
          selection: TextSelection.collapsed(offset: start),
          composing: TextRange.empty,
        ),
        SelectionChangedCause.keyboard,
      );
    } else if (start > 0) {
      final nextText = val.text.replaceRange(start - 1, start, '');
      editable.userUpdateTextEditingValue(
        val.copyWith(
          text: nextText,
          selection: TextSelection.collapsed(offset: start - 1),
          composing: TextRange.empty,
        ),
        SelectionChangedCause.keyboard,
      );
    }
    notifyListeners();
  }

  void clearAll() {
    final editable = _activeEditable;
    if (editable == null || !editable.mounted) return;
    editable.userUpdateTextEditingValue(
      const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ),
      SelectionChangedCause.keyboard,
    );
    notifyListeners();
  }

  void submitAndClose() {
    final editable = _activeEditable;
    if (editable != null && editable.mounted) {
      editable.performAction(TextInputAction.done);
    }
    hide();
  }
}

/// Root wrapper mounted inside [MaterialApp.builder] that docks the visual
/// Touch Keyboard at the bottom of the screen whenever any text/number field is focused.
class TouchKeyboardHost extends StatefulWidget {
  final Widget child;
  const TouchKeyboardHost({super.key, required this.child});

  @override
  State<TouchKeyboardHost> createState() => _TouchKeyboardHostState();
}

class _TouchKeyboardHostState extends State<TouchKeyboardHost> {
  final _kb = TouchKeyboardController.instance;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _kb.handleFocusChange();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _kb,
      builder: (context, _) {
        final show = _kb.visible;
        return Column(
          children: [
            Expanded(child: widget.child),
            if (show) const _DockedTouchKeyboardPanel(),
          ],
        );
      },
    );
  }
}

class _DockedTouchKeyboardPanel extends StatelessWidget {
  const _DockedTouchKeyboardPanel();

  static const _azertyRows = <List<String>>[
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm'],
    ['w', 'x', 'c', 'v', 'b', 'n', 'é', 'è', '-', '@'],
  ];

  static const _arabicRows = <List<String>>[
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج'],
    ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك', 'ط'],
    ['ئ', 'ء', 'ؤ', 'ر', 'لا', 'ى', 'ة', 'و', 'ز', 'ظ', 'د'],
  ];

  static const _numRows = <List<String>>[
    ['7', '8', '9', '+'],
    ['4', '5', '6', '-'],
    ['1', '2', '3', '.'],
    ['00', '0', 'C', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    final kb = TouchKeyboardController.instance;
    final p = FullTekThemes.paletteOf(context);
    final editable = kb.activeEditable;
    final rawVal = editable?.textEditingValue.text ?? '';
    final isObscure = editable?.widget.obscureText == true;
    final preview = isObscure ? ('•' * rawVal.length) : rawVal;

    return TextFieldTapRegion(
      child: Material(
        key: const Key('global_touch_keyboard'),
        elevation: 16,
        color: p.surface,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.primary, width: 2)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: kb.mode == TouchKeyboardMode.numeric ? 420 : 880,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top control bar: mode switchers (FR / عربي / 123) + live preview + Close
                  Row(
                    children: [
                      _modePill(
                        label: 'FR',
                        active: kb.mode == TouchKeyboardMode.azerty,
                        onTap: () => kb.setMode(TouchKeyboardMode.azerty),
                        p: p,
                      ),
                      const SizedBox(width: 5),
                      _modePill(
                        label: 'عربي',
                        active: kb.mode == TouchKeyboardMode.arabic,
                        onTap: () => kb.setMode(TouchKeyboardMode.arabic),
                        p: p,
                      ),
                      const SizedBox(width: 5),
                      _modePill(
                        label: '123',
                        active: kb.mode == TouchKeyboardMode.numeric,
                        onTap: () => kb.setMode(TouchKeyboardMode.numeric),
                        p: p,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: p.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            preview.isEmpty ? 'Clavier tactile...' : preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: preview.isEmpty
                                  ? p.textMuted
                                  : p.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        key: const Key('touch_kb_close_btn'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: kb.hide,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: p.danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: p.danger.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.keyboard_hide_rounded,
                                  size: 16, color: p.danger),
                              const SizedBox(width: 4),
                              Text(
                                'Fermer',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: p.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (kb.mode == TouchKeyboardMode.numeric)
                    _buildNumericPad(kb, p)
                  else
                    _buildAlphaPad(
                      kb,
                      p,
                      kb.mode == TouchKeyboardMode.arabic
                          ? _arabicRows
                          : _azertyRows,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modePill({
    required String label,
    required bool active,
    required VoidCallback onTap,
    required PosPalette p,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? p.primary : p.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? p.primary : p.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: active ? p.onPrimary : p.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildNumericPad(TouchKeyboardController kb, PosPalette p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _numRows) ...[
          Row(
            children: row.map((k) {
              final isClear = k == 'C';
              final isBack = k == '⌫';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _keyBtn(
                    label: k,
                    p: p,
                    height: 44,
                    bg: isClear
                        ? p.danger.withValues(alpha: 0.16)
                        : (isBack
                            ? p.warning.withValues(alpha: 0.16)
                            : p.surfaceAlt),
                    fg: isClear
                        ? p.danger
                        : (isBack ? p.warning : p.textPrimary),
                    onTap: () {
                      if (isClear) {
                        kb.clearAll();
                      } else if (isBack) {
                        kb.backspace();
                      } else {
                        kb.insertText(k);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: _keyBtn(
            label: '✓ Valider',
            p: p,
            height: 40,
            bg: p.primary,
            fg: p.onPrimary,
            onTap: kb.submitAndClose,
          ),
        ),
      ],
    );
  }

  Widget _buildAlphaPad(
    TouchKeyboardController kb,
    PosPalette p,
    List<List<String>> rows,
  ) {
    final isAzerty = kb.mode == TouchKeyboardMode.azerty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            children: row.map((k) {
              final shown = (isAzerty && kb.shift) ? k.toUpperCase() : k;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: _keyBtn(
                    label: shown,
                    p: p,
                    height: 40,
                    onTap: () => kb.insertText(k),
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 3),
        Row(
          children: [
            if (isAzerty)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: _keyBtn(
                    label: kb.shift ? '⇧ MAJ' : '⇧ maj',
                    p: p,
                    height: 42,
                    bg: kb.shift ? p.primary : p.surfaceAlt,
                    fg: kb.shift ? p.onPrimary : p.textPrimary,
                    onTap: kb.toggleShift,
                  ),
                ),
              ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: _keyBtn(
                  label: 'Espace',
                  p: p,
                  height: 42,
                  onTap: () => kb.insertText(' '),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: _keyBtn(
                  label: '⌫ Effacer',
                  p: p,
                  height: 42,
                  bg: p.warning.withValues(alpha: 0.16),
                  fg: p.warning,
                  onTap: kb.backspace,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: _keyBtn(
                  label: '✓ OK',
                  p: p,
                  height: 42,
                  bg: p.primary,
                  fg: p.onPrimary,
                  onTap: kb.submitAndClose,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyBtn({
    required String label,
    required PosPalette p,
    required VoidCallback onTap,
    double height = 40,
    Color? bg,
    Color? fg,
  }) {
    return Material(
      color: bg ?? p.surfaceAlt,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: p.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: fg ?? p.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
