import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoscanner/style/custom_text_style.dart';

final _firebase = FirebaseAuth.instance;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {

  final _form = GlobalKey<FormState>();
  var _isLogin = true;
  var _enteredEmail = '';
  var _enteredPassword = '';
  var _enteredUsername = '';
  var _isAuthenticating = false;

  Future<void> _submit() async {
    final isValid = _form.currentState!.validate();

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields correctly.')),
      );
      return;
    }

    _form.currentState!.save();

    setState(() {
      _isAuthenticating = true;
    });

    try {
      UserCredential userCredentials;
      if (_isLogin) {
        userCredentials = await _firebase.signInWithEmailAndPassword(
          email: _enteredEmail, 
          password: _enteredPassword,
        );
        print('User UID after login: ${userCredentials.user!.uid}');
      } else {
        userCredentials = await _firebase.createUserWithEmailAndPassword(
          email: _enteredEmail, 
          password: _enteredPassword,
        );
        print('User UID after registration: ${userCredentials.user!.uid}');
        await _storeUserData(userCredentials.user!.uid, _enteredUsername, _enteredEmail);
      }

    } on FirebaseAuthException catch (error) {
      print('Firebase Auth Error: ${error.message}');
      _showAuthenticationError(error);
    } catch (error) {
      print('General Error: $error');
      _showGeneralError(error);
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _storeUserData(String userId, String username, String email) async {
    try {
      await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set({
          'username': username,
          'email': email,
        });
      print('User data stored successfully for UID: $userId');
    } catch (error) {
      print('Error storing user data: $error');
    }
  }

  void _showAuthenticationError(FirebaseAuthException error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Authentication failed.')),
      );
    }
  }

  void _showGeneralError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(
                  top: 30,
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                width: 200,
                child: Image.asset('assets/logo.png'),
              ),
              Card(
                color: const Color.fromARGB(255, 243, 243, 243),
                margin: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isLogin)
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'User Name',
                                labelStyle: Theme.of(context).textTheme.bodySmall,
                                floatingLabelStyle: Theme.of(context).textTheme.bodySmall,
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                              ),
                              enableSuggestions: false,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              validator: (value) {
                                if (value == null || value.isEmpty || value.trim().length < 4) {
                                  return 'Please enter a valid username (more than 4 chars).';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _enteredUsername = value!;
                              },
                            ),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: Theme.of(context).textTheme.bodySmall,
                              floatingLabelStyle: Theme.of(context).textTheme.bodySmall,
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty || !value.contains('@')) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _enteredEmail = value!;
                            },
                          ),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: Theme.of(context).textTheme.bodySmall,
                              floatingLabelStyle: Theme.of(context).textTheme.bodySmall,
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.trim().length < 7) {
                                return 'Password must be at least 7 characters long.';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _enteredPassword = value!;
                            },
                          ),
                          const SizedBox(height: 30),
                          if (_isAuthenticating) const CircularProgressIndicator(),
                          if (!_isAuthenticating)
                            ElevatedButton(
                              onPressed: _submit,
                              style: ButtonStyle(
                                fixedSize: WidgetStateProperty.all<Size>(
                                    const Size(200, 40)),
                                backgroundColor: WidgetStateProperty.all<Color>(
                                  const Color.fromRGBO(80, 7, 120, 1),
                                ), // Background Color
                                padding: WidgetStateProperty.all<EdgeInsets>(
                                    const EdgeInsets.all(5)), //
                                shape: WidgetStateProperty.all<
                                    RoundedRectangleBorder>(
                                  RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10.0), // Round Radius
                                  ),
                                ),
                              ),
                              child: Text(
                                _isLogin ? 'Login' : 'Register',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          if (!_isAuthenticating)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                });
                              },
                              child: Text(
                                _isLogin
                                    ? 'Create an account'
                                    : 'I already have an account.',
                                style: CustomTextStyle.smallBoldGreyText,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
