import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:nexuschat/login.dart';
import 'package:nexuschat/menu.dart';
import 'package:url_launcher/url_launcher.dart';

class Setting extends StatefulWidget {
  const Setting({Key? key}) : super(key: key);

  @override
  _SettingState createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  late String _selectedTheme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentTheme = AdaptiveTheme.of(context).mode;
    if (currentTheme == AdaptiveThemeMode.light) {
      _selectedTheme = 'Clair';
    } else if (currentTheme == AdaptiveThemeMode.dark) {
      _selectedTheme = 'Sombre';
    } else {
      _selectedTheme = 'Système';
    }
  }

  Future<void> showLegalDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Mentions Légales'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "1. Informations collectées",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "NexusChat collecte des informations vous concernant lorsque vous utilisez nos services. "
                  "Ces informations peuvent inclure :",
                ),
                SizedBox(height: 8),
                Text("• Lors de la création d'un compte :"),
                Text(
                    "   - Votre adresse email : Utilisée pour la communication avec vous, la récupération de compte, la réinitialisation de mot de passe et les notifications importantes."),
                Text(
                    "   - Votre nom et prénom : Utilisés pour personnaliser votre expérience utilisateur."),
                SizedBox(height: 8),
                Text(
                    "• Lorsque vous soumettez des rapports via l'application NexusChat :"),
                Text(
                    "   - Informations techniques : Collectées automatiquement pour le dépannage et l'optimisation de l'application."),
                Text(
                    "   - Version de votre système d'exploitation : Pour identifier les problèmes spécifiques à certaines versions."),
                Text(
                    "   - Version de l'application : Pour assurer la compatibilité avec les versions antérieures."),
                Text(
                    "   - Recherches : Pour améliorer les fonctionnalités en fonction des besoins des utilisateurs."),
                SizedBox(height: 8),
                Text("• En naviguant sur notre site :"),
                Text(
                    "   - Informations de navigation : Telles que votre adresse IP, votre type de navigateur, et vos préférences."),
                Text(
                    "   - Cookies : Utilisés pour personnaliser votre expérience et nous aider à améliorer notre site."),
                SizedBox(height: 8),
                Text(
                  "2. Utilisation des données",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "NexusChat s'engage à ne jamais revendre vos données personnelles à des tiers à des fins publicitaires ou commerciales. "
                  "Les données collectées sont uniquement utilisées pour améliorer l'application et votre expérience utilisateur.",
                ),
                SizedBox(height: 8),
                Text("Utilisation des données statistiques anonymisées :"),
                Text(
                    "   - Analyser l'utilisation de l'application et de ses fonctionnalités."),
                Text(
                    "   - Identifier les tendances et les besoins des utilisateurs."),
                Text("   - Améliorer l'application et corriger les bugs."),
                SizedBox(height: 8),
                Text(
                  "3. Transferts de données hors Union européenne",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "NexusChat ne transfère aucune donnée personnelle vers des pays hors de l'Union européenne. Nos serveurs sont hébergés en Europe et les données des utilisateurs sont stockées conformément aux réglementations européennes en matière de protection des données, y compris le RGPD.",
                ),
                Text(
                  "En cas de nécessité absolue de transférer des données vers un pays hors de l'Union européenne, NexusChat s'engage à mettre en place les mesures de protection adéquates suivantes :",
                ),
                Text(
                    "   - Le transfert de vos données vers un pays tiers offrant un niveau de protection adéquat des données personnelles."),
                Text(
                    "   - Mise en place de clauses contractuelles types avec le destinataire des données, conformément aux modèles approuvés par la Commission européenne."),
                Text(
                    "   - Application de règles d'entreprise contraignantes garantissant un niveau de protection adéquat des données personnelles."),
                SizedBox(height: 8),
                Text(
                  "4. Droits des utilisateurs",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "En tant qu'utilisateur de NexusChat, vous disposez de plusieurs droits en matière de protection des données personnelles :",
                ),
                Text(
                    "   - Droit d'accès et de rectification : Vous pouvez accéder à vos données personnelles et les rectifier à tout moment en vous connectant à votre compte NexusChat."),
                Text(
                    "   - Droit à l'effacement : Vous pouvez demander l'effacement de vos données personnelles en accédant aux réglages de l'application. Votre demande sera traitée dans les meilleurs délais."),
                Text(
                    "   - Droit à la portabilité des données : Vous pouvez obtenir un listing de vos données personnelles en envoyant un email à notre service de support à l'adresse suivante : derick.maxime@derickexm.be"),
                SizedBox(height: 8),
                Text(
                  "5. Conservation des données",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "NexusChat conserve vos données personnelles pendant une période maximale de 2 ans après votre dernière connexion au service (Sauf si une demande suppression a été faite). Un mois avant la suppression de vos données, vous recevrez un email de notification vous informant de la date de suppression prévue.",
                ),
                Text(
                  "Si vous souhaitez conserver vos données après cette période, vous pouvez vous connecter à votre compte NexusChat ce qui annulera la suppression de votre compte.",
                ),
                SizedBox(height: 8),
                Text(
                  "6. Mesures de sécurité",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "NexusChat met en place des mesures de sécurité techniques et organisationnelles pour protéger vos données personnelles contre la perte, l'utilisation abusive, l'accès non autorisé, la divulgation, la modification ou la destruction.",
                ),
                Text(
                  "NexusChat utilise Mariadb :",
                ),
                Text("   - Crypter les données au repos et en transit."),
                Text("   - Contrôle d'accès basé sur les rôles."),
                Text("   - Surveillance et audit des journaux d'activité."),
                SizedBox(height: 8),
                Text(
                  "7. Application de la politique de confidentialité",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "La présente politique de confidentialité s'applique à toutes les versions de NexusChat. En cas de modification, nous vous informerons par email et/ou notification sur notre site web. La version la plus récente sera disponible sur notre site web.",
                ),
                SizedBox(height: 8),
                Text(
                  "8. Contact",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "Si vous avez des questions ou des demandes concernant vos données personnelles, vous pouvez nous contacter par email à l'adresse suivante : derick.maxime@derickexm.be",
                ),
                Text(
                  "Vous pouvez également utiliser le formulaire de contact sur notre site web. Nous répondrons à votre demande dans un délai d'un mois.",
                ),
                SizedBox(height: 8),
                Text(
                  "Dernière modification : Date de publication : 17 mars 2025",
                ),
                Text(
                  "Version : 1.0",
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

/*
  Future<void> showAboutDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('À propos'),
          content: Text(
            "MyChat est une application de messagerie développée par un élève de 6ème informatique. "
            "Elle permet aux utilisateurs de communiquer facilement et efficacement avec leurs amis et leur famille. "
            "L'objectif de MyChat est de fournir une plateforme simple et sécurisée pour les conversations quotidiennes. "
            "MyChat est en version bêta, des bugs peuvent survenir.",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
*/
  void _changeTheme(String theme) {
    setState(() {
      _selectedTheme = theme;
    });

    if (theme == 'Clair') {
      AdaptiveTheme.of(context).setLight();
    } else if (theme == 'Sombre') {
      AdaptiveTheme.of(context).setDark();
    } else {
      AdaptiveTheme.of(context).setSystem();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () async {
                Navigator.push(
                    context, MaterialPageRoute(builder: (context) => Login()));
              },
              child: const Text('Se déconnecter'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                showLegalDialog(context);
              },
              child: const Text('Mentions Légales'),
            ),
            SizedBox(height: 20),
            /*
            ElevatedButton(
              onPressed: () {
                showAboutDialog(context);
              },
              child: const Text('À propos'),
            ),*/
            SizedBox(height: 20),
            Text("Choisir thème"),
            DropdownButton<String>(
              value: _selectedTheme,
              items: <String>['Système', 'Clair', 'Sombre']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _changeTheme(newValue);
                }
              },
              hint: Text('Choisir le thème'),
            ),
            SizedBox(height: 20),
            Text(
              'Contact',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final url = 'mailto:derick.maxime@derickexm.be';
                    launch(url);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.email, color: Colors.blue),
                      SizedBox(width: 5),
                      Text(
                        'derick.maxime@derickexm.be',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              '© 2025 Derick Maxime',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
