import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:nexuschat/chat.dart';
import 'package:nexuschat/profil.dart';

class Contacts extends StatefulWidget {
  @override
  _ContactsState createState() => _ContactsState();
}

class _ContactsState extends State<Contacts>
    with SingleTickerProviderStateMixin {
  List<dynamic> _contacts = [];
  List<dynamic> _filteredContacts = [];
  List<dynamic> _demandes = [];
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  TextEditingController _searchController = TextEditingController();
  TextEditingController _contactSearchController = TextEditingController();

  String? _userEmail;
  String? currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initUser();
    _contactSearchController.addListener(_filterContacts);
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userEmail = prefs.getString('user_email') ?? '';
    try {
      final response = await http.get(
        Uri.parse(
            'https://nexuschat.derickexm.be/users/get_username/?email=$_userEmail'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        currentUser = data['username'];

        await _loadContacts();
        await _loadDemandes();
        await _loadAllUsers();
        _searchController.addListener(_filterUsers);

        setState(() {});
      } else {
        print("Erreur : utilisateur introuvable");
      }
    } catch (e) {
      print("Erreur récupération username : $e");
    }
  }

  Future<void> _loadContacts() async {
    if (currentUser == null) return;
    try {
      final response = await http.get(
        Uri.parse(
            'https://nexuschat.derickexm.be/contacts/mes_contacts?owner=$currentUser'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _contacts = data;
          _filteredContacts = data;
        });
      } else {
        print("Erreur chargement contacts: ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  Future<void> _loadDemandes() async {
    if (currentUser == null) return;
    try {
      final response = await http.get(
        Uri.parse(
            'https://nexuschat.derickexm.be/contacts/mes_demandes?owner=$currentUser'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _demandes = data);
      } else {
        print("Erreur chargement demandes: ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('https://nexuschat.derickexm.be/users/get_users?username='),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = data['users'];
        users.shuffle();
        setState(() {
          _users = users;
          _filteredUsers = users.length > 3 ? users.take(3).toList() : users;
        });
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = [];
      } else {
        _filteredUsers = _users
            .where((user) => user['username'].toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _filterContacts() {
    final query = _contactSearchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts
          .where((contact) => contact['contacts'].toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _sendnotification(
      String destinataire, String messageText) async {
    if (destinataire.isEmpty || currentUser == null) return;

    final url =
        Uri.parse("https://nexuschat.derickexm.be/users/send_notifications");
    final body = jsonEncode({
      'destinataire': destinataire,
      'type': 'text',
      'contenu': messageText,
      'owner': currentUser
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

  Future<void> _envoyerDemandeContact(String destinataire) async {
    if (destinataire == currentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vous ne pouvez pas vous ajouter vous-même")),
      );
      return;
    }

    final dejaContact =
        _contacts.any((contact) => contact['contacts'] == destinataire);
    final demandeExistante =
        _demandes.any((demande) => demande['from'] == destinataire);

    if (dejaContact) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$destinataire est déjà dans vos contacts")),
      );
      return;
    }

    if (demandeExistante) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Une demande est déjà en attente pour $destinataire")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://nexuschat.derickexm.be/contacts/demande_contact"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"owner": destinataire, "sender": currentUser}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Demande envoyée à $destinataire")),
        );
        await _sendnotification(
            destinataire, "$currentUser vous a envoyé une demande de contact.");
        await _loadDemandes();
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  Future<void> _accepterDemande(String sender) async {
    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/contacts/accepter_demande'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"owner": currentUser, "sender": sender}),
      );
      if (response.statusCode == 200) {
        await _loadContacts();
        await _loadDemandes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Demande de $sender acceptée")),
        );
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  Future<void> _refuserDemande(String sender) async {
    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/contacts/refuser_demande'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"owner": currentUser, "sender": sender}),
      );
      if (response.statusCode == 200) {
        await _loadDemandes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Demande de $sender refusée")),
        );
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  Future<void> _supprimerContact(String destinataire) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmer la suppression"),
        content: Text(
            "Voulez-vous vraiment supprimer $destinataire de vos contacts ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse('https://nexuschat.derickexm.be/contacts/supprimer_contact'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"owner": currentUser, "contact": destinataire}),
      );
      if (response.statusCode == 200) {
        await _loadContacts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Contact $destinataire supprimé")),
        );
        print("Status: ${response.statusCode}");
        print("Body: ${response.body}");
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  Future<String> _getEtatRelation(String target) async {
    final response = await http.get(
      Uri.parse(
          "https://nexuschat.derickexm.be/contacts/etat_relation?owner=$currentUser&target=$target"),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['etat'];
    } else {
      return "erreur";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes contacts"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Contacts"),
            Tab(text: "Demandes"),
            Tab(text: "Rechercher"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _contacts.isEmpty
              ? Center(child: Text("Aucun contact"))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _contactSearchController,
                        decoration: InputDecoration(
                          labelText: "Rechercher dans mes contacts...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final user = _filteredContacts[index]['contacts'];
                          return Card(
                            child: ListTile(
                              title: Text(user),
                              leading: Icon(Icons.person),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                            usernameExpediteur: user),
                                      ),
                                    ),
                                    child: Text("Chat"),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete),
                                    onPressed: () => _supprimerContact(user),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          _demandes.isEmpty
              ? Center(child: Text("Aucune demande"))
              : ListView.builder(
                  itemCount: _demandes.length,
                  itemBuilder: (context, index) {
                    final demande = _demandes[index]['from'];
                    return Card(
                      child: ListTile(
                        title: Text("Demande de $demande"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () => _accepterDemande(demande),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () => _refuserDemande(demande),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: "Rechercher un utilisateur...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: _filteredUsers.isEmpty
                    ? Center(child: Text("Aucun utilisateur trouvé"))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_searchController.text.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                "Personnes que tu pourrais connaître",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index]['username'];
                                if (user == currentUser) return SizedBox();

                                return FutureBuilder<String>(
                                  future: _getEtatRelation(user),
                                  builder: (context, snapshot) {
                                    String? etat = snapshot.data;

                                    if (!snapshot.hasData) {
                                      return ListTile(
                                        title: Text(user),
                                        subtitle: Text("Chargement..."),
                                      );
                                    }

                                    String label = "";
                                    VoidCallback? action;

                                    if (etat == "aucune_relation") {
                                      label = "Envoyer demande";
                                      action =
                                          () => _envoyerDemandeContact(user);
                                    } else if (etat == "pending_envoyee" ||
                                        etat == "pending_recue") {
                                      label = "Demande en attente";
                                      action = null;
                                    } else if (etat == "ami") {
                                      return SizedBox(); // cacher les amis
                                    } else {
                                      label = "Erreur";
                                      action = null;
                                    }

                                    return Card(
                                      child: ListTile(
                                        title: Text(user),
                                        leading: Icon(Icons.person_outline),
                                        trailing: ElevatedButton(
                                          onPressed: action,
                                          child: Text(label),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
