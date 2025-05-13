import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:nexuschat/login.dart';

class Inscription extends StatelessWidget {
  Inscription({super.key});

  final TextEditingController email = TextEditingController();
  final TextEditingController passwd = TextEditingController();
  final TextEditingController username = TextEditingController();

  Future<void> sendVerificationEmail(BuildContext context, String email) async {
    final url = Uri.parse(
        'https://nexuschat.derickexm.be/email/send_email?email=$email');
    try {
      final response = await http.post(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        _showSnackBar(context, "Email de vérification envoyé avec succès!");
      } else {
        _showSnackBar(context,
            "Impossible d'envoyer l'email de vérification. (${response.statusCode})");
        print("Réponse serveur : ${response.body}");
      }
    } catch (e) {
      _showSnackBar(context, "Erreur de connexion à l'API.");
      print("Erreur d'envoi email : $e");
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _API_inscription(BuildContext context) async {
    const String apiUrl = "https://nexuschat.derickexm.be/users/create_user";

    if (username.text.isEmpty || email.text.isEmpty || passwd.text.isEmpty) {
      _showSnackBar(context, "Veuillez remplir tous les champs.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username.text,
          "email": email.text,
          "password": passwd.text,
        }),
      );

      if (response.statusCode == 200) {
        print("Inscription réussie !");
        _showSnackBar(context, "Inscription réussie !");
        sendVerificationEmail(context, email.text);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Login()),
        );
      } else {
        print("Erreur : ${response.body}");
        _showSnackBar(context, "Erreur lors de l'inscription");
      }
    } catch (e) {
      print("Erreur réseau : $e");
      _showSnackBar(context, "Problème de connexion au serveur");
    }
  }

  @override
  Widget build(BuildContext context) {
    FocusNode emailFocusNode = FocusNode();
    FocusNode passwdFocusNode = FocusNode();
    FocusNode usernameFocusNode = FocusNode();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("S'inscrire sur NexusChat",
                      style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 400,
                    child: TextField(
                      controller: username,
                      focusNode: usernameFocusNode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Nom d'utilisateur",
                      ),
                      onTap: () => usernameFocusNode.requestFocus(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 400,
                    child: TextField(
                      controller: email,
                      focusNode: emailFocusNode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Adresse email',
                      ),
                      onTap: () => emailFocusNode.requestFocus(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 400,
                    child: TextField(
                      controller: passwd,
                      focusNode: passwdFocusNode,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Mot de passe',
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => _API_inscription(context),
                    child: const Text("S'inscrire"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => Login()));
                    },
                    child: const Text("Déjà inscrit ?"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
