import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fly2w_365/resources/funciones.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:path_provider/path_provider.dart';
import 'custom_alert_widget.dart';

// Paleta de colores
const Color blanco = Color(0xFFFFFFFF);
const Color amarilloCrema = Color(0xFFFFE3B3);
const Color amarilloCalido = Color(0xFFFFC973);
const Color azulClaro = Color(0xFF30A0E0);
const Color azulVibrante = Color(0xFF006BB9);
const Color fondoFormulario = Color(0xFFF7F7F7);

class FormScreen extends StatefulWidget {
  final String? promoCode;

  const FormScreen({super.key, this.promoCode});

  @override
  State<FormScreen> createState() => _FormScreenState();
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

  // Número de teléfono
  String completePhoneNumber = '';

  // Variables para fechas
  DateTime? fechaPartida;
  DateTime? fechaRetorno;
  bool fechasFijas = false;
  bool soloPartida = false;
  // Código del país, por defecto 'PE'
  String _initialCountryCode = 'PE';

  // Dropdown: Número de pasajeros (1 a 10 y "Más de 10")
  int _selectedPasajeros = 1;

  // Lista de ubicaciones (destinos) que se usarán en el Autocomplete
  List<String> locations = [];

  // Variable local para la versión de destinos (destino_cambio)
  String _localDestinoVersion = "0";

  @override
  void initState() {
    super.initState();

    if (widget.promoCode != null) {
      codigoPromoController.text = widget.promoCode!;
    }
    _loadLocalDestinoVersion().then((localVer) {
      _localDestinoVersion = localVer ?? "0";
      _loadLocationsFromAPI();
    });
    _obtenerCodigoPais();
  }

