import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoscanner/style/custom_text_style.dart';
import 'package:geoscanner/widgets/user_image_picker.dart';

final _firebase = FirebaseAuth.instance;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Create a global key to get access to the form state
  final _form = GlobalKey<FormState>();

  var _isLogin = true;
  var _enteredEmail = '';
  var _enteredPassword = '';
  var _enteredUsername = '';
  File? _selectedImage;
  var _isAuthenticating = false;

  // Use async to handle the Future<UserCredentials>
  void _submit() async {
    final isValid = _form.currentState!.validate();

    if (!isValid || _selectedImage == null && !_isLogin) {
      // show error message
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick an image.'),
        ),
      );
      return;
    }

    _form.currentState!.save();

    setState(() {
      _isAuthenticating = true;
    });

    try {
      if (_isLogin) {
        // Log user in
        // ignore: unused_local_variable
        final userCredentials = await _firebase.signInWithEmailAndPassword(
            email: _enteredEmail, password: _enteredPassword);
      } else {
        // Register user
        final userCredentials = await _firebase.createUserWithEmailAndPassword(
            email: _enteredEmail, password: _enteredPassword);

        // Initialize the storage reference
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_profile')
            .child('${userCredentials.user!.uid}.jpg');

        // Upload the image to the storage
        await storageRef.putFile(_selectedImage!);
        // Get the image URL for future usage
        final imageUrl = await storageRef.getDownloadURL();

        // Save the user profile data to the Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredentials.user!.uid)
            .set({
          'username': _enteredUsername,
          'email': _enteredEmail,
          'image_url': imageUrl,
        });
      }
    } on FirebaseAuthException catch (error) {
      // Handle the error
      if (error.code == 'email-already-in-use') {
        //...
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Authentication failed.'),
        ),
      );
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        UserImagePicker(
                          onPickImage: (pickedImage) {
                            _selectedImage = pickedImage;
                          },
                        ),
                      if (!_isLogin)
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'User Name',
                            labelStyle: Theme.of(context).textTheme.bodySmall,
                            floatingLabelStyle:
                                Theme.of(context).textTheme.bodySmall,
                            enabledBorder: const UnderlineInputBorder(
                              // Border style when enabled
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              // Border style when focused
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                          ),
                          enableSuggestions: false,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          // validator to handle the input validation
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty ||
                                value.trim().length < 4) {
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
                          floatingLabelStyle:
                              Theme.of(context).textTheme.bodySmall,
                          enabledBorder: const UnderlineInputBorder(
                            // Border style when enabled
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            // Border style when focused
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        // validator to handle the input validation
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty ||
                              !value.contains('@')) {
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
                          floatingLabelStyle:
                              Theme.of(context).textTheme.bodySmall,
                          enabledBorder: const UnderlineInputBorder(
                            // Border style when enabled
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            // Border style when focused
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                        obscureText: true,
                        // Make sure the password is longer than 7 characters
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
                            fixedSize: MaterialStateProperty.all<Size>(
                                const Size(200, 40)),
                            backgroundColor: MaterialStateProperty.all<Color>(
                              const Color.fromRGBO(80, 7, 120, 1),
                            ), // Background Color
                            padding: MaterialStateProperty.all<EdgeInsets>(
                                const EdgeInsets.all(5)), //
                            shape: MaterialStateProperty.all<
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
    )));
  }
}
