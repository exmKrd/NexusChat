import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_giphy_picker/giphy_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    destinataire = widget.usernameExpediteur;
    _loadExpediteur();
    _controller.addListener(_updateButtonState);
    _startPolling();
    _scrollController.addListener(() {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      final threshold = 100.0;

      final shouldShow = (maxScroll - currentScroll) > threshold;

      if (shouldShow != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = shouldShow;
        });
      }
    });
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
        Uri.parse('https://nexuschat.derickexm.be/messages/uncrypt_messages/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "messages": [
          {"encrypted_message": encryptedMessage, "key": key}
        ]
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null &&
          data['results'] is List &&
          data['results'].isNotEmpty) {
        final first = data['results'][0];
        return first['decrypted_message'] ?? encryptedMessage;
      } else {
        return encryptedMessage;
      }
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

          final batch = messagesList
              .map((msg) => {
                    "encrypted_message": msg['messages'].toString(),
                    "key": msg['key']?.toString() ?? ''
                  })
              .toList();

          final decryptUri = Uri.parse(
              'https://nexuschat.derickexm.be/messages/uncrypt_messages/');
          final decryptResponse = await http.post(
            decryptUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"messages": batch}),
          );

          List<String> textesDecryptes = [];

          if (decryptResponse.statusCode == 200) {
            final decryptedData = jsonDecode(decryptResponse.body);
            if (decryptedData['results'] is List) {
              textesDecryptes = List<String>.from(decryptedData['results']
                  .map((item) => item['decrypted_message'] ?? ''));
            }
          }

          final List<Map<String, dynamic>> finalMessages = [];
          for (int i = 0; i < messagesList.length; i++) {
            final msg = messagesList[i];
            final text = i < textesDecryptes.length
                ? textesDecryptes[i]
                : msg['messages'].toString();
            finalMessages.add({
              'sender': msg['expediteur'].toString(),
              'text': text,
              'encrypted': msg['messages'].toString(),
              'sent_at': msg['sent_at'].toString(),
              'key': msg['key']?.toString() ?? '',
              'type': msg['type'] ?? 'text',
            });
            print(msg['sent_at'].toString());
          }

          setState(() {
            messages = finalMessages;
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
        print(" Message supprimé");
        _fetchMessages(); // refresh
      } else {
        print("Erreur suppression: ${response.body}");
      }
    } catch (e) {
      print(" Erreur _supprimerMessage: $e");
    }
  }

  Future<void> _sendnotification(String messageText) async {
    if (destinataire.isEmpty) return;

    final url =
        Uri.parse("https://nexuschat.derickexm.be/users/send_notifications");
    final body = jsonEncode({
      'destinataire': destinataire,
      'type': 'text',
      'contenu': messageText,
      'owner': expediteur
    });

    try {
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'}, body: body);
      if (response.statusCode == 200) {
        print("✅ Notification envoyée.");
      } else {
        print("❌ Erreur envoi notification: ${response.body}");
      }
    } catch (e) {
      print("❌ Exception envoi notification: $e");
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

    final cryptoData = await _chiffrerMessage(message.trim());
    final encryptedMessage = cryptoData['encrypted_message'] ?? '';
    final key = cryptoData['key'] ?? '';
    final plainText = _controller.text.trim();

    // --- MODIFIED LINE FOR TIMESTAMP ---
    // Get current local time, then convert to UTC, then add 2 hours (for CEST / UTC+2)
    // This ensures the time sent is what CEST time would be for this moment.
    final nowCestTime = DateTime.now().toUtc().add(Duration(hours: 2));
    final nowCestIsoFormatted =
        DateFormat("yyyy-MM-dd HH:mm:ss").format(nowCestTime);

    if (key.isEmpty) {
      print('❌ Clé de chiffrement manquante. Message non envoyé.');
      return;
    }

    // Affichage local temporaire (sera remplacé par le polling)
    setState(() {
      messages = List<Map<String, dynamic>>.from(messages)
        ..add({
          'sender': expediteur ?? '',
          'text': plainText,
          'encrypted': encryptedMessage,
          'timestamp': 'En cours...', // Temporaire, will be updated by polling
          'key': key,
          'type': 'text'
        });
    });
    _controller.clear();
    _updateButtonState();
    _scrollToBottom();

    print("✉️ Envoi du message chiffré : $encryptedMessage");
    print("🔑 Clé : $key");
    print(
        "⏰ Timestamp envoyé à l'API (CEST): $nowCestIsoFormatted"); // Add this debug print

    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/messages/send_message/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'expediteur': expediteur,
          'destinataire': destinataire,
          'message': encryptedMessage,
          'id_conversation': idConversation,
          'key': key,
          'type': 'text',
          'timestamp':
              nowCestIsoFormatted, // --- USE THE CEST FORMATTED STRING ---
        }),
      );

      print("📡 Status Code: ${response.statusCode}");
      print("📡 Response: ${response.body}");

      if (response.statusCode == 200) {
        print("✅ Message envoyé avec succès");

        await Future.delayed(Duration(milliseconds: 500));
        await _fetchMessages();

        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse.containsKey('reply')) {
          setState(() {
            messages.add({
              'sender': destinataire,
              'text': jsonResponse['reply'],
              'timestamp': 'À l\'instant',
              'type': 'text'
            });
          });
          _scrollToBottom();
        }
        await _sendnotification(message.trim());
      } else {
        print('❌ Erreur HTTP ${response.statusCode}: ${response.body}');
        setState(() {
          messages.removeLast();
        });
      }
    } catch (e) {
      print('❌ Erreur exception sendMessage: $e');
      setState(() {
        messages.removeLast();
      });
    }
  }

