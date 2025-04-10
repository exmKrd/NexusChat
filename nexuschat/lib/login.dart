import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nexuschat/inscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menu.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    TextEditingController email = TextEditingController();
    TextEditingController passwd = TextEditingController();

    FocusNode emailFocusNode = FocusNode();
    FocusNode passwdFocusNode = FocusNode();

    void _showErrorDialog(BuildContext context, String message) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Erreur de connexion'),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                child: const Text('Fermer'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    Future<void> checkCredentials(String email, String password) async {
      final url =
          Uri.parse('https://nexuschat.derickexm.be/users/check_credentials');

      final body = jsonEncode({
        'email': email,
        'password': password,
      });

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: body,
        );

        if (response.statusCode == 200) {
          print("Connexion réussie");

          // Stocker l'email de l'utilisateur
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', email);

          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => Menu()));
        } else {
          _showErrorDialog(
              context, "Nom d'utilisateur ou mot de passe incorrect");
        }
      } catch (e) {
        _showErrorDialog(context, "Impossible de se connecter à l'API");
      }
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width:
                400, // Définition d'une largeur fixe pour un meilleur affichage
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min, // Adapter la taille du container au contenu
              mainAxisAlignment: MainAxisAlignment
                  .center, // Centrer les éléments verticalement
              crossAxisAlignment: CrossAxisAlignment
                  .center, // Centrer les éléments horizontalement
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 250,
                  height: 250,
                ),
                const SizedBox(height: 30),
                const Text(
                  'Bienvenue sur NexusChat',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: TextField(
                    controller: email,
                    focusNode: emailFocusNode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Adresse email',
                    ),
                    onTap: () {
                      emailFocusNode.requestFocus();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      print("Email saisi : ${email.text}");
                      print("Mot de passe : ${passwd.text}");
                      checkCredentials(email.text, passwd.text);
                    },
                    child: const Text("Se connecter"),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => Inscription()));
                    },
                    child: const Text("S'inscrire"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
