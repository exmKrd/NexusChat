import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nexuschat/contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexuschat/chat.dart';
import 'package:intl/intl.dart';

class Listechat extends StatefulWidget {
  const Listechat({Key? key}) : super(key: key);

  @override
  Listechatstate createState() => Listechatstate();
}

class Listechatstate extends State<Listechat> {
  Future<List<Map<String, dynamic>>>? futureConversations;
  String? expediteur;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadExpediteur();
  }

  Future<void> _loadExpediteur() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? expediteurEmail = prefs.getString('user_email');

      if (expediteurEmail == null) {
        setState(() {
          isLoading = false;
          errorMessage = "Aucun utilisateur connecté. Veuillez vous connecter.";
        });
        return;
      }

      final uri =
          Uri.parse('https://nexuschat.derickexm.be/users/get_username/')
              .replace(queryParameters: {'email': expediteurEmail});

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is Map<String, dynamic> &&
            jsonResponse.containsKey('username')) {
          setState(() {
            expediteur = jsonResponse['username'];
            futureConversations = fetchConversations();
          });
        } else {
          setState(() {
            isLoading = false;
            errorMessage = "Format de réponse invalide.";
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Erreur de connexion: $e';
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    if (expediteur == null) {
      setState(() {
        isLoading = false;
        errorMessage = "Nom d'utilisateur non disponible";
      });
      return [];
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url =
        Uri.parse("https://nexuschat.derickexm.be/conversation/get_conv/")
            .replace(queryParameters: {'user1': expediteur!});

    try {
      final response = await http.get(url);

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (data.containsKey("conversations")) {
            return List<Map<String, dynamic>>.from(data["conversations"]);
          } else if (data.containsKey("exists") && data["exists"] == false) {
            return [];
          }
        }
        setState(() {
          errorMessage = "Format de réponse inattendu";
        });
        return [];
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Impossible de récupérer les conversations: $e";
      });
      return [];
    }

    // ✅ Ce return évite l'erreur "body might complete normally"
    return [];
  }

  Future<void> _refreshConversations() async {
    setState(() {
      futureConversations = fetchConversations();
    });
  }

  String formatTimestamp(String timestamp) {
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  String truncateMessage(String message, int maxLength) {
    if (message.length <= maxLength) return message;
    return "${message.substring(0, maxLength)}...";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Mes Conversations"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshConversations,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _refreshConversations,
                        child: const Text("Réessayer"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshConversations,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: futureConversations,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Erreur: ${snapshot.error}"),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _refreshConversations,
                                child: const Text("Réessayer"),
                              ),
                            ],
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline,
                                  size: 80, color: Colors.grey),
                              const SizedBox(height: 20),
                              const Text(
                                "Aucune conversation pour l’instant",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Commencez une discussion avec vos contacts.",
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Contacts(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_comment),
                                label: const Text("Démarrer une conversation"),
                              ),
                            ],
                          ),
                        );
                      }

                      final conversations = snapshot.data!;

                      return ListView.builder(
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          final destinataire =
                              conv["user1_username"] == expediteur
                                  ? conv["user2_username"]
                                  : conv["user1_username"];

                          final rawId = conv["id"]?.toString();
                          final uniqueTag = rawId != null
                              ? "conversation_${expediteur}_$rawId"
                              : "conversation_${expediteur}_${destinataire}_$index";

                          return Hero(
                            tag: uniqueTag,
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  child: Text(
                                    destinataire.isNotEmpty
                                        ? destinataire[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  destinataire,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                //
                                // subtitle: Column(
                                //   crossAxisAlignment: CrossAxisAlignment.start,
                                //   children: [
                                //     Text(truncatedMessage),
                                //     Text(
                                //       formattedDate,
                                //       style: TextStyle(
                                //         fontSize: 12,
                                //         color: Colors.grey[600],
                                //       ),
                                //     ),
                                //   ],
                                // ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        usernameExpediteur: destinataire,
                                      ),
                                    ),
                                  ).then((_) {
                                    _refreshConversations();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Contacts()),
          ).then((_) {
            _refreshConversations();
          });
        },
        child: const Icon(Icons.message),
        tooltip: "Nouvelle conversation",
      ),
    );
  }
}