// 🎭 Fonction _sendGif simplifiée
  Future<void> _sendGif(String gifUrl) async {
    if (expediteur == null || gifUrl.isEmpty) return;

    print('📤 Préparation à l\'envoi du GIF : $gifUrl');
    final nowCestTime = DateTime.now().toUtc().add(Duration(hours: 2));
    final nowCestIsoFormatted =
        DateFormat("yyyy-MM-dd HH:mm:ss").format(nowCestTime);

    final cryptoData = await _chiffrerMessage(gifUrl);
    final encryptedMessage = cryptoData['encrypted_message'] ?? gifUrl;
    final key = cryptoData['key'] ?? 'test';

    // Affichage local temporaire
    setState(() {
      messages = List<Map<String, dynamic>>.from(messages)
        ..add({
          'sender': expediteur ?? '',
          'text': gifUrl,
          'encrypted': encryptedMessage,
          'sent_at': 'En cours...',
          'key': key,
          'type': 'gif'
        });
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/messages/send_message/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'expediteur': expediteur,
          'destinataire': destinataire,
          'message': encryptedMessage,
          'id_conversation': idConversation,
          'key': key,
          'type': 'gif',
          'timestamp': nowCestIsoFormatted, // --- INCLUDE THIS IN THE BODY ---
        }),
      );

      print("📡 GIF Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        print('✅ GIF envoyé avec succès.');
        // Refresh pour récupérer le vrai timestamp
        await Future.delayed(Duration(milliseconds: 500));
        await _fetchMessages();
      } else {
        print('❌ Erreur envoi GIF : ${response.body}');
        setState(() {
          messages.removeLast();
        });
      }
    } catch (e) {
      print('❌ Erreur réseau envoi GIF : $e');
      setState(() {
        messages.removeLast();
      });
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        final threshold = 100.0;

        if (force || (maxScroll - currentScroll) < threshold) {
          _scrollController.animateTo(
            maxScroll,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendFile(String fileUrl) async {
    if (expediteur == null || fileUrl.isEmpty) return;

    final nowUtcIso = DateTime.now().toIso8601String();
    final cryptoData = await _chiffrerMessage(fileUrl);
    final encryptedMessage = cryptoData['encrypted_message'] ?? fileUrl;
    final key = cryptoData['key'] ?? 'test';

    setState(() {
      messages = List<Map<String, dynamic>>.from(messages)
        ..add({
          'sender': expediteur ?? '',
          'text': fileUrl,
          'encrypted': encryptedMessage,
          'timestamp': nowUtcIso,
          'key': key,
          'type': 'file'
        });
    });
    _scrollToBottom();

    final body = jsonEncode({
      'expediteur': expediteur,
      'destinataire': destinataire,
      'message': encryptedMessage,
      // 'timestamp': nowUtcIso, // removed
      'id_conversation': idConversation,
      'key': key,
      'type': 'file'
    });

    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/messages/send_message/'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode != 200) {
        print('Erreur envoi fichier : ${response.body}');
      } else {
        print('✅ Fichier envoyé avec succès.');
      }
    } catch (e) {
      print('Erreur réseau envoi fichier : $e');
    }
  }

  ///

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
      body: Stack(
        children: [
          _isInitialLoading
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
                          return Container(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
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
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog(
                                                      title: Text(
                                                          "Supprimer le message ?"),
                                                      actions: [
                                                        TextButton(
                                                          child:
                                                              Text("Annuler"),
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                        ),
                                                        TextButton(
                                                          child:
                                                              Text("Supprimer"),
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
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
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: message['type'] == 'gif'
                                              ? Image.network(
                                                  message['text'] ?? '',
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                  return Text(
                                                      "Erreur de chargement du GIF");
                                                })
                                              : message['text']
                                                      .toString()
                                                      .startsWith('http')
                                                  ? GestureDetector(
                                                      onTap: () => launchUrl(
                                                          Uri.parse(
                                                              message['text'])),
                                                      child: Text(
                                                        '📎 Fichier joint',
                                                        style: TextStyle(
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                          color:
                                                              Colors.blueAccent,
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      message['owner'] != null
                                                          ? "Message de ${message['owner']}"
                                                          : (message['text'] ??
                                                              ''),
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
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Builder(
                                    builder: (context) {
                                      final rawDateStr = message['sent_at'] ??
                                          message['timestamp'];
                                      DateTime? parsedDate;
                                      try {
                                        parsedDate =
                                            DateTime.tryParse(rawDateStr ?? '');
                                      } catch (_) {}
                                      final display = parsedDate != null
                                          ? DateFormat("d MMMM yyyy à HH:mm",
                                                  "fr_FR")
                                              .format(parsedDate)
                                          : '';
                                      return Text(
                                        display,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600]),
                                      );
                                    },
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
                                        if (_controller.text
                                            .trim()
                                            .isNotEmpty) {
                                          sendMessage(_controller.text);
                                          _controller.clear();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 5),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
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
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, top: 2),
                            child: Text(
                              "🔒 Messages chiffrés de bout en bout",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          if (_showScrollToBottom)
            Positioned(
              bottom: 100,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.orange,
                child: Icon(Icons.arrow_downward),
                onPressed: () => _scrollToBottom(force: true),
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
