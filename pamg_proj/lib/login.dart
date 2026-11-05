import 'package:flutter/material.dart';
class LoginPage extends StatefulWidget {
  const LoginPage ({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

//----------------mechanizm logowania i informacja zwrotna--------//
  void login() {
    String username = usernameController.text;
    String password = passwordController.text;
//----------------dodac username i password---------------------//
    if (username == 'pamg' && password == 'projekt') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prawidłowe dane logowania'))
      );
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => const MapPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nieprawidłowe dane logowania'))
      );
    }
  }
  //-----------------budowa interfejsu strony logowania--------//
  @override
  Widget build(BuildContext context) {
    const Color loginBackground = Color.fromARGB(255, 194, 251, 188);
    return Scaffold(
      backgroundColor: loginBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              const Text(
                'GeoGrav',
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Color.fromARGB(255, 0, 67, 7)
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.lock_outline, size: 70),
              const SizedBox(height: 25),
              const Text(
                'Logowanie',
                style: TextStyle(fontSize: 34, fontWeight:FontWeight.bold),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Login',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Hasło',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color.fromARGB(255, 0, 67, 7),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: login, 
                  child: const Padding(
                    padding: EdgeInsets.all(15),
                    child: Text('Zaloguj', style: TextStyle(fontSize: 18)))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
