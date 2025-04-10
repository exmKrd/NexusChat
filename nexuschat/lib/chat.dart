// ✅ chat.dart (corrigé sans ChatApp)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String usernameExpediteur;

  const ChatScreen({super.key, required this.usernameExpediteur});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> messages = [];
  String? expediteur;
  late String destinataire;
  int idConversation = 0;
  bool _isButtonEnabled = false;
  late Timer _pollingTimer;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    destinataire = widget.usernameExpediteur;
    _loadExpediteur();
    _controller.addListener(_updateButtonState);
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _fetchMessages();
    });
  }

  @override
  void dispose() {
    _pollingTimer.cancel();
    _controller.removeListener(_updateButtonState);
    _controller.dispose();
    super.dispose();
  }

  Future<void> searchId() async {
    try {
      final uri =
          Uri.parse('https://nexuschat.derickexm.be/conversation/get_id/')
              .replace(queryParameters: {
        'user1': expediteur!,
        'user2': destinataire,
      });
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is Map<String, dynamic> &&
            jsonResponse.containsKey('conversations')) {
          List<dynamic> conversations = jsonResponse['conversations'];
          if (conversations.isNotEmpty && conversations[0].containsKey('id')) {
            int? idConv = int.tryParse(conversations[0]['id'].toString());
            if (idConv != null) {
              setState(() {
                idConversation = idConv;
              });
              _fetchMessages();
            }
          }
        }
      }
    } catch (e) {
      print('❌ Erreur searchId: $e');
    }
  }

  Future<void> _checkConv() async {
    if (expediteur == null) return;
    try {
      final uri =
          Uri.parse('https://nexuschat.derickexm.be/conversation/check_conv/')
              .replace(queryParameters: {
        'user1': expediteur!,
        'user2': destinataire,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['exists'] == true) {
          searchId();
        } else {
          await _createConv();
        }
      }
    } catch (e) {
      print('Erreur checkConv: $e');
    }
  }

  Future<void> _createConv() async {
    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/conversation/create_conv/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user1': expediteur,
          'user2': destinataire,
        }),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('id_conversation')) {
          int? idConv = jsonResponse['id_conversation'];
          if (idConv != null) {
            setState(() {
              idConversation = idConv;
            });
            _fetchMessages();
          }
        }
      }
    } catch (e) {
      print('Erreur createConv: $e');
    }
  }

  Future<void> _fetchMessages() async {
    if (idConversation <= 0) return;
    try {
      final uri =
          Uri.parse('https://nexuschat.derickexm.be/messages/get_message/')
              .replace(queryParameters: {'id_conv': idConversation.toString()});
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('messages')) {
          final List<dynamic> messagesList = jsonResponse['messages'];
          setState(() {
            messages = messagesList.map((msg) {
              bool isMe = msg['expediteur'].toString() == expediteur;
              return {
                'sender': isMe ? 'me' : 'bot',
                'text': msg['messages'].toString(),
              };
            }).toList();
            _isInitialLoading = false;
          });
        }
      }
    } catch (e) {
      print('Erreur fetchMessages: $e');
    }
  }

  Future<void> _loadExpediteur() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? expediteurEmail =
        prefs.getString('user_email') ?? widget.usernameExpediteur;
    try {
      final uri =
          Uri.parse('https://nexuschat.derickexm.be/users/get_username/')
              .replace(queryParameters: {'email': expediteurEmail});
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('username')) {
          setState(() {
            expediteur = jsonResponse['username'];
          });
        }
      }
    } catch (e) {
      print('Erreur loadExpediteur: $e');
    } finally {
      _checkConv();
    }
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _controller.text.isNotEmpty;
    });
  }

  Future<void> sendMessage(String message) async {
    setState(() {
      messages.add({'sender': 'me', 'text': message});
    });
    _controller.clear();
    _updateButtonState();
    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/messages/send_message/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'expediteur': expediteur,
          'destinataire': destinataire,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
          'id_conversation': idConversation,
        }),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('reply')) {
          setState(() {
            messages.add({'sender': 'bot', 'text': jsonResponse['reply']});
          });
        }
      }
    } catch (e) {
      print('Erreur sendMessage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(destinataire),
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message['sender'] == 'me';
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.orange : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message['text']!,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Écrire un message...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _isButtonEnabled
                            ? () => sendMessage(_controller.text)
                            : null,
                        color: _isButtonEnabled ? Colors.orange : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
