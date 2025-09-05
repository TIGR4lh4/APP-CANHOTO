import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'nf_screen.dart';

class EmpresaNFScreen extends StatefulWidget {
  @override
  _EmpresaNFScreenState createState() => _EmpresaNFScreenState();
}

class _EmpresaNFScreenState extends State<EmpresaNFScreen> {
  List empresas = [];
  int? empresaSelecionada;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchEmpresas();
  }

  Future<void> fetchEmpresas() async {
    try {
      final res = await http.get(Uri.parse("${Config.apiUrl}/empresas"));
      if (res.statusCode == 200) {
        setState(() {
          empresas = jsonDecode(res.body);
          loading = false;
        });
      } else {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar empresas")),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Falha de conexão com servidor")),
      );
    }
  }

  void irParaNF() {
    if (empresaSelecionada != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NFScreen(
            username: "admin",
            empresaId: empresaSelecionada!, // ✅ usa a empresa escolhida
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Selecione uma empresa")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Selecionar Empresa"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: loading
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.business,
                    size: 80,
                    color: Colors.blueAccent,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Escolha a Empresa",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(height: 30),

                  // Dropdown de Empresas
                  DropdownButtonFormField<int>(
                    isExpanded: true, // ocupa toda largura
                    decoration: InputDecoration(
                      labelText: "Selecione a Empresa",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    value: empresaSelecionada,
                    items: empresas.map<DropdownMenuItem<int>>((e) {
                      return DropdownMenuItem<int>(
                        value: e["EmpresaId"],
                        child: Text(
                          "${e["EmpresaId"]} - ${e["EmpresaNomeInterno"]}",
                          overflow: TextOverflow.ellipsis, // evita overflow
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        empresaSelecionada = value;
                      });
                    },
                  ),
                  SizedBox(height: 40),

                  // Botão Continuar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: irParaNF,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Continuar",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
