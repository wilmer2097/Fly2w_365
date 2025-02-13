import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para cargar el JSON desde assets
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:http/http.dart' as http;
import 'custom_alert_widget.dart'; // Asegúrate de que la ruta sea correcta

// Definición global de la paleta de colores
const Color blanco = Color(0xFFFFFFFF);
const Color amarilloCrema = Color(0xFFFFE3B3);
const Color amarilloCalido = Color(0xFFFFC973);
const Color azulClaro = Color(0xFF30A0E0);
const Color azulVibrante = Color(0xFF006BB9);
// Color para el fondo del formulario (Card)
const Color fondoFormulario = Color(0xFFF7F7F7);

class FormScreen extends StatefulWidget {
  @override
  _FormScreenState createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final TextEditingController codigoPromoController = TextEditingController();
  final TextEditingController origenController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();
  final TextEditingController condicionesController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController correoController = TextEditingController();

  // Variable para almacenar el número de teléfono completo
  String completePhoneNumber = '';

  // Variables para fechas
  DateTime? fechaPartida;
  DateTime? fechaRetorno;
  bool fechasFijas = false;

  // Variable para el checkbox "solo_partida"
  bool soloPartida = false;

  // Lista de ubicaciones cargada desde el JSON
  List<String> locations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  // Función asíncrona para cargar el JSON de ubicaciones
  Future<void> _loadLocations() async {
    try {
      final String jsonString =
      await rootBundle.loadString('lib/assets/datosJson/destinos.json');
      final List<dynamic> jsonResponse = json.decode(jsonString);
      setState(() {
        // Extrae el campo "agrupado" de cada objeto
        locations = jsonResponse
            .map((item) => item['agrupado'] as String)
            .toList();
      });
    } catch (e) {
      print("Error al cargar ubicaciones: $e");
      // Puedes definir un fallback o dejar la lista vacía.
    }
  }

