import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/fulltek_themes.dart';

enum TouchKeyboardMode { azerty, arabic, numeric }

enum TouchKeyboardDock { left, center, right }

/// Global controller for the built-in visual touch keyboard (AZERTY / Arabic / Numeric).
/// Automatically pops up whenever ANY [EditableText] receives focus on touch POS screens.
class TouchKeyboardController extends ChangeNotifier {
  TouchKeyboardController._();
  static final TouchKeyboardController instance = TouchKeyboardController._();

  /// Enabled by default on Web/POS touch terminals; disabled in headless unit tests unless toggled.
  bool autoOpenEnabled = kIsWeb;
  bool _visible = false;
  TouchKeyboardMode _mode = TouchKeyboardMode.azerty;
  TouchKeyboardDock _dock = TouchKeyboardDock.left;
  bool _shift = false;
  bool _capsLock = false;
  EditableTextState? _activeEditable;

  bool get visible =>
      _visible && _activeEditable != null && _activeEditable!.mounted;
  TouchKeyboardMode get mode => _mode;
  TouchKeyboardDock get dock => _dock;
  bool get shift => _shift;
  bool get capsLock => _capsLock;
  bool get isUppercase => _shift || _capsLock;
  EditableTextState? get activeEditable {
    final e = _activeEditable;
    if (e == null || !e.mounted) {
      _activeEditable = null;
      return null;
    }
    return e;
  }

  void setAutoOpen(bool enabled) {
    autoOpenEnabled = enabled;
    if (!enabled) {
      _visible = false;
      _activeEditable = null;
    }
    notifyListeners();
  }

  void setMode(TouchKeyboardMode next) {
    if (_mode == next) return;
    _mode = next;
    notifyListeners();
  }

  void setDock(TouchKeyboardDock next) {
    if (_dock == next) return;
    _dock = next;
    notifyListeners();
  }

