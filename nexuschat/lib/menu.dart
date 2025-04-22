import 'package:flutter/material.dart';
import 'package:nexuschat/profil.dart';
import 'settings.dart';
import 'listechat.dart';

class Menu extends StatefulWidget {
  const Menu({Key? key}) : super(key: key);

  @override
  _MenuState createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int _selectedIndex = 0;
  String? _userDisplayName;
  String? _profilePictureURL;
  bool showEmailWarning = true;

  static late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();

    _widgetOptions = <Widget>[
      Listechat(),
      Setting(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Bienvenue !",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_userDisplayName != null) ...[
                  Container(
                    constraints: const BoxConstraints(maxWidth: 125),
                    child: Text(
                      _userDisplayName!,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Profil()),
                    );
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.white38,
                    radius: 25,
                    backgroundImage: _profilePictureURL != null
                        ? NetworkImage(_profilePictureURL!)
                        : null,
                    child: _profilePictureURL == null
                        ? const Icon(
                            Icons.account_circle,
                            size: 40,
                            color: Colors.black,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.fromLTRB(15, 10, 10, 10),
        child: Column(
          children: [
            if (showEmailWarning)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.amber[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.black),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        " Les emails de vérification sont momentanément indisponibles. Veuillez nous en excuser !",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: _widgetOptions.elementAt(_selectedIndex),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange.shade400,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: "Chat",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Paramètres",
          ),
        ],
      ),
    );
  }
}
