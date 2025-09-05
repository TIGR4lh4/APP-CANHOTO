import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool loading = false;
  String msg = "";

  Future<void> register() async {
    if (passCtrl.text != confirmCtrl.text) {
      setState(() => msg = "⚠️ Senhas não conferem");
      return;
    }

    setState(() => loading = true);

    final res = await http.post(
      Uri.parse("${Config.apiUrl}/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": userCtrl.text,
        "email": emailCtrl.text,
        "password": passCtrl.text,
      }),
    );

    setState(() => loading = false);

    if (res.statusCode == 201) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() {
        msg = "Erro ao cadastrar (talvez e-mail já usado)";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Cadastro"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: 20),
            Icon(Icons.person_add, size: 80, color: Colors.blueAccent),
            SizedBox(height: 16),
            Text(
              "Crie sua conta",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade800,
              ),
            ),
            SizedBox(height: 32),

            TextField(
              controller: userCtrl,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
                labelText: "Usuário",
              ),
            ),
            SizedBox(height: 16),

            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.email_outlined),
                labelText: "E-mail",
              ),
            ),
            SizedBox(height: 16),

            TextField(
              controller: passCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                labelText: "Senha",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 16),

            TextField(
              controller: confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_reset),
                labelText: "Confirmar Senha",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : register,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Cadastrar", style: TextStyle(fontSize: 18)),
              ),
            ),
            SizedBox(height: 16),

            if (msg.isNotEmpty)
              Text(msg, style: TextStyle(color: Colors.red)),

            SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Já tem conta? "),
                GestureDetector(
                  child: Text(
                    "Entrar",
                    style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
