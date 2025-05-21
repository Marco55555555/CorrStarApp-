import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'MainAnalysisScreen.dart';

class PrepareDataScreen extends StatefulWidget {
  final String fileId;

  const PrepareDataScreen({super.key, required this.fileId});

  @override
  _PrepareDataScreenState createState() => _PrepareDataScreenState();
}

class _PrepareDataScreenState extends State<PrepareDataScreen> {
  List<String> columnNames = [];
  List<Map<String, dynamic>> dataPreview = [];
  List<String> categoricalColumns = [];
  Map<String, String> selectedCategoricalsWithType = {};
  bool isLoading = true;

  static const String apiBaseUrl =
      'https://ruling-thereby-moms-canadian.trycloudflare.com';

  @override
  void initState() {
    super.initState();
    fetchDataPreview();
  }

  Future<void> fetchDataPreview() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/preview/${widget.fileId}?rows=10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        columnNames = List<String>.from(data['columns']);
        dataPreview = List<Map<String, dynamic>>.from(data['preview']);

        categoricalColumns = columnNames.where((col) {
          return dataPreview
              .any((row) => double.tryParse(row[col].toString()) == null);
        }).toList();
      } else {
        throw Exception("Error al cargar vista previa de datos");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> applyAutomaticEncoding() async {
    if (selectedCategoricalsWithType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos una columna")),
      );
      return;
    }

    setState(() => isLoading = true);
    final body = json.encode({
      "file_id": widget.fileId,
      "columns": selectedCategoricalsWithType.keys.toList(),
      "column_types": selectedCategoricalsWithType,
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/encode-categoricals-auto/'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          dataPreview = List<Map<String, dynamic>>.from(data['preview']);
          if (dataPreview.isNotEmpty) {
            columnNames = dataPreview.first.keys.toList();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Codificación aplicada exitosamente")),
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error desconocido');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al codificar: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Preparación de Datos"),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Vista Previa del Dataset",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      columns: columnNames
                          .map((name) => DataColumn(label: Text(name)))
                          .toList(),
                      rows: dataPreview
                          .map((row) => DataRow(
                                cells: columnNames
                                    .map((col) =>
                                        DataCell(Text(row[col].toString())))
                                    .toList(),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text("Codificación de Variables Categóricas",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: categoricalColumns.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      String col = categoricalColumns[index];
                      return ListTile(
                        title: Text(col),
                        trailing: DropdownButton<String>(
                          hint: const Text("Tipo"),
                          value: selectedCategoricalsWithType[col],
                          items: const [
                            DropdownMenuItem(
                              value: "nominal",
                              child: Text("Nominal"),
                            ),
                            DropdownMenuItem(
                              value: "ordinal",
                              child: Text("Ordinal"),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                selectedCategoricalsWithType[col] = value;
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: selectedCategoricalsWithType.isNotEmpty
                        ? applyAutomaticEncoding
                        : null,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text("Aplicar Codificación"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MainAnalysisScreen(fileId: widget.fileId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics),
                    label: const Text("Continuar al Análisis"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
