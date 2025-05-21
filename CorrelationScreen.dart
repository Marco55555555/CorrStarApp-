import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CorrelationScreen extends StatefulWidget {
  final String fileId;

  const CorrelationScreen({super.key, required this.fileId});

  @override
  State<CorrelationScreen> createState() => _CorrelationScreenState();
}

class _CorrelationScreenState extends State<CorrelationScreen> {
  List<String> columns = [];
  List<String> selectedVariables = [];
  String method = 'pearson';
  List<List<double>> correlationMatrix = [];
  bool isLoading = false;
  String? errorMessage;
  bool showSummary = false;

  static const String apiBaseUrl =
      'https://ruling-thereby-moms-canadian.trycloudflare.com';

  @override
  void initState() {
    super.initState();
    fetchColumns();
    method = ''; // O no establecer ningún valor inicial
  }

  Future<void> fetchColumns() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/preview/${widget.fileId}?encoded=true'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> preview = data['preview'];
        if (preview.isNotEmpty) {
          setState(() {
            columns = List<String>.from(preview.first.keys);
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error al obtener columnas: ${e.toString()}";
      });
    }
  }

  Future<void> calculateCorrelation() async {
    if (selectedVariables.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos 2 variables")),
      );
      return;
    }

    setState(() => isLoading = true);
    final body =
        json.encode({"variables": selectedVariables, "method": method});

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/calculate-correlation/${widget.fileId}'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          correlationMatrix = List<List<double>>.from(data['correlation_matrix']
              .map((row) => List<double>.from(row.map((e) => e.toDouble()))));
          errorMessage = null;
        });
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error desconocido');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildSummaryScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Información de Correlaciones"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => showSummary = false),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Tipos de Correlación",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(
                thickness: 2,
                indent: 40,
                endIndent: 40,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 24),

              // Tarjeta Pearson
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.show_chart,
                              color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            "Correlación de Pearson",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Mide la relación lineal entre variables continuas con distribución normal:",
                        style: TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "• Rango: -1 (negativa perfecta) a +1 (positiva perfecta)"),
                            Text("• Ideal para datos paramétricos"),
                            Text("• Sensible a valores atípicos"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tarjeta Spearman
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up,
                              color: Colors.green.shade700, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            "Correlación de Spearman",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Evalúa relaciones monotónicas (no necesariamente lineales):",
                        style: TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("• Usa rangos en lugar de valores brutos"),
                            Text("• Ideal para datos ordinales o no normales"),
                            Text("• Menos sensible a valores atípicos"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tarjeta Kendall
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.compare_arrows,
                              color: Colors.orange.shade700, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            "Correlación de Kendall",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Basada en la concordancia de pares de observaciones:",
                        style: TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("• Robustez con muestras pequeñas"),
                            Text(
                                "• Eficaz con datos con empates (valores repetidos)"),
                            Text(
                                "• Menos común pero más preciso que Spearman en ciertos casos"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorrelationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        // Encabezado de sección
        const Text(
          "Análisis de Correlación",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Divider(
          thickness: 1,
          indent: 40,
          endIndent: 40,
          color: Colors.blueGrey,
        ),
        const SizedBox(height: 16),

        // Información sobre métodos de correlación
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  "Selecciona el método de correlación:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    // Botón de información
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          showSummary = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 18),
                          SizedBox(width: 6),
                          Text("Info Correlaciones"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selector de métodos de correlación
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilterChip(
              avatar: const Icon(Icons.show_chart, size: 18),
              label: const Text("Pearson"),
              selected: selectedVariables.length >= 2 && method == 'pearson',
              onSelected: selectedVariables.length >= 2
                  ? (selected) {
                      if (selected) {
                        setState(() {
                          method = 'pearson';
                        });
                      }
                    }
                  : null,
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.blue.shade50,
              showCheckmark: true,
              elevation: 2,
            ),
            FilterChip(
              avatar: const Icon(Icons.trending_up, size: 18),
              label: const Text("Spearman"),
              selected: selectedVariables.length >= 2 && method == 'spearman',
              onSelected: selectedVariables.length >= 2
                  ? (selected) {
                      if (selected) {
                        setState(() {
                          method = 'spearman';
                        });
                      }
                    }
                  : null,
              selectedColor: Colors.green,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.green.shade50,
              showCheckmark: true,
              elevation: 2,
            ),
            FilterChip(
              avatar: const Icon(Icons.compare_arrows, size: 18),
              label: const Text("Kendall"),
              selected: selectedVariables.length >= 2 && method == 'kendall',
              onSelected: selectedVariables.length >= 2
                  ? (selected) {
                      if (selected) {
                        setState(() {
                          method = 'kendall';
                        });
                      }
                    }
                  : null,
              selectedColor: Colors.orange,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.orange.shade50,
              showCheckmark: true,
              elevation: 2,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Botón para calcular correlación
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ElevatedButton(
            onPressed:
                selectedVariables.length >= 2 ? calculateCorrelation : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 3,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calculate, size: 20),
                      SizedBox(width: 8),
                      Text("Calcular Correlación"),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Resultados de correlación
        if (correlationMatrix.isNotEmpty) ...[
          const Text(
            "Matriz de Correlación",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 16,
                columns: [
                  DataColumn(
                    label: Center(
                      child: Text(
                        'Variable',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                  ...selectedVariables.map(
                    (varName) => DataColumn(
                      label: Center(
                        child: Text(
                          varName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                rows: List<DataRow>.generate(
                  selectedVariables.length,
                  (i) => DataRow(
                    cells: [
                      DataCell(
                        Center(
                          child: Text(
                            selectedVariables[i],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      ...List.generate(
                        selectedVariables.length,
                        (j) => DataCell(
                          Center(
                            child: Text(
                              correlationMatrix[i][j].toStringAsFixed(3),
                              style: TextStyle(
                                color: _getCorrelationColor(
                                    correlationMatrix[i][j]),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "Interpretación: Valores cercanos a 1 = fuerte correlación positiva, "
              "cercanos a -1 = fuerte correlación negativa, "
              "cercanos a 0 = poca o ninguna correlación.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Color _getCorrelationColor(double value) {
    if (value > 0.7) return Colors.green.shade800;
    if (value > 0.3) return Colors.green;
    if (value < -0.7) return Colors.red.shade800;
    if (value < -0.3) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (showSummary) {
      return _buildSummaryScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Análisis de Correlación"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Información sobre correlaciones',
            onPressed: () {
              setState(() {
                showSummary = true;
              });
            },
          ),
        ],
      ),
      body: isLoading && correlationMatrix.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de variables
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Variables seleccionadas:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (columns.isEmpty)
                            const Center(child: CircularProgressIndicator())
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: columns.map((col) {
                                final selected =
                                    selectedVariables.contains(col);
                                return FilterChip(
                                  label: Text(col),
                                  selected: selected,
                                  onSelected: (bool value) {
                                    setState(() {
                                      if (value) {
                                        if (selectedVariables.length < 10) {
                                          selectedVariables.add(col);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    "Máximo 10 variables permitidas")),
                                          );
                                        }
                                      } else {
                                        selectedVariables.remove(col);
                                        correlationMatrix = [];
                                      }
                                    });
                                  },
                                  selectedColor: Theme.of(context).primaryColor,
                                  labelStyle: TextStyle(
                                    color: selected ? Colors.white : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 12),
                          if (selectedVariables.isNotEmpty)
                            Text(
                              "Seleccionadas: ${selectedVariables.length}",
                              style: const TextStyle(fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Sección de correlación
                  _buildCorrelationSection(),

                  // Mensaje de error
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
