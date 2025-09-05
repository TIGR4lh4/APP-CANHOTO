import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:intl/intl.dart';
import '../config.dart';

class NFScreen extends StatefulWidget {
  final String username;
  final int empresaId;

  const NFScreen({
    Key? key,
    this.username = "admin",
    required this.empresaId,
  }) : super(key: key);

  @override
  _NFScreenState createState() => _NFScreenState();
}

class _NFScreenState extends State<NFScreen> {
  final nfCtrl = TextEditingController();
  final docCtrl = TextEditingController();
  final respCtrl = TextEditingController();
  final obsCtrl = TextEditingController();
  final dataRecebCtrl = TextEditingController();

  Map<String, dynamic>? nfData;
  File? image;
  String? uploadedFilename;
  bool loading = false;

  // Controle do cropper
  final CropController _cropController = CropController();
  Uint8List? _pickedImageData;
  bool cortando = false;
  bool confirmarUsado = false; // garante 1 clique apenas

  String formatarData(String? data) {
    if (data == null || data.isEmpty) return "";
    try {
      final dt = DateTime.parse(data);
      return DateFormat("dd/MM/yyyy", "pt_BR").format(dt);
    } catch (e) {
      return data;
    }
  }

  Future<void> buscarNF() async {
    if (nfCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Informe o número da NF")),
      );
      return;
    }

    setState(() {
      loading = true;
      nfData = null;
    });

    final url = "${Config.apiUrl}/nf/${nfCtrl.text}/${widget.empresaId}";
    try {
      final res = await http.get(Uri.parse(url));
      setState(() => loading = false);

      if (res.statusCode == 200) {
        setState(() {
          nfData = jsonDecode(res.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("NF não encontrada")),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao conectar com servidor")),
      );
    }
  }

  /// 🚀 FOTO + RECORTE
  Future<void> pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageData = bytes;
        confirmarUsado = false;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text("Recortar Imagem")),
            body: Crop(
              controller: _cropController,
              image: _pickedImageData!,
              onCropped: (croppedData) async {
                final tempDir = Directory.systemTemp;
                final file = await File(
                  "${tempDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg",
                ).writeAsBytes(croppedData);

                setState(() {
                  image = file;
                  cortando = false;
                });

                Navigator.pop(context);
              },
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatefulBuilder(
                      builder: (context, setBtn) {
                        return ElevatedButton(
                          onPressed: () {
                            if (cortando || confirmarUsado) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          color: Colors.blueAccent,
                                          strokeWidth: 2,
                                        ),
                                        SizedBox(width: 10),
                                        Text("Carregando...",
                                            style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              Future.delayed(Duration(seconds: 1), () {
                                Navigator.of(context).pop();
                              });
                              return;
                            }
                            setBtn(() {
                              cortando = true;
                              confirmarUsado = true;
                            });
                            _cropController.crop();
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(140, 45),
                            backgroundColor:
                                cortando ? Colors.grey : Colors.blueAccent,
                          ),
                          child: Text(
                              cortando ? "Processando..." : "Confirmar"),
                        );
                      },
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(140, 45),
                        backgroundColor: Colors.grey,
                      ),
                      child: Text("Cancelar"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao capturar imagem")),
      );
    }
  }

  Future<void> uploadImage() async {
    if (image == null || nfData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Primeiro busque a NF e tire a foto")),
      );
      return;
    }

    var req =
        http.MultipartRequest("POST", Uri.parse("${Config.apiUrl}/upload"));
    req.files.add(await http.MultipartFile.fromPath("file", image!.path));

    req.fields["Responsavel"] = respCtrl.text;
    req.fields["Documento"] = docCtrl.text;
    req.fields["NFObs"] = obsCtrl.text;
    req.fields["DataRecebimento"] = dataRecebCtrl.text;
    req.fields["NFNro"] = nfData!["NFNro"].toString();
    req.fields["NFSerie"] = nfData!["NFSerie"].toString();
    req.fields["EmpresaId"] = widget.empresaId.toString();

    var res = await req.send();
    final respStr = await res.stream.bytesToString();

    if (res.statusCode == 200) {
      final respJson = jsonDecode(respStr);
      setState(() {
        uploadedFilename = respJson["url"];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("📸 Imagem enviada com sucesso!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Erro ao enviar imagem")),
      );
    }
  }

  void logout() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Consulta NF - Empresa ${widget.empresaId}"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: "Sair",
            onPressed: logout,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nfCtrl,
                    decoration: InputDecoration(
                      labelText: "Número NF",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : buscarNF,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: loading
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text("Buscar"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            if (nfData != null) ...[
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("NF: ${nfData!['NFNro'] ?? ''}",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Série: ${nfData!['NFSerie'] ?? ''}"),
                      Text("Cliente: ${nfData!['CanhotoNFClienteNome'] ?? ''}",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Data Cadastro: ${formatarData(nfData!['NFDtCadastro'])}"),
                      Text("Data Emissão: ${formatarData(nfData!['NFDtEmissao'])}"),
                      Text("Usuário Cadastro: ${nfData!['NFUsuarioCadastro'] ?? ''}"),
                      Text("Data Atual: ${formatarData(nfData!['DataAtual'])}"),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              TextField(
                controller: docCtrl,
                decoration: InputDecoration(
                  labelText: "Documento",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16),

              TextField(
                controller: dataRecebCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Data de Recebimento",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    locale: const Locale("pt", "BR"),
                  );
                  if (pickedDate != null) {
                    dataRecebCtrl.text =
                        DateFormat("yyyy-MM-dd").format(pickedDate);
                  }
                },
              ),
              SizedBox(height: 16),

              TextField(
                controller: respCtrl,
                decoration: InputDecoration(
                  labelText: "Responsável",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: obsCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "NF Obs (opcional)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 20),

              if (image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(image!, height: 200, fit: BoxFit.cover),
                ),
                SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: pickImage,
                      icon: Icon(Icons.camera_alt),
                      label: Text("Tirar Foto"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: uploadImage,
                      icon: Icon(Icons.upload),
                      label: Text("Enviar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              /// 🔹 BOTÃO FINAL: apenas exibe popup e redireciona
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Exibe popup central
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 48),
                              SizedBox(height: 16),
                              Text(
                                "✅ Canhoto salvo!",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    await Future.delayed(Duration(seconds: 1));

                    if (mounted) {
                      Navigator.of(context).pop(); // fecha popup
                      Navigator.pushReplacementNamed(context, "/empresas");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Salvar Canhoto",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