  // Función para seleccionar la fecha de partida
  Future<void> _selectFechaPartida(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaPartida ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != fechaPartida) {
      setState(() {
        fechaPartida = picked;
      });
    }
  }

  // Función para seleccionar la fecha de retorno (deshabilitada si soloPartida es true)
  Future<void> _selectFechaRetorno(BuildContext context) async {
    if (soloPartida) return; // Si se marca soloPartida, no se permite seleccionar
    final DateTime initial = (fechaPartida != null)
        ? fechaPartida!.add(Duration(days: 1))
        : DateTime.now().add(Duration(days: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaRetorno ?? initial,
      firstDate: fechaPartida ?? DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != fechaRetorno) {
      setState(() {
        fechaRetorno = picked;
      });
    }
  }

  @override
  void dispose() {
    codigoPromoController.dispose();
    origenController.dispose();
    destinoController.dispose();
    condicionesController.dispose();
    nombreController.dispose();
    correoController.dispose();
    super.dispose();
  }

  // Función auxiliar para unificar el estilo de los InputDecoration
  InputDecoration _buildInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: azulVibrante),
      filled: true,
      fillColor: blanco,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: azulClaro, width: 2),
      ),
    );
  }

  /// Función personalizada para el selector de fechas.
  /// Muestra un icono de calendario, un label, y debajo la fecha seleccionada (o mensaje)
  Widget _buildDateSelector(String label, DateTime? selectedDate, bool enabled, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, color: azulVibrante),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: azulVibrante),
            ),
            Spacer(),
            if (enabled)
              TextButton(
                onPressed: onTap,
                child: Text("Seleccionar", style: TextStyle(color: azulClaro)),
              ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          enabled
              ? (selectedDate != null ? "${selectedDate.toLocal()}".split(' ')[0] : "No seleccionada")
              : "No aplica",
          style: TextStyle(
            fontSize: 16,
            color: enabled
                ? (selectedDate != null ? azulVibrante : Colors.grey)
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  // Función para enviar la reserva a la API
  Future<void> _sendReserva() async {
    // URL de la API
    const String apiUrl = "https://biblioteca1.info/fly2w/insertReserva.php";

    // Construir el objeto JSON con los datos del formulario
    Map<String, dynamic> requestData = {
      "codigoPromo": codigoPromoController.text,
      "origen": origenController.text,
      "destino": destinoController.text,
      "fechaPartida": fechaPartida != null
          ? fechaPartida!.toIso8601String().split("T").first
          : "",
      "fechaRetorno": soloPartida ? "" : (fechaRetorno != null
          ? fechaRetorno!.toIso8601String().split("T").first
          : ""),
      "solo_partida": soloPartida,
      "fechasFijas": fechasFijas,
      "condiciones": condicionesController.text,
      "nombre": nombreController.text,
      "telefono": completePhoneNumber,
      "correo": correoController.text,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 201) {
        var responseData = jsonDecode(response.body);
        // Mostrar alerta de éxito personalizada
        await showDialog(
          context: context,
          builder: (context) => CustomAlertWidget(
            mensaje: responseData["mensaje"] ?? "Reserva exitosa",
            esExito: true,
          ),
        );
        Navigator.pop(context);
      } else {
        var responseData = jsonDecode(response.body);
        // Mostrar alerta de error personalizada
        await showDialog(
          context: context,
          builder: (context) => CustomAlertWidget(
            mensaje: responseData["error"] ?? "Error al insertar reserva",
            esExito: false,
          ),
        );
      }
    } catch (e) {
      await showDialog(
        context: context,
        builder: (context) => CustomAlertWidget(
          mensaje: "Error: $e",
          esExito: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blanco, // Fondo blanco en toda la vista
      appBar: AppBar(
        backgroundColor: blanco,
        elevation: 0,
        iconTheme: IconThemeData(color: azulVibrante),
        title: Row(
          children: [
            Image.asset(
              'lib/assets/images/logo.png',
              height: 40,
            ),
            SizedBox(width: 8),
            Text(
              "Formulario de Reserva",
              style: TextStyle(
                color: azulVibrante,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: fondoFormulario, // Color de fondo suave para el formulario
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Código de Promoción (opcional)
                  TextFormField(
                    controller: codigoPromoController,
                    decoration: _buildInputDecoration(
                      "Código de Promoción",
                      hint: "Ej. A0123 o PE000",
                    ),
                  ),
                  SizedBox(height: 16),
                  // Origen utilizando Autocomplete (datos cargados del JSON)
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return locations.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      origenController.text = selection;
                    },
                    fieldViewBuilder:
                        (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration("Origen"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Seleccione un origen";
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  // Destino utilizando Autocomplete (datos cargados del JSON)
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return locations.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      destinoController.text = selection;
                    },
                    fieldViewBuilder:
                        (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration("Destino"),
                        validator: (value) {
                          // Si soloPartida es true, no se valida el destino.
                          if (!soloPartida && (value == null || value.isEmpty)) {
                            return "Seleccione un destino";
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  // Selector de Fecha de Partida con icono de calendario
                  _buildDateSelector("Fecha de Partida", fechaPartida, true, () => _selectFechaPartida(context)),
                  SizedBox(height: 16),
                  // Selector de Fecha de Retorno (deshabilitado si soloPartida es true)
                  _buildDateSelector("Fecha de Retorno", fechaRetorno, !soloPartida, () => _selectFechaRetorno(context)),
                  SizedBox(height: 16),
                  // Checkbox para Solo Partida
                  Row(
                    children: [
                      Checkbox(
                        value: soloPartida,
                        activeColor: azulClaro,
                        onChanged: (value) {
                          setState(() {
                            soloPartida = value ?? false;
                            if (soloPartida) {
                              fechaRetorno = null;
                            }
                          });
                        },
                      ),
                      Text(
                        "Solo Partida (sin fecha de retorno)",
                        style: TextStyle(color: azulVibrante),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Checkbox para Fechas Fijas
                  Row(
                    children: [
                      Checkbox(
                        value: fechasFijas,
                        activeColor: azulClaro,
                        onChanged: (value) {
                          setState(() {
                            fechasFijas = value ?? false;
                          });
                        },
                      ),
                      Text(
                        "Fechas Fijas",
                        style: TextStyle(color: azulVibrante),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Nombre y Apellido
                  TextFormField(
                    controller: nombreController,
                    decoration: _buildInputDecoration("Nombre y Apellido"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Este campo es obligatorio";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  // Campo de Teléfono con intl_phone_field (selector de país integrado)
                  IntlPhoneField(
                    decoration: _buildInputDecoration("Teléfono"),
                    initialCountryCode: 'MX',
                    onChanged: (phone) {
                      completePhoneNumber = phone.completeNumber;
                    },
                    validator: (phone) {
                      if (phone == null || phone.number.isEmpty) {
                        return "Ingrese su número de teléfono";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  // Correo
                  TextFormField(
                    controller: correoController,
                    decoration: _buildInputDecoration("Correo"),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Este campo es obligatorio";
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return "Ingrese un correo válido";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  // Condiciones Especiales
                  TextFormField(
                    controller: condicionesController,
                    decoration: _buildInputDecoration("Condiciones especiales, número de personas, otros"),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  // Botón de Envío
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          await _sendReserva();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulVibrante,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Solicitar cotización", style: TextStyle(color: blanco)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
