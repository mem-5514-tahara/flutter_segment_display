import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:segment_display/src/character_segment_map.dart';
import 'package:segment_display/src/display/fourteen_segment_display.dart';
import 'package:segment_display/src/display/seven_segment_display.dart';
import 'package:segment_display/src/display/sixteen_segment_display.dart';
import 'package:segment_display/src/segment_style/segment_style.dart';

/// Selects which segment display type [SegmentDisplayField] renders.
enum SegmentDisplayType {
  /// 7-segment display.
  seven,

  /// 14-segment display.
  fourteen,

  /// 16-segment display.
  sixteen,
}

/// An interactive segment display that accepts keyboard input.
///
/// Tap to focus and bring up the keyboard. Characters not supported by the
/// chosen [displayType] are silently dropped. The display holds its current
/// value while the IME is composing (CJK 2-stage input).
///
/// ## Cursor
/// When focused a blinking [showCursor] character appears at the end of the
/// text using [customCharacterMap] so the existing paint pipeline is reused
/// without modification.
///
/// ## IME
/// [keyboardType] defaults to [TextInputType.number] for 7-segment (numbers
/// only) and [TextInputType.visiblePassword] for 14/16-segment — both bypass
/// IME inline conversion on most platforms.
class SegmentDisplayField extends StatefulWidget {
  const SegmentDisplayField({
    super.key,
    required this.displayType,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.showCursor = true,
    this.cursorBlinkDuration = const Duration(milliseconds: 500),
    this.size = 10.0,
    this.characterSpacing = 7.0,
    this.backgroundColor,
    this.segmentStyle,
    this.showDisabledDividers = false,
    this.keyboardType,
    this.customCharacterMap,
  });

  final SegmentDisplayType displayType;

  /// Controller for the text being edited. Internally managed when omitted.
  final TextEditingController? controller;

  /// Manages focus for this field. Internally managed when omitted.
  final FocusNode? focusNode;

  /// Called whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard action button is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Maximum characters to accept. Maps to [SegmentDisplay.characterCount].
  final int? maxLength;

  /// Whether to show a blinking cursor glyph when focused.
  final bool showCursor;

  /// Half-period of the cursor blink animation.
  final Duration cursorBlinkDuration;

  // --- SegmentDisplay visual parameters ---

  final double size;
  final double characterSpacing;
  final Color? backgroundColor;
  final SegmentStyle? segmentStyle;
  final bool showDisabledDividers;

  /// Platform keyboard type. Defaults to [TextInputType.number] for 7-segment
  /// and [TextInputType.visiblePassword] for 14/16-segment to avoid IME
  /// inline conversion on most platforms.
  final TextInputType? keyboardType;

  /// Additional or override character-to-bitmask entries, merged on top of the
  /// built-in map for [displayType].
  final Map<String, int>? customCharacterMap;

  @override
  State<SegmentDisplayField> createState() => _SegmentDisplayFieldState();
}

