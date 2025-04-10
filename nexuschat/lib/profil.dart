import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences prefs;

class Profil extends StatefulWidget {
  const Profil({super.key});

  @override
  _ProfilState createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  final TextEditingController _usernameController = TextEditingController();
  String? _profilePictureURL;
  bool _isLoadingImage = false;
  bool _isEmailVerified = false;
  String? _userEmail;
  String? _username;

  @override
  void initState() {
    super.initState();
    _initPrefs().then((_) {
      _updateEmailVerification();
      _getUsername();
    });
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('user_email') ?? 'email@example.com';
      _profilePictureURL = prefs.getString('profile_picture');
    });
  }

  Future<void> _changeUsername() async {
    String newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) {
      _showSnackBar("Le nom d'utilisateur ne peut pas être vide.");
      return;
    }

    final oldUsername = prefs.getString('username');
    if (oldUsername == null) {
      _showSnackBar(
          "Aucun nom d'utilisateur trouvé. Veuillez vous reconnecter.");
      return;
    }

    final url =
        Uri.parse('https://nexuschat.derickexm.be/users/change_username');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": oldUsername,
          "newusername": newUsername,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _username = newUsername;
        });
        await prefs.setString('username', newUsername);
        _showSnackBar("Nom d'utilisateur mis à jour !");
      } else {
        _showSnackBar("Impossible de changer le nom d'utilisateur.");
      }
    } catch (e) {
      _showSnackBar("Erreur de connexion à l'API.");
    }
  }

  Future<void> _updateEmailVerification() async {
    if (_userEmail == null) return;

    final url = Uri.parse(
        'https://nexuschat.derickexm.be/users/check_email/?email=$_userEmail');
    try {
      final response =
          await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isEmailVerified =
              (data["verified"] == 1 || data["verified"] == true);
        });
      } else {
        _showSnackBar("Erreur lors de la vérification de l'email.");
      }
    } catch (e) {
      _showSnackBar("Erreur de connexion à l'API.");
    }
  }

  Future<void> _getUsername() async {
    final url = Uri.parse(
        'https://nexuschat.derickexm.be/users/get_username/?email=$_userEmail');
    try {
      final response =
          await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _username = data['username'];
        });
      } else {
        _showSnackBar("Impossible de récupérer le nom d'utilisateur.");
      }
    } catch (e) {
      _showSnackBar("Erreur de connexion à l'API.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> sendVerificationEmail(BuildContext context, String email) async {
    final url = Uri.parse(
        'https://nexuschat.derickexm.be/email/send_email?email=$_userEmail');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": email,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Email de vérification envoyé avec succès!");
      } else {
        _showSnackBar("Impossible d'envoyer l'email de vérification.");
      }
    } catch (e) {
      _showSnackBar("Erreur de connexion à l'API.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.grey.shade200,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _isLoadingImage
                    ? const CircularProgressIndicator()
                    : CircleAvatar(
                        radius: 100,
                        backgroundColor: Colors.black,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 120,
                          backgroundImage: _profilePictureURL != null
                              ? NetworkImage(_profilePictureURL!)
                              : null,
                          child: _profilePictureURL == null
                              ? const Icon(
                                  Icons.account_circle,
                                  color: Colors.black,
                                  size: 180,
                                )
                              : null,
                        ),
                      ),
                const SizedBox(height: 15),
                const Text("Nom d'utilisateur",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 15),
                Text(
                  _username ??
                      'Erreur lors du chargement du nom d\'utilisateur',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 15),
                const Text("Email",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: _isEmailVerified
                            ? 'Email vérifié'
                            : 'Email non vérifié',
                        child: Icon(
                          _isEmailVerified ? Icons.check : Icons.error,
                          color: _isEmailVerified ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _userEmail ?? "Erreur lors du chargement de l'email",
                        style: const TextStyle(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    if (_userEmail != null) {
                      sendVerificationEmail(context, _userEmail!);
                    } else {
                      _showSnackBar("Aucun email trouvé pour l'utilisateur.");
                    }
                  },
                  child: const Text("Envoyer l'email de vérification"),
                ),
                const SizedBox(height: 20),
                const Text("Statut",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 3),
                Text(
                  "Dernière activité : Non spécifié",
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Changer nom d\'utilisateur'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nouveau nom d\'utilisateur',
                                ),
                              ),
                            ],
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () async {
                                String newUsername =
                                    _usernameController.text.trim();
                                if (newUsername.isNotEmpty) {
                                  _changeUsername();
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Confirmer'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Changer nom d\'utilisateur'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
