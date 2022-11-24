import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((value) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenAI API test app',
      home: MyHomePage(token: dotenv.env['token'] as String),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.token});

  final String token;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  final searchString = TextEditingController();
  String imgUrl = '';
  bool isRequest = false;
  String error = '';

  Future<void> fetchImages(requestString) async {
    try {
      final response = await http
          .post(Uri.parse('https://api.openai.com/v1/images/generations'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${widget.token}'
              },
              body: jsonEncode(<String, dynamic>{
                'prompt': requestString,
                'n': 1,
                'size': '1024x1024'
              }))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final url = jsonDecode(response.body)['data'][0]['url'];
        print(url);
        setState(() {
          imgUrl = url;
          //isRequest = false;
          error = '';
        });
      } else {
        setState(() {
          isRequest = false;
          error = 'Response status code was ${response.statusCode}';
        });
      }
    } on TimeoutException catch (_) {
      setState(() {
        isRequest = false;
        error = 'request timeout';
      });
    } catch (_) {
      setState(() {
        isRequest = false;
        error = 'something went wrong';
      });
    }
  }

  void send(context) {
    FocusScope.of(context).unfocus();
    setState(() {
      isRequest = true;
      error = '';
    });
    fetchImages(searchString.text);
  }

  progressBar(lp) {
    return CircularProgressIndicator(
      value: lp.expectedTotalBytes != null
          ? lp.cumulativeBytesLoaded / lp.expectedTotalBytes!
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != '') {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error))));
    }
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextFormField(
                      controller: searchString,
                      textInputAction: TextInputAction.go,
                      onFieldSubmitted: (v) => send(context))),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: isRequest ? null : () => send(context),
                  child: Text(isRequest ? 'Please wait...' : 'Submit'),
                ),
              ),
              imgUrl != ''
                  ? SingleChildScrollView(
                      child: Image.network(
                      imgUrl,
                      semanticLabel: searchString.text,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        if (loadingProgress.cumulativeBytesLoaded ==
                            loadingProgress.expectedTotalBytes) {
                          WidgetsBinding.instance.addPostFrameCallback(
                              (_) => setState(() => (isRequest = false)));
                        }
                        return Center(child: progressBar(loadingProgress));
                      },
                    ))
                  : Container()
            ],
          ),
        ));
  }
}
