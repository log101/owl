import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'src/authentication.dart';
import 'src/widgets.dart';


import 'src/widgets.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ApplicationState(),
      builder: (context, _) => App(),
    ),
  );
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Owl',
      theme: ThemeData(
        buttonTheme: Theme.of(context).buttonTheme.copyWith(
              highlightColor: Colors.deepPurple,
            ),
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: null,
            body: Center(
              child: Consumer<ApplicationState>(
                builder: (context, appState, _) => Authentication(
                  email: appState.email,
                  loginState: appState.loginState,
                  startLoginFlow: appState.startLoginFlow,
                  verifyEmail: appState.verifyEmail,
                  signInWithEmailAndPassword: appState.signInWithEmailAndPassword,
                  cancelRegistration: appState.cancelRegistration,
                  registerAccount: appState.registerAccount,
                  signOut: appState.signOut,
                ),
              ),
            ),
          );
  }
}

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  Future<void> init() async {
    await Firebase.initializeApp();

    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        _loginState = ApplicationLoginState.loggedIn;
        _recipesSubscription = FirebaseFirestore.instance
            .collection('recipes')
            .orderBy('timestamp', descending: true)
            .snapshots()
            .listen((snapshot) {
          _recipes = [];
          snapshot.docs.forEach((document) {
            _recipes.add(
              RecipeInfo(
                title: document.data()['title'],
                date: document.data()['date'],
                howto: document.data()['howto'],
                info: document.data()['info'],
                imageurl: document.data()['imageurl'],
                done: document.data()['done'],
                category: document.data()['category'],
              ),
            );
          });
          notifyListeners();
        });
        _guestBookSubscription = FirebaseFirestore.instance
            .collection('guestbook')
            .orderBy('timestamp', descending: true)
            .snapshots()
            .listen((snapshot) {
          _guestBookMessages = [];
          snapshot.docs.forEach((document) {
            _guestBookMessages.add(
              GuestBookMessage(
                name: document.data()['name'],
                message: document.data()['text'],
              ),
            );
          });
          notifyListeners();
        });

      } else {
        _loginState = ApplicationLoginState.loggedOut;
        _guestBookMessages = [];
        _guestBookSubscription?.cancel();

        _recipes = [];
        _recipesSubscription?.cancel();
      }
      notifyListeners();
    });
  }

  ApplicationLoginState _loginState = ApplicationLoginState.loggedOut;
  ApplicationLoginState get loginState => _loginState;

  String? _email;
  String? get email => _email;

  StreamSubscription<QuerySnapshot>? _guestBookSubscription;
  StreamSubscription<QuerySnapshot>? _recipesSubscription;
  List<GuestBookMessage> _guestBookMessages = [];
  List<RecipeInfo> _recipes = [];
  List<GuestBookMessage> get guestBookMessages => _guestBookMessages;
  List<RecipeInfo> get recipes => _recipes;


  void startLoginFlow() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  void verifyEmail(
      String email,
      void Function(FirebaseAuthException e) errorCallback,
      ) async {
    try {
      var methods =
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.contains('password')) {
        _loginState = ApplicationLoginState.password;
      } else {
        _loginState = ApplicationLoginState.register;
      }
      _email = email;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void signInWithEmailAndPassword(
      String email,
      String password,
      void Function(FirebaseAuthException e) errorCallback,
      ) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void cancelRegistration() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  void registerAccount(String email, String displayName, String password,
      void Function(FirebaseAuthException e) errorCallback) async {
    try {
      var credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user!.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void signOut() {
    FirebaseAuth.instance.signOut();
  }

  // Firestore
  Future<DocumentReference> addMessageToGuestBook(String message) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance.collection('guestbook').add(<String, dynamic>{
      'text': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'name': FirebaseAuth.instance.currentUser!.displayName,
      'userId': FirebaseAuth.instance.currentUser!.uid,
    });
  }

}

class RecipeInfo {
  RecipeInfo({required this.date, required this.title, this.howto = "", this.imageurl = "", this.info = "", this.done = false, this.category = ""});
  final int date;
  final String category;
  final String title;
  final String howto;
  final String imageurl;
  final String info;
  final bool done;
}

class RecipesOfThatDay extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _RecipesOfThatDayState();

}

class _RecipesOfThatDayState extends State<RecipesOfThatDay> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ApplicationState>(
      builder: (context, appState, _) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0),
            child: Text("Todo", style: Theme.of(context).textTheme.headline6),
          ),
          DividerSubHeader(title: "Medicine"),
          for (var recipe in appState.recipes)
            if (recipe.category == "medicine" && recipe.done != true)
            RecipeTile(recipe: recipe),
          Divider(indent: 16),
          DividerSubHeader(title: "Food"),
          for (var recipe in appState.recipes)
            if (recipe.category == "food" && recipe.done != true)
              RecipeTile(recipe: recipe),
          Divider(indent: 16),
          DividerSubHeader(title: "Exercise"),
          for (var recipe in appState.recipes)
            if (recipe.category == "exercise" && recipe.done != true)
              RecipeTile(recipe: recipe),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0),
            child: Text("Done", style: Theme.of(context).textTheme.headline6),
          ),
          for (var recipe in appState.recipes)
            if (recipe.done == true)
              RecipeTile(recipe: recipe),
        ],
      ),
    );
  }
}

class DividerSubHeader extends StatelessWidget {
  const DividerSubHeader({
    Key? key, required this.title,
  }) : super(key: key);

  final String title;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 16, top: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.bodyText2!.copyWith(
              fontSize: 12.0,
              color: Theme.of(context).textTheme.caption!.color),
          textAlign: TextAlign.start,
        ),
      ),
    );
  }
}

class RecipeTile extends StatelessWidget {
  const RecipeTile({
    Key? key,
    required this.recipe,
  }) : super(key: key);

  final RecipeInfo recipe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0),
    child: ListTile(
      contentPadding: EdgeInsets.all(8.0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(recipe.title),
            Text(recipe.howto, style: TextStyle(color: Colors.grey)),
          ]),
        leading: Image.network(recipe.imageurl),
      trailing: Icon(
        (recipe.done) ? Icons.task_alt_outlined : Icons.error_outline_outlined, color: (recipe.done) ? Colors.green : Colors.red,
      ),
    ));
  }
}

class GuestBookMessage {
  GuestBookMessage({required this.name, required this.message});
  final String name;
  final String message;
}

class GuestBook extends StatefulWidget {
  GuestBook({required this.addMessage, required this.messages});
  final FutureOr<void> Function(String message) addMessage;
  final List<GuestBookMessage> messages;

  @override
  _GuestBookState createState() => _GuestBookState();
}

class _GuestBookState extends State<GuestBook> {
  final _formKey = GlobalKey<FormState>(debugLabel: '_GuestBookState');
  final _controller = TextEditingController();

  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Leave a message',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your message to continue';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  StyledButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await widget.addMessage(_controller.text);
                        _controller.clear();
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.send),
                        SizedBox(width: 4),
                  Text('SEND'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    SizedBox(height: 8),
    for (var message in widget.messages)
      Paragraph('${message.name}: ${message.message}'),
    SizedBox(height: 8),
  ]);
  }
}

// Consumer for messages
/*
          Consumer<ApplicationState>(
            builder: (context, appState, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (appState.loginState == ApplicationLoginState.loggedIn) ...[
                  Header('Discussion'),
                  GuestBook(
                    addMessage: (String message) =>
                        appState.addMessageToGuestBook(message),
                    messages: appState.guestBookMessages,
                  ),
                ],
              ],
            ),
          )
 */