  /// Lee el archivo local "destino_variable.json" para obtener la versión local de destino_cambio
  Future<String?> _loadLocalDestinoVersion() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/destino_variable.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(contents);
        return data["destino_cambio"]?.toString();
      }
    } catch (e) {
      print("Error leyendo la versión local de destinos: $e");
    }
    return null;
  }

  /// Guarda la versión de destino_cambio en el archivo local "destino_variable.json"
  Future<void> _writeLocalDestinoVersion(String value) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/destino_variable.json');
      Map<String, dynamic> data = {"destino_cambio": value};
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print("Error escribiendo la versión local de destinos: $e");
    }
  }

  /// Consulta la API para obtener la variable "destino_cambio" y la lista de destinos (filtrando bestado = 1)
  Future<void> _loadLocationsFromAPI() async {
    final String apiUrl = "https://biblioteca1.info/fly2w/getDestinos.php";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Se espera que la API devuelva "destino_cambio" y "destinos"
        String remoteVersionStr = data["destino_cambio"].toString();
        int? remoteVersion = int.tryParse(remoteVersionStr);
        int? localVersion = int.tryParse(_localDestinoVersion);

        // Si la versión remota es mayor, se actualiza la lista y se guarda la nueva versión local.
        if (remoteVersion != null &&
            localVersion != null &&
            remoteVersion > localVersion) {
          List<dynamic> destinos = data["destinos"];
          setState(() {
            locations = destinos
                .map((destino) => destino["agrupado"] as String)
                .toList();
          });
          await _writeLocalDestinoVersion(remoteVersionStr);
          print("Destinos actualizados. Nueva versión: $remoteVersionStr");
        } else {
          // Aunque no haya cambio en la versión, se actualiza la lista para la primera carga
          List<dynamic> destinos = data["destinos"];
          setState(() {
            locations = destinos
                .map((destino) => destino["agrupado"] as String)
                .toList();
          });
          print("Destinos cargados. Versión local: $_localDestinoVersion, remoto: $remoteVersionStr");
        }
      } else {
        print("Error al consultar la API de destinos: ${response.statusCode}");
      }
    } catch (e) {
      print("Excepción al cargar destinos desde la API: $e");
    }
  }

  Future<void> _obtenerCodigoPais() async {
    setState(() {
      _initialCountryCode = datosPaisActual()["codigoPais"];
    });
    // try {
    //   // Verifica y solicita permisos si es necesario
    //   LocationPermission permission = await Geolocator.checkPermission();
    //   if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    //     permission = await Geolocator.requestPermission();
    //   }
    //
    //   // Obtén la ubicación actual del usuario
    //   Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    //
    //   // Realiza la geocodificación inversa para obtener datos de la ubicación
    //   List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    //   if (placemarks.isNotEmpty) {
    //     setState(() {
    //       _initialCountryCode = placemarks.first.isoCountryCode ?? 'PE';
    //     });
    //   }
    // } catch (e) {
    //   print("Error al obtener el código de país: $e");
    // }
  }

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

  Future<void> _selectFechaRetorno(BuildContext context) async {
    if (soloPartida) return;
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

  InputDecoration _buildInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: azulVibrante),
      filled: true,
      fillColor: blanco,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: azulClaro, width: 2),
      ),
    );
  }

  /// Widget para el selector de fechas con icono de calendario.
  Widget _buildDateSelector(String label, DateTime? selectedDate, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: azulVibrante),
                  SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: azulVibrante),
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
                  fontWeight: FontWeight.bold,
                  color: enabled ? (selectedDate != null ? azulVibrante : Colors.grey) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dropdown para seleccionar el número de pasajeros.
  Widget _buildPassengerDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedPasajeros,
      decoration: _buildInputDecoration("Número de Pasajeros"),
      items: List.generate(11, (index) {
        int value = index + 1;
        return DropdownMenuItem<int>(
          value: value,
          child: Text(value == 11 ? "Más de 10" : value.toString()),
        );
      }),
      onChanged: (int? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedPasajeros = newValue;
          });
        }
      },
      validator: (value) {
        if (value == null) return "Seleccione el número de pasajeros";
        return null;
      },
    );
  }

  Future<void> _sendReserva() async {
    const String apiUrl = "https://biblioteca1.info/fly2w/insertReserva.php";
    Map<String, dynamic> requestData = {
      "codigoPromo": codigoPromoController.text,
      "origen": origenController.text,
      "destino": destinoController.text,
      "fechaPartida": fechaPartida != null ? fechaPartida!.toIso8601String().split("T").first : "",
      "fechaRetorno": soloPartida ? "" : (fechaRetorno != null ? fechaRetorno!.toIso8601String().split("T").first : ""),
      "solo_partida": soloPartida,
      "fechasFijas": fechasFijas,
      "condiciones": condicionesController.text,
      "nombre": nombreController.text,
      "telefono": completePhoneNumber,
      "correo": correoController.text,
      "pasajeros": _selectedPasajeros,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );
      if (response.statusCode == 201) {
        var responseData = jsonDecode(response.body);
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
      backgroundColor: blanco,
      appBar: AppBar(
        backgroundColor: blanco,
        elevation: 0,
        forceMaterialTransparency: true,
        iconTheme: IconThemeData(color: azulVibrante),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: fondoFormulario,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Código de Promoción (opcional, autocompletado si se pasa promoCode)
                    TextFormField(
                      controller: codigoPromoController,
                      decoration: _buildInputDecoration("Código de Promoción (Opcional)", hint: "Ej. A0123 o PE000"),
                    ),
                    SizedBox(height: 16),
                    // Origen (Autocomplete con datos provenientes de la API)
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty)
                          return const Iterable<String>.empty();
                        return locations.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        origenController.text = selection;
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: _buildInputDecoration("Lugar de partida"),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return "Seleccione un origen";
                            return null;
                          },
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    // Destino (Autocomplete)
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty)
                          return const Iterable<String>.empty();
                        return locations.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        destinoController.text = selection;
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: _buildInputDecoration("Lugar de destino"),
                          validator: (value) {
                            if (!soloPartida && (value == null || value.isEmpty))
                              return "Seleccione un destino";
                            return null;
                          },
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    // Fila de selectores de Fecha de Partida y Retorno
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateSelector("Fecha de partida", fechaPartida, true, () => _selectFechaPartida(context)),

                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildDateSelector("Fecha de retorno", fechaRetorno, !soloPartida, () => _selectFechaRetorno(context)),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Checkbox: Solo Partida
                    Row(
                      children: [
                        Checkbox(
                          value: soloPartida,
                          activeColor: azulClaro,
                          onChanged: (value) {
                            setState(() {
                              soloPartida = value ?? false;
                              if (soloPartida) fechaRetorno = null;
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
                    // Checkbox: Fechas Fijas
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
                    // Dropdown: Número de Pasajeros
                    _buildPassengerDropdown(),
                    SizedBox(height: 16),
                    // Nombre y Apellido
                    TextFormField(
                      controller: nombreController,
                      decoration: _buildInputDecoration("Nombre y Apellido de Contacto"),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return "Este campo es obligatorio";
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Teléfono (intl_phone_field)
                    IntlPhoneField(
                      decoration: _buildInputDecoration("Teléfono"),
                      initialCountryCode: _initialCountryCode,
                      searchText: "Buscar país",
                      onChanged: (phone) {
                        completePhoneNumber = phone.completeNumber;
                      },
                      validator: (phone) {
                        if (phone == null || phone.number.isEmpty)
                          return "Ingrese su número de teléfono";
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
                        if (value == null || value.isEmpty)
                          return "Este campo es obligatorio";
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                          return "Ingrese un correo válido";
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    // Condiciones especiales
                    TextFormField(
                      controller: condicionesController,
                      decoration: _buildInputDecoration("Condiciones especiales"),
                      maxLines: 3,
                    ),
                    SizedBox(height: 20),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      ),
    );
  }
}
