import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebaseexample/models/message.dart';
import 'package:firebaseexample/widges/message_area.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

final firebaseAuthInstance = FirebaseAuth.instance;
final firebaseStorageInstance = FirebaseStorage.instance;
final firebaseFireStore = FirebaseFirestore.instance;
final fcm = FirebaseMessaging.instance;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  File? _pickedFile;
  String _imageUrl = '';
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    _requestNotificationPermission();
    _getUserImage();
    super.initState();
  }

  void _requestNotificationPermission() async {
    NotificationSettings notificationSettings = await fcm.requestPermission();

    if (notificationSettings.authorizationStatus ==
        AuthorizationStatus.denied) {
      // bildirimlere izin verilmedi
    } else {
      String? token = await fcm.getToken();

      if (token == null) {
        // kullanıcıya bir uyarı göster..
      }
      _updateTokenInDb(token!);

      await fcm.subscribeToTopic("chat");

      fcm.onTokenRefresh.listen((token) {
        _updateTokenInDb(token);
      }).onError((error) {});
    }
  }

  void _updateTokenInDb(String token) async {
    await firebaseFireStore
        .collection("users")
        .doc(firebaseAuthInstance.currentUser!.uid)
        .update({'fcm': token});
  }

  void _getUserImage() async {
    final user = firebaseAuthInstance.currentUser;
    final document = firebaseFireStore.collection("users").doc(user!.uid);
    final documentSnapshot =
        await document.get(); // document.get => dökümanın okunmasını sağlar.
    // documentSnapshot => dökümanın tamamı
    print("documentSnapshot");
    setState(() {
      _imageUrl = documentSnapshot.get(
          "imageUrl"); // documentSnapshot.get => dökümanın içindeki field'ı okur
    });
  }

  void _pickImage() async {
    final image = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 150);

    if (image != null) {
      setState(() {
        _pickedFile = File(image.path);
      });
    }
  }

  void _upload() async {
    final user = firebaseAuthInstance.currentUser;
    final storageRef =
        firebaseStorageInstance.ref().child("images").child("${user!.uid}.jpg");

    await storageRef.putFile(_pickedFile!);

    final url = await storageRef.getDownloadURL();

    final document = firebaseFireStore.collection("users").doc(user!.uid);

    await document.update({
      'imageUrl': url
    }); // document.update => verilen değeri ilgili dökümanda günceller!
  }

  Future<void> _sendMessage() async {
    if(_messageController.text != ""){
      final user = firebaseAuthInstance.currentUser;
    await firebaseFireStore.collection('messages').add({
      'userID': user!.uid,
      'message': _messageController.text,
      'date': DateTime.now()
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firebase Application"),
        actions: [
          IconButton(
              onPressed: () {
                firebaseAuthInstance.signOut();
              },
              icon: const Icon(Icons.logout))
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Column(children: [
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_imageUrl.isNotEmpty && _pickedFile == null)
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey,
                      foregroundImage: NetworkImage(_imageUrl),
                    ),
                  if (_pickedFile != null)
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey,
                      foregroundImage: FileImage(_pickedFile!),
                    ),
                  TextButton(
                      onPressed: () {
                        _pickImage();
                      },
                      child: const Text("Resim Seç")),
                  if (_pickedFile != null)
                    ElevatedButton(
                        onPressed: () {
                          _upload();
                        },
                        child: const Text("Yükle"))
                ],
              ),
              SizedBox(
                height: 540,
                child: StreamBuilder(
                  stream: firebaseFireStore
                      .collection('messages')
                      .orderBy('date')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final messages = snapshot.data!.docs.reversed;
                    List<Widget> messageWidgets = [];
                    List<Message> messageList = messages
                        .map((e) => Message(
                            e['userID'], e['message'], e['date'].toString()))
                        .toList();

                    for (var message in messageList) {
                      messageWidgets.add(MessageArea(
                          message: message,
                          user: firebaseAuthInstance.currentUser!));
                    }

                    return ListView(
                      reverse: true,
                      children: messageWidgets,
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(35)),
                            hintText: 'Mesaj',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          _sendMessage();
                          _messageController.clear();
                        },
                      ),
                    ],
                  ),
                ),
              )
            ]),
          ),
        ),
      ),
    );
  }
}
// Authentication
// Profil Düzenleme (Storage)
// Takvim? Pair 8