class _SegmentDisplayFieldState extends State<SegmentDisplayField>
    implements TextInputClient {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  TextInputConnection? _connection;
  Timer? _cursorTimer;
  bool _cursorVisible = false;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  // Cursor glyph per display type.
  static const _cursorChar = {
    SegmentDisplayType.seven: '_',
    SegmentDisplayType.fourteen: '|',
    SegmentDisplayType.sixteen: '|',
  };

  // Bitmask for each cursor glyph injected via customCharacterMap.
  // _ = 0x08 (bottom bar) for 7-seg; | = 0x0012 (centre vertical) for 14/16-seg.
  static const _cursorBitmask = {
    SegmentDisplayType.seven: <String, int>{'_': 0x08},
    SegmentDisplayType.fourteen: <String, int>{'|': 0x0012},
    SegmentDisplayType.sixteen: <String, int>{'|': 0x0012},
  };

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SegmentDisplayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _ownsController = widget.controller == null;
      _controller = widget.controller ?? TextEditingController();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (_ownsFocusNode) _focusNode.dispose();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _connection?.close();
    _focusNode.removeListener(_onFocusChange);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _attach();
      if (widget.showCursor) _startCursorTimer();
    } else {
      _connection?.close();
      _connection = null;
      _stopCursorTimer();
    }
  }

  void _attach() {
    final keyboardType = widget.keyboardType ??
        (widget.displayType == SegmentDisplayType.seven
            ? TextInputType.number
            : TextInputType.visiblePassword);

    _connection = TextInput.attach(
      this,
      TextInputConfiguration(
        inputType: keyboardType,
        inputAction: TextInputAction.done,
      ),
    )
      ..show()
      ..setEditingState(_editingValue);
  }

  void _startCursorTimer() {
    _cursorVisible = true;
    _cursorTimer = Timer.periodic(widget.cursorBlinkDuration, (_) {
      if (mounted) setState(() => _cursorVisible = !_cursorVisible);
    });
  }

  void _stopCursorTimer() {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    if (mounted) setState(() => _cursorVisible = false);
  }

  // ---------------------------------------------------------------------------
  // TextInputClient
  // ---------------------------------------------------------------------------

  TextEditingValue get _editingValue {
    final text = _controller.text;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  TextEditingValue get currentTextEditingValue => _editingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    // While composing (e.g. CJK 2-stage input), hold display until confirmed.
    if (value.composing.isValid) return;

    final filtered = _filterText(value.text);
    if (filtered == _controller.text) return;

    _controller.text = filtered;
    widget.onChanged?.call(filtered);
    // Reflect the filtered value back to the IME, cursor pinned to end.
    _connection?.setEditingState(_editingValue);
    setState(() {});
  }

  @override
  void performAction(TextInputAction action) {
    widget.onSubmitted?.call(_controller.text);
    _focusNode.unfocus();
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void connectionClosed() => _stopCursorTimer();

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void showToolbar() {}

  @override
  void performSelector(String selectorName) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _filterText(String raw) {
    final map = _effectiveCharacterMap();
    final dividers = CharacterSegmentMap.dividerCharacters.values.toSet();
    var filtered = raw
        .split('')
        .where((c) => map.containsKey(c) || dividers.contains(c))
        .join();

    final limit = widget.maxLength;
    if (limit != null && filtered.length > limit) {
      filtered = filtered.substring(filtered.length - limit);
    }
    return filtered;
  }

  Map<String, int> _effectiveCharacterMap() {
    final base = switch (widget.displayType) {
      SegmentDisplayType.seven => CharacterSegmentMap.seven,
      SegmentDisplayType.fourteen => CharacterSegmentMap.fourteen,
      SegmentDisplayType.sixteen => CharacterSegmentMap.sixteen,
    };
    final custom = widget.customCharacterMap;
    return custom == null ? base : {...base, ...custom};
  }

  String get _displayValue {
    final text = _controller.text;
    final isFull =
        widget.maxLength != null && text.length >= widget.maxLength!;
    if (!widget.showCursor ||
        !_focusNode.hasFocus ||
        !_cursorVisible ||
        isFull) {
      return text;
    }
    return '$text${_cursorChar[widget.displayType]}';
  }

  // Cursor bitmask takes precedence so it always renders correctly.
  Map<String, int> get _mergedCustomMap => {
        ...?widget.customCharacterMap,
        ..._cursorBitmask[widget.displayType]!,
      };

  // When maxLength is unset and cursor is active, reserve a slot for the
  // cursor glyph so the display width doesn't jitter on each blink cycle.
  int? get _characterCount {
    if (widget.maxLength != null) return widget.maxLength;
    if (widget.showCursor && _focusNode.hasFocus) {
      return _controller.text.length + 1;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final value = _displayValue;
    final customMap = _mergedCustomMap;
    final characterCount = _characterCount;

    return Focus(
      focusNode: _focusNode,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focusNode.requestFocus(),
        child: switch (widget.displayType) {
          SegmentDisplayType.seven => SevenSegmentDisplay(
              value: value,
              size: widget.size,
              characterSpacing: widget.characterSpacing,
              backgroundColor:
                  widget.backgroundColor ?? const Color(0xff000000),
              segmentStyle: widget.segmentStyle,
              showDisabledDividers: widget.showDisabledDividers,
              characterCount: characterCount,
              customCharacterMap: customMap,
            ),
          SegmentDisplayType.fourteen => FourteenSegmentDisplay(
              value: value,
              size: widget.size,
              characterSpacing: widget.characterSpacing,
              backgroundColor:
                  widget.backgroundColor ?? const Color(0xff000000),
              segmentStyle: widget.segmentStyle,
              showDisabledDividers: widget.showDisabledDividers,
              characterCount: characterCount,
              customCharacterMap: customMap,
            ),
          SegmentDisplayType.sixteen => SixteenSegmentDisplay(
              value: value,
              size: widget.size,
              characterSpacing: widget.characterSpacing,
              backgroundColor:
                  widget.backgroundColor ?? const Color(0xff000000),
              segmentStyle: widget.segmentStyle,
              showDisabledDividers: widget.showDisabledDividers,
              characterCount: characterCount,
              customCharacterMap: customMap,
            ),
        },
      ),
    );
  }
}
