import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:nexuschat/profil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Notif extends StatefulWidget {
  const Notif({
    Key? key,
  }) : super(key: key);

  @override
  _NotifState createState() => _NotifState();
}

class _NotifState extends State<Notif> {
  String? username;
  String? userId;
  Map<String, dynamic>? _lastNotification;
  bool isUsernameReady = false;
  late SharedPreferences prefs;
  int? selectedNotificationId;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';

    if (email.isNotEmpty) {
      await _getUsername(email);
    } else {
      print("❌ Aucun email trouvé dans les préférences.");
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final url =
        Uri.parse('https://nexuschat.derickexm.be/users/delete_notifications/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'id': notificationId},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notification supprimée')),
          );
        }
      } else {
        print('Erreur lors de la suppression: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de suppression de la notification')),
        );
      }
    } catch (e) {
      print('Erreur lors de la suppression: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression')),
      );
    }
  }

  Future<bool> deleteAllNotifications() async {
    final url = Uri.parse(
        'https://nexuschat.derickexm.be/users/delete_all_notifications/');

    try {
      var formData = FormData.fromMap({
        'destinataire': username,
      });

      final response = await Dio().post(
        url.toString(),
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print('Successfully deleted ${data['count']} notifications');
        return true;
      } else {
        print('Failed to delete notifications: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error when deleting all notifications: $e');
      return false;
    }
  }

  Future<void> _getUsername(String email) async {
    final url = Uri.parse(
        'https://nexuschat.derickexm.be/users/get_username/?email=$email');
    try {
      final response =
          await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            username = data['username'];
            prefs.setString('username', username!);
            isUsernameReady = true;
          });
        }
      } else {
        print("❌ Impossible de récupérer le nom d'utilisateur");
      }
    } catch (e) {
      print("❌ Erreur de connexion à l'API : $e");
    }
  }

  void _initializeNotifications() {}

  Future<List<Map<String, dynamic>>> fetchNotifications(
      String? username) async {
    if (username == null || username.isEmpty) {
      return [];
    }

    final response = await http.get(Uri.parse(
        'https://nexuschat.derickexm.be/users/get_notifications?username=$username'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List notifications = decoded['notifications'];
      return notifications.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Erreur de chargement des notifications');
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Confirmation'),
              content: Text(
                  'Voulez-vous vraiment supprimer toutes les notifications ?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: Text('Annuler'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Text('Supprimer'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep),
            tooltip: 'Supprimer toutes les notifications',
            onPressed: () async {
              bool confirm = await _showConfirmationDialog(context);
              if (confirm) {
                bool success = await deleteAllNotifications();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Toutes les notifications ont été supprimées')),
                  );
                  if (mounted) {
                    setState(() {});
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Échec de la suppression des notifications')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: isUsernameReady
          ? FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchNotifications(username),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur: ${snapshot.error}'),
                  );
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return Center(
                    child: Text('Aucune notification pour le moment'),
                  );
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final username = notification['owner'] ?? 'inconnu';

                    final message = notification['contenu'] ?? 'Pas de contenu';

                    final timestamp = notification.containsKey('date_creation')
                        ? DateTime.parse(notification['date_creation'])
                        : DateTime.now();

                    var formattedTimestamp =
                        DateFormat('dd MMM yyyy, HH:mm').format(timestamp);

                    return Container(
                      decoration: BoxDecoration(),
                      margin:
                          EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      child: ListTile(
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () async {
                            await _deleteNotification(
                                notification['id'].toString());
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            Icons.notifications,
                            size: 30,
                            color: Colors.black,
                          ),
                          backgroundColor: Colors.white38,
                        ),
                        title: Text(
                          username ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              formattedTimestamp,
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            selectedNotificationId = notification['id'];
                            print(
                                "Notification sélectionnée : $selectedNotificationId");
                          });
                        },
                      ),
                    );
                  },
                );
              },
            )
          : Center(child: CircularProgressIndicator()),
    );
  }

  void _showNotification(
      BuildContext context, Map<String, dynamic>? notificationData) async {
    var source =
        notificationData != null && notificationData.containsKey('type')
            ? notificationData['type']
            : "divers";
    var message =
        notificationData != null && notificationData.containsKey('contenu')
            ? notificationData['contenu']
            : "Pas de message";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🔔 $source : $message"),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
