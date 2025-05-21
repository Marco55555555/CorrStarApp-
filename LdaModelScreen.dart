import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LdaModelScreen extends StatefulWidget {
  final String fileId;
  final String apiBaseUrl;

  const LdaModelScreen({
    super.key,
    required this.fileId,
    this.apiBaseUrl = 'https://ruling-thereby-moms-canadian.trycloudflare.com',
  });

  @override
  State<LdaModelScreen> createState() => _LdaModelScreenState();
}

class _LdaModelScreenState extends State<LdaModelScreen> {
  List<String> columnNames = [];
  String? selectedTarget;
  List<String> selectedFeatures = [];
  Map<String, dynamic>? modelResults;
  bool isLoading = false;
  String? errorMessage;
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

  Future<void> trainLdaModel() async {
    if (selectedTarget == null || selectedFeatures.isEmpty) {
      setState(() {
        errorMessage = 'Selecciona objetivo y al menos una variable predictora';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      modelResults = null; // Resetear resultados anteriores
    });

    try {
      final body = json.encode({
        'target': selectedTarget,
        'features': selectedFeatures,
      });

      final resp = await http.post(
        Uri.parse('${widget.apiBaseUrl}/train-lda/${widget.fileId}'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (resp.statusCode == 200) {
        final responseData = json.decode(resp.body);
        setState(() {
          modelResults = {
            ...responseData['metrics'],
            ...responseData['plots'],
            'class_names': responseData['metrics']['class_names'],
          };
        });
      } else {
        final error = json.decode(resp.body);
        setState(() {
          errorMessage = error['detail'] ?? 'Error desconocido';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error al entrenar modelo: ${e.toString()}';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildResults() {
    if (modelResults == null) return const SizedBox();

    final accuracy = modelResults!['accuracy'] as double?;
    final f1Score = modelResults!['f1_score'] as double?;
    final aucScore = modelResults!['auc_score'] as double?;
    final explainedVar =
        List<double>.from(modelResults!['explained_variance_ratio'] ?? []);
    final classNames = List<String>.from(modelResults!['class_names'] ?? []);

    final confMatrix = modelResults!['confusion_matrix_image'] as String?;
    final scree = modelResults!['scree_plot'] as String?;
    final proj2d = modelResults!['projection_2d'] as String?;
    final proj3d = modelResults!['projection_3d'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Resultados del Modelo', Icons.analytics),
        if (accuracy != null)
          _buildMetricCard('Accuracy:', accuracy.toStringAsFixed(4)),
        if (f1Score != null)
          _buildMetricCard('F1 Score:', f1Score.toStringAsFixed(4)),
        if (aucScore != null)
          _buildMetricCard('AUC Score:', aucScore.toStringAsFixed(4)),
        const SizedBox(height: 16),
        _buildSectionHeader('Varianza Explicada', Icons.pie_chart),
        if (explainedVar.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: explainedVar.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Chip(
                    label: Text(
                      'LD${e.key + 1}: ${(e.value * 100).toStringAsFixed(1)}%',
                    ),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        if (confMatrix != null) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Matriz de Confusión', Icons.grid_on),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(base64Decode(confMatrix)),
            ),
          ),
        ],
        if (scree != null) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Scree Plot', Icons.show_chart),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(base64Decode(scree)),
            ),
          ),
        ],
        if (proj2d != null) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Proyección 2D', Icons.scatter_plot),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(base64Decode(proj2d)),
            ),
          ),
        ],
        if (proj3d != null) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Proyección 3D', Icons.threed_rotation),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(base64Decode(proj3d)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = columnNames.where((c) => c != selectedTarget).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis LDA'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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
                        'Entrenando modelo LDA...',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                  'Configuración del Modelo', Icons.tune),
                              const Text(
                                'Variable objetivo:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: selectedTarget,
                                    hint: const Text('Selecciona objetivo'),
                                    items: columnNames
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        selectedTarget = v;
                                        selectedFeatures.clear();
                                        errorMessage = null;
                                      });
                                    },
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.arrow_drop_down),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Variables predictoras:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (features.isEmpty)
                                const Text(
                                  'Selecciona primero la variable objetivo',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: features.map((c) {
                                    final sel = selectedFeatures.contains(c);
                                    return FilterChip(
                                      label: Text(c),
                                      selected: sel,
                                      backgroundColor: Colors.grey.shade100,
                                      selectedColor:
                                          Colors.teal.withOpacity(0.2),
                                      labelStyle: TextStyle(
                                        color: sel
                                            ? Colors.teal.shade800
                                            : Colors.grey.shade800,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: sel
                                              ? Colors.teal.shade400
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      onSelected: (yes) {
                                        setState(() {
                                          if (yes) {
                                            selectedFeatures.add(c);
                                          } else {
                                            selectedFeatures.remove(c);
                                          }
                                          errorMessage = null;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Card(
                            color: Colors.red.shade50,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.red.shade200,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: trainLdaModel,
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
                                        const LdaExplanationScreen(),
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
                                      color: Colors.blue.shade700, size: 20),
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
                      const SizedBox(height: 32),
                      buildResults(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class LdaExplanationScreen extends StatelessWidget {
  const LdaExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explicación de LDA'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExplanationCard(
              icon: Icons.analytics,
              title: 'Accuracy',
              content:
                  'Porcentaje de predicciones correctas del modelo. Mide la capacidad general del modelo para clasificar correctamente las observaciones.',
            ),
            _buildExplanationCard(
              icon: Icons.show_chart,
              title: 'F1 Score',
              content:
                  'Media armónica entre precisión y recall. Es especialmente útil cuando las clases están desbalanceadas (valores más altos = mejor desempeño).',
            ),
            _buildExplanationCard(
              icon: Icons.trending_up,
              title: 'AUC-ROC',
              content:
                  'Área bajo la curva ROC. Mide la capacidad del modelo para distinguir entre clases (1 = perfecto, 0.5 = aleatorio).',
            ),
            _buildExplanationCard(
              icon: Icons.pie_chart,
              title: 'Varianza Explicada',
              content:
                  'Porcentaje de varianza en los datos que es capturado por cada componente discriminante. LD1 suele capturar la mayor variación.',
            ),
            _buildExplanationCard(
              icon: Icons.grid_on,
              title: 'Matriz de Confusión',
              content:
                  'Muestra los aciertos (diagonal) y errores de clasificación. TP = Verdaderos Positivos, TN = Verdaderos Negativos, FP = Falsos Positivos, FN = Falsos Negativos.',
            ),
            _buildExplanationCard(
              icon: Icons.scatter_plot,
              title: 'Proyecciones 2D/3D',
              content:
                  'Visualización de cómo el modelo transforma los datos para maximizar la separación entre clases. Cada punto representa una observación.',
            ),
            _buildExplanationCard(
              icon: Icons.show_chart,
              title: 'Scree Plot',
              content:
                  'Muestra la importancia relativa de cada componente discriminante. Ayuda a determinar cuántos componentes retener para el análisis.',
            ),
            const SizedBox(height: 20),
            Text(
              '¿Cómo interpretar LDA?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'LDA busca encontrar combinaciones lineales de variables que maximicen la separación entre clases. Es útil para:',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            _buildBulletPoint('Reducción de dimensionalidad'),
            _buildBulletPoint('Clasificación supervisada'),
            _buildBulletPoint('Visualización de datos multivariados'),
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
