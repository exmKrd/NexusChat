// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword(BuildContext context, String email) async {
    final url = Uri.parse(
        'https://nexuschat.derickexm.be/email/change_password?email=$email');
    try {
      final response = await http.post(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        _showErrorDialog(context, "Email de vérification envoyé avec succès!");
      } else {
        _showErrorDialog(context,
            "Impossible d'envoyer l'email de vérification. (${response.statusCode})");
        print("Réponse serveur : ${response.body}");
      }
    } catch (e) {
      _showErrorDialog(context, "Erreur de connexion à l'API.");
      print("Erreur d'envoi email : $e");
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(''),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('rénitialisation de mot de passe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Entrer votre email';
                  }
                  if (!value.contains('@')) {
                    return 'Erreur : entrer un email valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _resetPassword(context, _emailController.text);
                  }
                },
                child: const Text('Rénitialiser votre mot de passe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
