import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class LinearRegressionScreen extends StatefulWidget {
  final String fileId;
  const LinearRegressionScreen({super.key, required this.fileId});

  @override
  State<LinearRegressionScreen> createState() => _LinearRegressionScreenState();
}

class _LinearRegressionScreenState extends State<LinearRegressionScreen> {
  List<String> columnNames = [];
  String? selectedTarget;
  List<String> selectedFeatures = [];
  Map<String, dynamic>? modelResults;
  bool isLoading = false;

  static const String apiBaseUrl =
      'https://ruling-thereby-moms-canadian.trycloudflare.com';

  @override
  void initState() {
    super.initState();
    fetchColumnNames();
  }

  Future<void> fetchColumnNames() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/preview/${widget.fileId}?encoded=true'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          columnNames = List<String>.from(data['columns']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Error al obtener columnas codificadas: ${e.toString()}"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> trainLinearModel() async {
    if (selectedTarget == null || selectedFeatures.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                "Selecciona objetivo y al menos una variable predictora"),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => isLoading = true);

    final body = json.encode({
      "target": selectedTarget,
      "features": selectedFeatures,
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/train-linear-regression/${widget.fileId}'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            modelResults = data;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Modelo entrenado exitosamente!"),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error desconocido');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al entrenar modelo: ${e.toString()}"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String formatFixed(dynamic number, int digits) {
    if (number == null || number == 'null') return '-';
    try {
      return (double.tryParse(number.toString()) ?? 0.0)
          .toStringAsFixed(digits);
    } catch (e) {
      return '-';
    }
  }

  String formatExp(dynamic number, int digits) {
    if (number == null || number == 'null') return '-';
    try {
      return (double.tryParse(number.toString()) ?? 0.0)
          .toStringAsExponential(digits);
    } catch (e) {
      return '-';
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.blue.shade700, size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnovaTable() {
    if (modelResults!["anova"] == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Tabla ANOVA", Icons.assessment,
            color: Colors.purple.shade700),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: DataTable(
              columnSpacing: 24,
              dataRowHeight: 48,
              headingRowHeight: 48,
              columns: const [
                DataColumn(label: Text("Fuente")),
                DataColumn(label: Text("Suma Cuadrados")),
                DataColumn(label: Text("GL")),
                DataColumn(label: Text("F")),
                DataColumn(label: Text("p")),
              ],
              rows: List<DataRow>.from(
                modelResults!["anova"].map((row) => DataRow(cells: [
                      DataCell(Text(row["index"]?.toString() ?? "")),
                      DataCell(Text(formatFixed(row["sum_sq"], 2))),
                      DataCell(Text(formatFixed(row["df"], 2))),
                      DataCell(Text(formatFixed(row["F"], 2))),
                      DataCell(Text(formatExp(row["PR(>F)"], 2))),
                    ])),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget buildModelSummary() {
    if (modelResults == null) return const SizedBox();

    List<DataRow> coefRows = [];
    for (int i = 0; i < modelResults!["features"].length; i++) {
      coefRows.add(DataRow(
        cells: [
          DataCell(
            Text(
              modelResults!["features"][i],
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          DataCell(
            Text(
              formatFixed(modelResults!["coefficients"][i], 4),
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DataCell(
            Text(
              formatExp(modelResults!["p_values"][i], 2),
              style: TextStyle(
                color: (modelResults!["p_values"][i] as num) < 0.05
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Resultados del Modelo", Icons.analytics),

        _buildMetricCard(
            "Ecuación del modelo", modelResults!["equation"] ?? "-"),

        _buildMetricCard("Coeficiente de determinación (R²)",
            formatFixed(modelResults!["r_squared"], 4)),

        const SizedBox(height: 24),

        _buildSectionHeader("Coeficientes del Modelo", Icons.table_chart),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 20),
            child: DataTable(
              columnSpacing: 32,
              dataRowHeight: 48,
              headingRowHeight: 48,
              columns: const [
                DataColumn(
                  label: Text(
                    "Variable",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Coeficiente",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "p-valor",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
              rows: coefRows,
            ),
          ),
        ),

        // Tabla ANOVA
        if (modelResults!["anova"] != null) _buildAnovaTable(),

        if (modelResults!["residuals_plot"] != null) ...[
          const SizedBox(height: 24),
          _buildSectionHeader("Análisis de Residuales", Icons.show_chart),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.only(bottom: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child:
                  Image.memory(base64Decode(modelResults!["residuals_plot"])),
            ),
          ),
        ],

        if (modelResults!["visual_plot"] != null) ...[
          const SizedBox(height: 24),
          _buildSectionHeader("Visualización del Modelo", Icons.insights),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(base64Decode(modelResults!["visual_plot"])),
            ),
          ),
        ],
      ],
    );
  }

  List<String> getFilteredFeatures() {
    return columnNames.where((col) => col != selectedTarget).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFeatureOptions = getFilteredFeatures();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Regresión Lineal",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, size: 26),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Ayuda"),
                  content: const Text(
                    "Selecciona una variable objetivo y las variables predictoras "
                    "para entrenar el modelo de regresión lineal.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Entendido"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Entrenando modelo...",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Configuración del Modelo",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Variable objetivo:",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedTarget,
                                  hint: const Text(
                                    "Selecciona la variable objetivo",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.arrow_drop_down,
                                      size: 28),
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 17,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedTarget = value;
                                      selectedFeatures.remove(value);
                                    });
                                  },
                                  items: columnNames
                                      .map((col) => DropdownMenuItem(
                                            value: col,
                                            child: Text(col),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Variables predictoras:",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (filteredFeatureOptions.isEmpty)
                              const Text(
                                "Selecciona primero la variable objetivo",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: filteredFeatureOptions.map((col) {
                                  final selected =
                                      selectedFeatures.contains(col);
                                  return ChoiceChip(
                                    label: Text(col),
                                    selected: selected,
                                    selectedColor: Colors.blue.withOpacity(0.2),
                                    backgroundColor: Colors.grey.shade100,
                                    labelStyle: TextStyle(
                                      fontSize: 15,
                                      color: selected
                                          ? Colors.blue.shade800
                                          : Colors.grey.shade800,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: selected
                                            ? Colors.blue.shade400
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    onSelected: (bool value) {
                                      setState(() {
                                        value
                                            ? selectedFeatures.add(col)
                                            : selectedFeatures.remove(col);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 32),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: trainLinearModel,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 3,
                                    ),
                                    child: const Text(
                                      "ENTRENAR MODELO",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ModelExplanationScreen(),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(
                                        color: Colors.blue.shade700,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.help_outline,
                                            color: Colors.blue.shade700,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          "AYUDA",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (modelResults != null) buildModelSummary(),
                  ],
                ),
              ),
      ),
    );
  }
}

// Agrega este nuevo widget al mismo archivo, antes de la clase LinearRegressionScreen

class ModelExplanationScreen extends StatelessWidget {
  const ModelExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explicación del Modelo'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExplanationCard(
              icon: Icons.linear_scale,
              title: 'Coeficientes',
              content:
                  'Los coeficientes indican cuánto cambia la variable objetivo por cada unidad de cambio en la variable predictora, manteniendo constantes las demás variables.',
            ),
            _buildExplanationCard(
              icon: Icons.assessment,
              title: 'R² (Coeficiente de Determinación)',
              content:
                  'Mide la proporción de la variación en la variable objetivo que es predecible a partir de las variables predictoras. Valores cercanos a 1 indican mejor ajuste.',
            ),
            _buildExplanationCard(
              icon: Icons.table_chart,
              title: 'Tabla ANOVA',
              content:
                  'Analiza la varianza para determinar si existe una relación significativa entre las variables. Valores p < 0.05 indican significancia estadística.',
            ),
            _buildExplanationCard(
              icon: Icons.show_chart,
              title: 'Gráfico de Residuales',
              content:
                  'Muestra la diferencia entre los valores observados y predichos. Un buen modelo tendrá residuales distribuidos aleatoriamente sin patrones claros.',
            ),
            _buildExplanationCard(
              icon: Icons.insights,
              title: 'Visualización del Modelo',
              content:
                  'Muestra la relación entre las variables predictoras y la objetivo. En modelos simples, se ve como una línea recta que mejor ajusta los datos.',
            ),
            const SizedBox(height: 20),
            Text(
              'Interpretación de p-valores:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 10),
            _buildPValueIndicator(
                'p < 0.01', 'Muy significativo', Colors.green.shade700),
            _buildPValueIndicator(
                '0.01 ≤ p < 0.05', 'Significativo', Colors.lightGreen.shade700),
            _buildPValueIndicator('0.05 ≤ p < 0.1',
                'Marginalmente significativo', Colors.orange.shade700),
            _buildPValueIndicator(
                'p ≥ 0.1', 'No significativo', Colors.red.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPValueIndicator(String value, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
