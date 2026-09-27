import 'package:flutter/material.dart';
import 'chat_connection_manager.dart';
import 'chat_event.dart';

/// شاشة تجربة مؤقتة لـ P-073 — مش جزء من الـ Part نفسه، ومش المفروض
/// تتعمل عليها commit نهائي. امسحها لما P-074 (chat UI) يتعمل.
void main() {
  runApp(const _DebugChatApp());
}

class _DebugChatApp extends StatelessWidget {
  const _DebugChatApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: _DebugChatScreen());
  }
}

class _DebugChatScreen extends StatefulWidget {
  const _DebugChatScreen();

  @override
  State<_DebugChatScreen> createState() => _DebugChatScreenState();
}

class _DebugChatScreenState extends State<_DebugChatScreen> {
  // === معبّاة بالقيم الحقيقية من جلسة الاختبار ===
  static const _token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzkwNDk5MDA5LCJpYXQiOjE3OTA0OTgxMDksImp0aSI6Ijg0ODc4N2YwOGIwZTQ4M2M4OWU1Y2ViYmQxMDI3OGEyIiwidXNlcl9pZCI6IjI1In0.BOoZ458MROY52YvW2L44PeujkzXkr4-wNRA6GELtusw'; // TOKEN_A (user_id 25) — access token, بينتهي بسرعة فاختبر بسرعة
  static const _baseUrl = 'http://10.0.2.2:8095'; // عدّل حسب AppConfig.apiBaseUrl الحقيقي عندك
  static const _conversationId = 1; // CONVERSATION_ID الحقيقي من الجلسة

  late final ChatConnectionManager _manager;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _manager = ChatConnectionManager(
      getAccessToken: () async => _token,
      getApiBaseUrl: () => _baseUrl,
    );
    _manager.connectionState.listen((s) => _addLog('STATE: $s'));
    _manager.eventStream.listen((e) => _addLog('EVENT: $e'));
  }

  void _addLog(String line) {
    setState(() => _log.insert(0, '${DateTime.now().toIso8601String()}  $line'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('P-073 Debug Harness')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _manager.connect(_conversationId),
                  child: const Text('connect()'),
                ),
                ElevatedButton(
                  onPressed: _manager.disconnect,
                  child: const Text('disconnect()'),
                ),
                ElevatedButton(
                  onPressed: () => _manager.sendTyping(true),
                  child: const Text('sendTyping(true)'),
                ),
                ElevatedButton(
                  onPressed: _manager.sendHeartbeat,
                  child: const Text('sendHeartbeat()'),
                ),
              ],
            ),
          ),
          Text('Current state: ${_manager.currentState}'),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (_, i) => Text(_log[i], style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}