  /// Cycles: lowercase -> Shift (1 letter) -> CAPS LOCK (permanent) -> lowercase
  void toggleShift() {
    if (!_shift && !_capsLock) {
      _shift = true;
      _capsLock = false;
    } else if (_shift && !_capsLock) {
      _shift = false;
      _capsLock = true;
    } else {
      _shift = false;
      _capsLock = false;
    }
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
        _capsLock = false;
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
        kt ==
            const TextInputType.numberWithOptions(
                decimal: true, signed: true) ||
        kt == TextInputType.phone) {
      return TouchKeyboardMode.numeric;
    }
    return TouchKeyboardMode.azerty;
  }

  EditableTextState? _findFocusedEditable() {
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node is FocusScopeNode) return null;
    final ctx = node.context;
    if (ctx == null || !ctx.mounted) return null;
    if (ctx is StatefulElement && ctx.state is EditableTextState) {
      return ctx.state as EditableTextState;
    }
    final ancestor = ctx.findAncestorStateOfType<EditableTextState>();
    if (ancestor != null) return ancestor;
    EditableTextState? found;
    void visitor(Element el) {
      if (found != null) return;
      if (el is StatefulElement && el.state is EditableTextState) {
        final st = el.state as EditableTextState;
        if (st.widget.focusNode == node) {
          found = st;
        }
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
    final outText = (_mode == TouchKeyboardMode.azerty && isUppercase)
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
    if (_shift && !_capsLock) {
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

/// Root wrapper mounted inside [MaterialApp.builder] that floats the visual
/// Touch Keyboard at the bottom-left (leaving the right Cart/Checkout pane visible!).
class TouchKeyboardHost extends StatefulWidget {
  final Widget child;
  const TouchKeyboardHost({super.key, required this.child});

  @override
  State<TouchKeyboardHost> createState() => _TouchKeyboardHostState();
}

class _TouchKeyboardHostState extends State<TouchKeyboardHost> {
  final _kb = TouchKeyboardController.instance;
  final GlobalKey _keyboardPanelKey = GlobalKey();

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

  bool _isPointInsideContext(BuildContext? ctx, Offset globalPos) {
    if (ctx == null || !ctx.mounted) return false;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) return false;
    final topLeft = ro.localToGlobal(Offset.zero);
    final rect = topLeft & ro.size;
    // Small 10px tolerance around input field borders
    return rect.inflate(10).contains(globalPos);
  }

  void _handleGlobalPointerDown(PointerDownEvent event) {
    final pos = event.position;
    if (_kb.visible) {
      // Keep keyboard open when tapping inside the keyboard itself or the active text field
      if (_isPointInsideContext(_keyboardPanelKey.currentContext, pos)) return;
      if (_isPointInsideContext(_kb.activeEditable?.context, pos)) return;
      // Tapped anywhere else -> hide keyboard & unfocus seamlessly (iOS/Android UX)
      FocusManager.instance.primaryFocus?.unfocus();
      _kb.hide();
      return;
    }
    // If keyboard was dismissed while a TextField still holds focus, tapping it re-opens keyboard
    if (_kb.autoOpenEnabled &&
        _isPointInsideContext(_kb.activeEditable?.context, pos)) {
      _kb.openForCurrentFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleGlobalPointerDown,
      child: AnimatedBuilder(
        animation: _kb,
        builder: (context, _) {
          final show = _kb.visible;
          final align = switch (_kb.dock) {
            TouchKeyboardDock.left => Alignment.bottomLeft,
            TouchKeyboardDock.center => Alignment.bottomCenter,
            TouchKeyboardDock.right => Alignment.bottomRight,
          };
          return Stack(
            children: [
              Positioned.fill(child: widget.child),
              if (show)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Align(
                    alignment: align,
                    child: _DockedTouchKeyboardPanel(
                      key: _keyboardPanelKey,
                      kb: _kb,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DockedTouchKeyboardPanel extends StatelessWidget {
  final TouchKeyboardController kb;
  const _DockedTouchKeyboardPanel({super.key, required this.kb});

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
    final p = FullTekThemes.paletteOf(context);
    final screenW = MediaQuery.of(context).size.width;
    final editable = kb.activeEditable;
    final rawVal = editable?.textEditingValue.text ?? '';
    final isObscure = editable?.widget.obscureText == true;
    final preview = isObscure ? ('•' * rawVal.length) : rawVal;

    // On wide screens keep keyboard compact (~60% left side) so the right-side Cart & Checkout remain fully visible!
    final double panelMaxW = kb.mode == TouchKeyboardMode.numeric
        ? 360.0
        : (screenW >= 1100 ? 700.0 : (screenW * 0.68).clamp(340.0, 700.0));

    return TextFieldTapRegion(
      child: Material(
        key: const Key('global_touch_keyboard'),
        elevation: 18,
        borderRadius: BorderRadius.circular(16),
        color: p.surface,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: panelMaxW),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top control bar: mode switchers (FR / عربي / 123) + live preview + Dock L/C/R + Close
                Row(
                  children: [
                    _modePill(
                      key: const Key('touch_kb_mode_fr'),
                      label: 'FR',
                      active: kb.mode == TouchKeyboardMode.azerty,
                      onTap: () => kb.setMode(TouchKeyboardMode.azerty),
                      p: p,
                    ),
                    const SizedBox(width: 4),
                    _modePill(
                      key: const Key('touch_kb_mode_ar'),
                      label: 'عربي',
                      active: kb.mode == TouchKeyboardMode.arabic,
                      onTap: () => kb.setMode(TouchKeyboardMode.arabic),
                      p: p,
                    ),
                    const SizedBox(width: 4),
                    _modePill(
                      key: const Key('touch_kb_mode_num'),
                      label: '123',
                      active: kb.mode == TouchKeyboardMode.numeric,
                      onTap: () => kb.setMode(TouchKeyboardMode.numeric),
                      p: p,
                    ),
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 6),
                    // Quick position switcher (Left / Center / Right)
                    _dockIconBtn(
                      icon: Icons.align_horizontal_left_rounded,
                      active: kb.dock == TouchKeyboardDock.left,
                      onTap: () => kb.setDock(TouchKeyboardDock.left),
                      p: p,
                    ),
                    const SizedBox(width: 2),
                    _dockIconBtn(
                      icon: Icons.align_horizontal_center_rounded,
                      active: kb.dock == TouchKeyboardDock.center,
                      onTap: () => kb.setDock(TouchKeyboardDock.center),
                      p: p,
                    ),
                    const SizedBox(width: 2),
                    _dockIconBtn(
                      icon: Icons.align_horizontal_right_rounded,
                      active: kb.dock == TouchKeyboardDock.right,
                      onTap: () => kb.setDock(TouchKeyboardDock.right),
                      p: p,
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      key: const Key('touch_kb_close_btn'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: kb.hide,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: p.danger.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: p.danger.withValues(alpha: 0.4)),
                        ),
                        child: Icon(Icons.keyboard_hide_rounded,
                            size: 17, color: p.danger),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (kb.mode == TouchKeyboardMode.numeric)
                  _buildNumericPad(p)
                else
                  _buildAlphaPad(
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
    );
  }

  Widget _dockIconBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required PosPalette p,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: active ? p.primary.withValues(alpha: 0.2) : p.surfaceAlt,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? p.primary : p.border),
        ),
        child: Icon(icon, size: 15, color: active ? p.primary : p.textMuted),
      ),
    );
  }

  Widget _modePill({
    required Key key,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required PosPalette p,
  }) {
    return InkWell(
      key: key,
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

  Widget _buildNumericPad(PosPalette p) {
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
                  padding: const EdgeInsets.all(2.5),
                  child: _keyBtn(
                    key: Key('touch_kb_num_$k'),
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
    PosPalette p,
    List<List<String>> rows,
  ) {
    final isAzerty = kb.mode == TouchKeyboardMode.azerty;
    final shiftLabel = kb.capsLock
        ? '⇪ CAPS'
        : (kb.shift ? '⇧ MAJ' : '⇧ maj');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            children: row.map((k) {
              final shown = (isAzerty && kb.isUppercase) ? k.toUpperCase() : k;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _keyBtn(
                    key: Key('touch_kb_key_$k'),
                    label: shown,
                    p: p,
                    height: 39,
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
                  padding: const EdgeInsets.all(2),
                  child: _keyBtn(
                    key: const Key('touch_kb_shift_btn'),
                    label: shiftLabel,
                    p: p,
                    height: 40,
                    bg: kb.isUppercase ? p.primary : p.surfaceAlt,
                    fg: kb.isUppercase ? p.onPrimary : p.textPrimary,
                    onTap: kb.toggleShift,
                  ),
                ),
              ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _keyBtn(
                  key: const Key('touch_kb_space_btn'),
                  label: kb.mode == TouchKeyboardMode.arabic ? 'مسافة' : 'Espace',
                  p: p,
                  height: 40,
                  onTap: () => kb.insertText(' '),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _keyBtn(
                  key: const Key('touch_kb_backspace_btn'),
                  label: '⌫ Effacer',
                  p: p,
                  height: 40,
                  bg: p.warning.withValues(alpha: 0.16),
                  fg: p.warning,
                  onTap: kb.backspace,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _keyBtn(
                  key: const Key('touch_kb_ok_btn'),
                  label: '✓ OK',
                  p: p,
                  height: 40,
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
    Key? key,
    required String label,
    required PosPalette p,
    required VoidCallback onTap,
    double height = 39,
    Color? bg,
    Color? fg,
  }) {
    return Material(
      color: bg ?? p.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: fg ?? p.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
