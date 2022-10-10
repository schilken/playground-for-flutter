import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:appwrite/models.dart' as Models;

const String _projectId = 'playgroundForFlutter';
const String _backendUrl = "https://192.168.2.23";
const String _email = 'user@appwrite.io';
const String _password = 'password';

const _databaseId = 'db1';
const _collectionId = 'c1';

const _bucketId = 'testbucket';
final _functionId = 'func01';

void main() {
  // required if you are initializing your client in main() like we do here
  WidgetsFlutterBinding.ensureInitialized();
  Client _client = Client();
  Account _account = Account(_client);
  Storage _storage = Storage(_client);
  Databases _databases = Databases(_client);
  Functions _functions = Functions(_client);

  _client
          .setEndpoint(
              '$_backendUrl/v1') // Make sure your endpoint is accessible from your emulator, use IP if needed
          .setProject(_projectId) // Your project ID
          .setSelfSigned() // Do not use this in production
      ;

  runApp(MaterialApp(
    home: Playground(
      client: _client,
      account: _account,
      storage: _storage,
      database: _databases,
      functions: _functions,
    ),
  ));
}

class Playground extends StatefulWidget {
  Playground({
    required this.client,
    required this.account,
    required this.storage,
    required this.database,
    required this.functions,
  });
  final Client client;
  final Account account;
  final Storage storage;
  final Databases database;
  final Functions functions;

  @override
  PlaygroundState createState() => PlaygroundState();
}

class PlaygroundState extends State<Playground> {
  String _username = "Loading...";
  Models.Account? _user;
  Models.File? _uploadedFile;
  Models.Jwt? _jwt;
  String? _realtimeEvent;
  RealtimeSubscription? _subscription;

  @override
  void initState() {
    _getAccount();
    super.initState();
  }

  Future<void> _getAccount() async {
    try {
      _user = await widget.account.get();
      setState(() {
        if (_user!.email.isEmpty) {
          _username = "Anonymous Login";
        } else {
          _username = _user!.name;
        }
      });
    } on AppwriteException catch (error) {
      print(error.message);
      setState(() {
        _username = 'No Session';
      });
    }
  }

  Future<void> _uploadFile() async {
    try {
      final response = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (response == null) return;
      final pickedFile = response.files.single;
      late InputFile inFile;
      if (kIsWeb) {
        inFile = InputFile(
          filename: pickedFile.name,
          bytes: pickedFile.bytes,
        );
      } else {
        inFile = InputFile(
          path: pickedFile.path,
          filename: pickedFile.name,
          bytes: pickedFile.bytes,
        );
      }
      final file = await widget.storage.createFile(
        bucketId: _bucketId,
        fileId: ID.unique(),
        file: inFile,
        permissions: [
          Permission.read(_user != null ? Role.user(_user!.$id) : Role.any()),
          Permission.write(Role.users())
        ],
      );
      print(file);
      setState(() {
        _uploadedFile = file;
      });
    } on AppwriteException catch (e) {
      print(e.message);
    } catch (e) {
      print(e);
    }
  }

  Future<void> _callRemoteFunction() async {
    try {
      final execution = await widget.functions.createExecution(
          functionId: _functionId, data: "arg1:string-argument");
      print('execution.status: ${execution.status}');
      print('execution.response: ${execution.response}');
    } on AppwriteException catch (e) {
      print(e.message);
    }
  }

  void _subscribe() {
    final realtime = Realtime(widget.client);
    _subscription = realtime.subscribe(['files', 'documents']);
    setState(() {});
    _subscription!.stream.listen((data) {
      print(data);
      setState(() {
        _realtimeEvent = jsonEncode(data.toMap());
      });
    });
  }

