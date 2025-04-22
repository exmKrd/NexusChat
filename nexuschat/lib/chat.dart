import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

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
    _focusNode.dispose();
    _scrollController.dispose();
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
                'sender': msg['expediteur'].toString(),
                'text': msg['messages'].toString(),
                'timestamp': msg['sent_at'].toString(),
              };
            }).toList();
            _isInitialLoading = false;
          });
          _scrollToBottom();
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
      _isButtonEnabled = _controller.text.trim().isNotEmpty;
    });
  }

  Future<void> sendMessage(String message) async {
    if (expediteur == null || message.trim().isEmpty) return;

    final now = DateTime.now();

    setState(() {
      messages.add({
        'sender': expediteur!,
        'text': message.trim(),
        'timestamp': now.toIso8601String(),
      });
    });
    _controller.clear();
    _updateButtonState();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/messages/send_message/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'expediteur': expediteur,
          'destinataire': destinataire,
          'message': message.trim(),
          'sent_at': now.toIso8601String(),
          'id_conversation': idConversation,
        }),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('reply')) {
          setState(() {
            messages.add({
              'sender': destinataire,
              'text': jsonResponse['reply'],
              'timestamp': DateTime.now().toIso8601String(),
            });
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Erreur sendMessage: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _selectPhoto() {
    print('Sélectionner une photo');
  }

  void _selectGif() {
    print('Sélectionner un GIF');
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
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message['sender'] == expediteur;

                      // Formatage de l'heure
                      final time =
                          DateTime.tryParse(message['timestamp'] ?? '');
                      final formattedTime = time != null
                          ? "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"
                          : '';

                      return Container(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['sender'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.orange : Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                message['text'] ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            if (formattedTime.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  formattedTime,
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[600]),
                                ),
                              ),
                          ],
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
                          focusNode: _focusNode,
                          style: TextStyle(fontSize: 16),
                          cursorColor: Colors.orange,
                          decoration: InputDecoration(
                            hintText: 'Entrez votre message...',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onChanged: (text) => _updateButtonState(),
                          onEditingComplete: () {},
                          inputFormatters: [
                            _EnterKeyFormatter(
                              onEnter: () {
                                if (_controller.text.trim().isNotEmpty) {
                                  sendMessage(_controller.text);
                                  _controller
                                      .clear(); // 👈 Ajout explicite du clear ici
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.send, color: Colors.black),
                          onPressed: _isButtonEnabled
                              ? () => sendMessage(_controller.text)
                              : null,
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ✅ Formatter : Enter = envoi / Shift+Enter = saut de ligne
class _EnterKeyFormatter extends TextInputFormatter {
  final VoidCallback onEnter;

  _EnterKeyFormatter({required this.onEnter});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length > oldValue.text.length &&
        newValue.text.endsWith('\n') &&
        !RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.shiftLeft) &&
        !RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.shiftRight)) {
      onEnter();
      return const TextEditingValue(text: ''); // vide le champ après envoi
    }
    return newValue;
  }
}
