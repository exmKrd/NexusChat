import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_giphy_picker/giphy_ui.dart';
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

  List<Map<String, dynamic>> messages = [];
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

  Future<Map<String, String>> _chiffrerMessage(String message) async {
    final uri =
        Uri.parse('https://nexuschat.derickexm.be/messages/crypt_message/')
            .replace(queryParameters: {'message': message});
    final response = await http.post(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("Chiffrement → encrypted_message: ${data['encrypted_message']}");
      print("Chiffrement → key: ${data['key']}");
      return {
        'encrypted_message': data['encrypted_message'] ?? message,
        'key': data['key'] ?? ''
      };
    } else {
      print("Erreur chiffrement: ${response.body}");
      return {'encrypted_message': message, 'key': ''};
    }
  }

  Future<String> _dechiffrerMessage(String encryptedMessage, String key) async {
    final uri =
        Uri.parse('https://nexuschat.derickexm.be/messages/uncrypt_message/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'encrypted_message': encryptedMessage,
        'key': key,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['decrypted_message'] ?? encryptedMessage;
    } else {
      print("Erreur déchiffrement: ${response.body}");
      return encryptedMessage;
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
          final decryptedMessages =
              await Future.wait(messagesList.map((msg) async {
            final isMe = msg['expediteur'].toString() == expediteur;

            final encrypted = msg['messages'].toString();
            final cle = msg['key']?.toString() ?? '';
            final texte = await _dechiffrerMessage(encrypted, cle);
            return {
              'sender': msg['expediteur'].toString(),
              'text': texte,
              'encrypted': msg['messages'].toString(),
              'timestamp': msg['sent_at'].toString(),
              'key': msg['key']?.toString() ?? '',
              'type': msg['type'] ?? 'text'
            };
          }));
          setState(() {
            messages = decryptedMessages;
            _isInitialLoading = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Erreur fetchMessages: $e');
    }
  }

  Future<void> _supprimerMessage(Map<String, dynamic> message) async {
    try {
      final uri = Uri.parse(
          'https://nexuschat.derickexm.be/messages/messages/delete_message/');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'expediteur': expediteur,
          'id_conversation': idConversation,
          'message': message['encrypted'],
          'key': message['key'],
        }),
      );
      if (response.statusCode == 200) {
        print("✅ Message supprimé");
        _fetchMessages(); // refresh
      } else {
        print("❌ Erreur suppression: ${response.body}");
      }
    } catch (e) {
      print("❌ Erreur _supprimerMessage: $e");
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
          print("📦 Chargement expediteur : $expediteur");
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
    print("🧪 Appel à sendMessage()...");
    print("🔍 expediteur: $expediteur");
    if (expediteur == null || message.trim().isEmpty) return;

    final now = DateTime.now();

    final cryptoData = await _chiffrerMessage(message.trim());
    print("Résultat chiffrement : $cryptoData");
    final encryptedMessage = cryptoData['encrypted_message'] ?? '';
    final key = cryptoData['key'] ?? '';
    // Ajout du texte en clair
    final plainText = _controller.text.trim();
    if (key == null || key.isEmpty) {
      print('❌ Clé de chiffrement manquante. Message non envoyé.');
      return;
    }

    setState(() {
      messages = List<Map<String, dynamic>>.from(messages)
        ..add({
          'sender': expediteur ?? '',
          'text': plainText,
          'encrypted': encryptedMessage,
          'timestamp': now.toIso8601String(),
          'key': key,
          'type': 'text'
        });
    });
    _controller.clear();
    _updateButtonState();
    _scrollToBottom();

    print("✉️ Envoi du message chiffré : $encryptedMessage");
    print("🔑 Clé : $key");

    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/messages/send_message/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'expediteur': expediteur,
          'destinataire': destinataire,
          'message': encryptedMessage,
          // Correction : horodatage en heure locale (Belgique)
          'timestamp': DateTime.now().toIso8601String(),
          'id_conversation': idConversation,
          // Correction : forcer 'key' non vide
          'key': key.isNotEmpty ? key : 'test'
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

  Future<void> _sendGif(String gifUrl) async {
    if (expediteur == null || gifUrl.isEmpty) return;
    print('📤 Préparation à l’envoi du GIF :');
    print('  ↪️ URL : $gifUrl');

    final nowUtcIso = DateTime.now().toIso8601String();
    // Désactivation du chiffrement pour les GIFs
    final encryptedMessage = gifUrl;
    final key = 'test';
    print('  🔐 Encrypted : $encryptedMessage');
    print('  🔑 Key : $key');
    print('  💬 ID conversation : $idConversation');
    setState(() {
      messages = List<Map<String, dynamic>>.from(messages)
        ..add({
          'sender': expediteur ?? '',
          'text': gifUrl,
          'encrypted': encryptedMessage,
          'timestamp': nowUtcIso,
          'key': key,
          'type': 'gif'
        });
    });
    _scrollToBottom();

    final body = jsonEncode({
      'expediteur': expediteur,
      'destinataire': destinataire,
      'message': encryptedMessage,
      'timestamp': nowUtcIso,
      'id_conversation': idConversation,
      'key': key,
      'type': 'gif'
    });
    print("📦 Corps envoyé à l’API :");
    print("  expediteur     : ${expediteur}");
    print("  destinataire   : ${destinataire}");
    print("  message        : $encryptedMessage");
    print("  key            : $key");
    print("  timestamp      : $nowUtcIso");
    print("  id_conversation: $idConversation");
    print("  type           : gif");
    print("🔒 Longueur message : ${encryptedMessage.length}");
    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/messages/send_message/'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode != 200) {
        print('Erreur envoi GIF : ${response.body}');
      } else {
        print('✅ GIF envoyé avec succès.');
      }
    } catch (e) {
      print('Erreur réseau envoi GIF : $e');
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

  Future<void> _selectGif() async {
    GiphyLocale? fr;
    fr ??= GiphyLocale.fromContext(context);

    final config = GiphyUIConfig(
      apiKey: 'qG62ngUKbr66l2jVPcDGulJW1RbZy5xI',
    );
    final result =
        await showGiphyPicker(context, config, locale: GiphyLocale.fr);

    if (result != null) {
      print("GIF sélectionné : ${result.url}");
      _sendGif(result.url);
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: isMe
                                        ? () {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Text(
                                                      "Supprimer le message ?"),
                                                  actions: [
                                                    TextButton(
                                                      child: Text("Annuler"),
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(),
                                                    ),
                                                    TextButton(
                                                      child: Text("Supprimer"),
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                        _supprimerMessage(
                                                            message);
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          }
                                        : null,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? Colors.orange
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: message['type'] == 'gif'
                                          ? Image.network(message['text'] ?? '')
                                          : Text(
                                              message['text'] ?? '',
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
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
                              color: Colors.orange.shade100, // plus doux
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.gif_box,
                                  color: Colors.deepOrange, size: 28),
                              onPressed: _selectGif,
                              tooltip: 'GIF',
                            ),
                          ),
                          SizedBox(width: 5),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.send, color: Colors.black),
                              onPressed: _isButtonEnabled
                                  ? () {
                                      sendMessage(_controller.text);
                                      _controller.clear();
                                      _updateButtonState();
                                    }
                                  : null,
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, top: 2),
                        child: Text(
                          "🔒 Messages chiffrés de bout en bout",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
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
