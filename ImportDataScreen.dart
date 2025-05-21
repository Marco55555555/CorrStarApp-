import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'PrepareDataScreen.dart';

class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  _ImportDataScreenState createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  String? apiFileId;
  bool isLoading = false;
  static const String apiBaseUrl =
      'https://ruling-thereby-moms-canadian.trycloudflare.com';

  Future<void> uploadCSV(PlatformFile file) async {
    setState(() => isLoading = true);
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/upload-csv/'),
      );

      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path!,
        ));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var result = json.decode(responseData);

      if (response.statusCode == 200) {
        apiFileId = result['file_id'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Archivo cargado correctamente"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrepareDataScreen(fileId: apiFileId!),
          ),
        );
      } else {
        throw Exception(result['detail'] ?? 'Error al cargar el archivo');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al subir el archivo: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        dialogTitle: 'Selecciona tu archivo CSV',
      );

      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.first;

      // Verificación de tamaño aproximado (1 millón de registros ~ 50MB)
      final fileSize = file.size / (1024 * 1024); // Convertir a MB
      if (fileSize > 50) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Archivo demasiado grande"),
            content: const Text(
              "El archivo seleccionado excede el límite recomendado de 1 millón de registros.\n\n"
              "Para un mejor rendimiento, por favor utiliza archivos más pequeños.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Entendido"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        );
        return;
      }

      await uploadCSV(file);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al seleccionar el archivo: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Importar Datos"),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload,
                  size: 80,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Importar Archivo CSV",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Sube tu archivo CSV para comenzar el análisis. "
                  "La aplicación soporta hasta 1 millón de registros.\n\n"
                  "Para mejores resultados, asegúrate que tu archivo:",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  children: [
                    _buildBulletPoint("Tenga encabezados en la primera fila"),
                    _buildBulletPoint("Use formato UTF-8"),
                    _buildBulletPoint("Esté bien formateado sin celdas vacías"),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              isLoading
                  ? const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    )
                  : ElevatedButton.icon(
                      onPressed: pickFile,
                      icon: const Icon(Icons.upload_file, size: 24),
                      label: const Text(
                        "Seleccionar Archivo CSV",
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
              const SizedBox(height: 24),
              const Text(
                "Formatos soportados: .csv (Tamaño máximo: 50MB)",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4.0, right: 8.0),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