  void _unsubscribe() {
    _subscription?.close();
    setState(() {
      _subscription = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Appwrite + Flutter = ❤️"),
          backgroundColor: Colors.pinkAccent[200]),
      body: Container(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Padding(padding: EdgeInsets.all(20.0)),
              ElevatedButton(
                child: Text(
                  "Anonymous Login",
                  style: TextStyle(color: Colors.black, fontSize: 20.0),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.all(16),
                  minimumSize: Size(280, 50),
                ),
                onPressed: () async {
                  try {
                    await widget.account.createAnonymousSession();
                    _getAccount();
                  } on AppwriteException catch (e) {
                    print(e.message);
                  }
                },
              ),
              const SizedBox(height: 10.0),
              ElevatedButton(
                  child: Text(
                    "Login with Email",
                    style: TextStyle(color: Colors.black, fontSize: 20.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: const EdgeInsets.all(16),
                    minimumSize: Size(280, 50),
                  ),
                  onPressed: () async {
                    try {
                      await widget.account.createEmailSession(
                        email: _email,
                        password: _password,
                      );
                      _getAccount();
                      print(_user);
                    } on AppwriteException catch (e) {
                      print(e.message);
                    }
                  }),
              Padding(
                padding: const EdgeInsets.all(20.0),
              ),
              ElevatedButton(
                child: Text(
                  _subscription != null ? "Unsubscribe" : "Subscribe",
                  style: TextStyle(color: Colors.white, fontSize: 20.0),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(280, 50),
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _subscription != null ? _unsubscribe : _subscribe,
              ),
              if (_realtimeEvent != null) ...[
                const SizedBox(height: 10.0),
                Text(_realtimeEvent!),
              ],
              const SizedBox(height: 30.0),
              ElevatedButton(
                  child: Text(
                    "Create Doc",
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(280, 50),
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: () async {
                    try {
                      final document = await widget.database.createDocument(
                        databaseId: _databaseId,
                        collectionId: _collectionId,
                        documentId: ID.unique(),
                        data: {'message': 'a message', 'justANumber': 42},
                        permissions: [
                          Permission.read(Role.any()),
                          Permission.write(Role.user(_user?.$id ?? 'none')),
                        ],
                      );
                      print(document.toMap());
                    } on AppwriteException catch (e) {
                      print(e.message);
                    }
                  }),
              const SizedBox(height: 10.0),
              ElevatedButton(
                  child: Text(
                    "Upload file",
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.all(16),
                    minimumSize: Size(280, 50),
                  ),
                  onPressed: () {
                    _uploadFile();
                  }),
              const SizedBox(height: 10.0),
              ElevatedButton(
                  child: Text(
                    "Call remote function",
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.all(16),
                    minimumSize: Size(280, 50),
                  ),
                  onPressed: () {
                    _callRemoteFunction();
                  }),
              Padding(padding: EdgeInsets.all(20.0)),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    minimumSize: Size(280, 50),
                  ),
                  onPressed: () async {
                    try {
                      _jwt = await widget.account.createJWT();
                      setState(() {});
                    } on AppwriteException catch (e) {
                      print(e.message);
                    }
                  },
                  child: Text("Generate JWT",
                      style: TextStyle(color: Colors.white, fontSize: 20.0))),
              const SizedBox(height: 20.0),
              if (_jwt != null) ...[
                SelectableText(
                  _jwt!.jwt,
                  style: TextStyle(fontSize: 18.0),
                ),
                const SizedBox(height: 20.0),
              ],
              ElevatedButton(
                  child: Text(
                    "Login with Facebook",
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.all(16),
                    minimumSize: Size(280, 50),
                  ),
                  onPressed: () async {
                    try {
                      await widget.account.createOAuth2Session(
                        provider: 'discord',
                        success: 'http://localhost:43663/auth.html',
                      );
                      _getAccount();
                    } on AppwriteException catch (e) {
                      print(e.message);
                    }
                  }),
              Padding(padding: EdgeInsets.all(10.0)),
              ElevatedButton(
                  child: Text(
                    "Login with GitHub",
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.all(16),
                    minimumSize: Size(280, 50),
                  ),
                  onPressed: () {
                    widget.account
                        .createOAuth2Session(
                            provider: 'github', success: '', failure: '')
                        .then((value) {
                      _getAccount();
                    }).catchError((error) {
                      print(error.message);
                    }, test: (e) => e is AppwriteException);
                  }),
              Padding(padding: EdgeInsets.all(10.0)),
              ElevatedButton(
                  child: Text(
                    "Login with Google",
                    style: TextStyle(color: Colors.white, fontSize: 20.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.all(16),
                    minimumSize: Size(280, 50),
                  ),
                  onPressed: () {
                    widget.account
                        .createOAuth2Session(provider: 'google')
                        .then((value) {
                      _getAccount();
                    }).catchError((error) {
                      print(error.message);
                    }, test: (e) => e is AppwriteException);
                  }),
              if (_user != null && _uploadedFile != null)
                FutureBuilder<Uint8List>(
                  future: widget.storage.getFilePreview(
                      bucketId: 'testbucket',
                      fileId: _uploadedFile!.$id,
                      width: 300),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.memory(snapshot.data!);
                    }
                    if (snapshot.hasError) {
                      if (snapshot.error is AppwriteException) {
                        print((snapshot.error as AppwriteException).message);
                      }
                      print(snapshot.error);
                    }
                    return CircularProgressIndicator();
                  },
                ),
              Padding(padding: EdgeInsets.all(20.0)),
              Divider(),
              Padding(padding: EdgeInsets.all(20.0)),
              Text(_username,
                  style: TextStyle(color: Colors.black, fontSize: 20.0)),
              Padding(padding: EdgeInsets.all(20.0)),
              Divider(),
              Padding(padding: EdgeInsets.all(20.0)),
              ElevatedButton(
                  child: Text('Logout',
                      style: TextStyle(color: Colors.white, fontSize: 20.0)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: const EdgeInsets.all(16),
                    minimumSize: Size(280, 50),
                  ),
                  onPressed: () {
                    widget.account
                        .deleteSession(sessionId: 'current')
                        .then((response) {
                      setState(() {
                        _username = 'No Session';
                      });
                    }).catchError((error) {
                      print(error.message);
                    }, test: (e) => e is AppwriteException);
                  }),
              Padding(padding: EdgeInsets.all(20.0)),
            ],
          ),
        ),
      ),
    );
  }
}

class MyDocument {
  final String userName;
  final String id;
  MyDocument({
    required this.userName,
    required this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'id': id,
    };
  }

  factory MyDocument.fromMap(Map<String, dynamic> map) {
    return MyDocument(
      userName: map['username'],
      id: map['\$id'],
    );
  }

  String toJson() => json.encode(toMap());

  factory MyDocument.fromJson(String source) =>
      MyDocument.fromMap(json.decode(source));

  @override
  String toString() => 'MyDocument(userName: $userName, id: $id)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MyDocument && other.userName == userName && other.id == id;
  }

  @override
  int get hashCode => userName.hashCode ^ id.hashCode;
}
