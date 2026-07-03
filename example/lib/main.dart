import 'package:flutter/material.dart';
import 'package:segment_display/segment_display.dart';
import 'package:intl/intl.dart';

void main() => runApp(const App(title: 'Segment display example'));

class App extends StatefulWidget {
  const App({super.key, required this.title});

  final String title;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late int _displayType;
  late SegmentStyle _segmentStyle;
  late Color _accentColor;
  late String _text;
  late TextEditingController _controller;
  String _submittedText = '';

  @override
  void initState() {
    super.initState();
    _accentColor = const Color(0xFFFF0000);
    _displayType = 0;
    _segmentStyle = DefaultSegmentStyle(
      enabledColor: _accentColor,
      disabledColor: _accentColor.withValues(alpha: 0.15),
    );
    _text = 'HELLO';
    _controller = TextEditingController();
    _controller.value = TextEditingValue(text: _text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeSegmentStyle(SegmentStyle segmentStyle) {
    setState(() {
      _segmentStyle = segmentStyle;
    });
  }

  void _changeDisplayType(int type) {
    setState(() {
      _displayType = type;
    });
  }

  SegmentDisplayType get _fieldDisplayType {
    const types = [
      SegmentDisplayType.seven,
      SegmentDisplayType.fourteen,
      SegmentDisplayType.sixteen,
    ];
    return types[_displayType];
  }

  void _changeColor(Color color) {
    setState(() {
      _accentColor = color;
      _segmentStyle = _segmentStyle.copyWith(
        enabledColor: _accentColor,
        disabledColor: _accentColor.withValues(alpha: 0.15),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.title,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accentColor,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            PopupMenuButton<SegmentStyle>(
              tooltip: 'Segment style',
              icon: const Icon(Icons.style),
              onSelected: _changeSegmentStyle,
              itemBuilder: (context) {
                return [
                  PopupMenuItem<SegmentStyle>(
                    value: DefaultSegmentStyle(
                      enabledColor: _accentColor,
                      disabledColor: _accentColor.withValues(alpha: 0.15),
                    ),
                    child: const Text('Default'),
                  ),
                  PopupMenuItem<SegmentStyle>(
                    value: RectSegmentStyle(
                      enabledColor: _accentColor,
                      disabledColor: _accentColor.withValues(alpha: 0.15),
                    ),
                    child: const Text('Rect'),
                  ),
                  PopupMenuItem<SegmentStyle>(
                    value: HexSegmentStyle(
                      enabledColor: _accentColor,
                      disabledColor: _accentColor.withValues(alpha: 0.15),
                    ),
                    child: const Text('Hex'),
                  ),
                ];
              },
            ),
            PopupMenuButton<int>(
              tooltip: 'Display type',
              icon: const Icon(Icons.filter_7),
              onSelected: _changeDisplayType,
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<int>(value: 0, child: Text('7-segment')),
                  const PopupMenuItem<int>(value: 1, child: Text('14-segment')),
                  const PopupMenuItem<int>(value: 2, child: Text('16-segment')),
                ];
              },
            ),
            PopupMenuButton<Color>(
              tooltip: 'Color',
              icon: const Icon(Icons.color_lens),
              onSelected: _changeColor,
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<Color>(
                    value: Color(0xFFFF0000),
                    child: Text('Red'),
                  ),
                  const PopupMenuItem<Color>(
                    value: Color(0xFF00FF00),
                    child: Text('Green'),
                  ),
                  const PopupMenuItem<Color>(
                    value: Color(0xFF0000FF),
                    child: Text('Blue'),
                  ),
                  const PopupMenuItem<Color>(
                    value: Color(0xFF00FFFF),
                    child: Text('Cyan'),
                  ),
                  const PopupMenuItem<Color>(
                    value: Color(0xFFFFFF00),
                    child: Text('Yellow'),
                  ),
                  const PopupMenuItem<Color>(
                    value: Color(0xFFFFFFFF),
                    child: Text('White'),
                  ),
                ];
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Display(
                  value: DateFormat('HH:mm').format(DateTime.now()),
                  size: 7.0,
                  type: _displayType,
                  style: _segmentStyle,
                ),
                const SizedBox(height: 100),
                _Display(
                  value: _text,
                  size: 7.0,
                  type: _displayType,
                  style: _segmentStyle,
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: 250.0,
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Change me',
                    ),
                    maxLength: 20,
                    onChanged: (String text) async {
                      setState(() => _text = text.isEmpty ? ' ' : text);
                    },
                  ),
                ),
                const SizedBox(height: 60),
                const Divider(color: Colors.white24),
                const SizedBox(height: 20),
                Text(
                  'SegmentDisplayField — tap to type',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _accentColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SegmentDisplayField(
                        displayType: _fieldDisplayType,
                        size: 5.0,
                        maxLength: 8,
                        segmentStyle: _segmentStyle,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (text) =>
                            setState(() => _submittedText = text),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'tap · type · done to submit',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_submittedText.isNotEmpty)
                  Text(
                    'Submitted: $_submittedText',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white54),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Display extends StatelessWidget {
  final String value;
  final int type;
  final double size;
  final SegmentStyle style;

  const _Display({
    required this.value,
    required this.type,
    required this.style,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final displays = [
      SevenSegmentDisplay(value: value, size: size, segmentStyle: style),
      FourteenSegmentDisplay(value: value, size: size, segmentStyle: style),
      SixteenSegmentDisplay(value: value, size: size, segmentStyle: style),
    ];

    return displays[type];
  }
}
