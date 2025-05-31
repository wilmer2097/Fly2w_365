import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para cargar assets
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'custom_alert_widget.dart';
import 'form_screen.dart';

// Paleta de colores
const Color blanco = Color(0xFFFFFFFF);
const Color amarilloCrema = Color(0xFFFFE3B3);
const Color amarilloCalido = Color(0xFFFFC973);
const Color azulClaro = Color(0xFF30A0E0);
const Color azulVibrante = Color(0xFF006BB9);
const Color fondoFormulario = Color(0xFFF7F7F7);

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Variables para el logo
  String _logoLink = "";
  String _localLogoVersion = "0"; // Valor local (guardado en 'logo_variable.json')

  @override
  void initState() {
    super.initState();
    _loadLocalLogoVariable().then((localVer) {
      _localLogoVersion = localVer ?? "0";
      _checkAndUpdateLogo();
    });
  }

  // Lee el archivo local "logo_variable.json" para obtener la versión del logo
  Future<String?> _loadLocalLogoVariable() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/logo_variable.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(contents);
        return data["url_logo_version"]?.toString();
      }
    } catch (e) {
      print("Error leyendo variable local del logo: $e");
    }
    return null;
  }

  // Escribe el valor del logo en "logo_variable.json"
  Future<void> _writeLocalLogoVariable(String value) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/logo_variable.json');
      Map<String, dynamic> data = {"url_logo_version": value};
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print("Error escribiendo variable local del logo: $e");
    }
  }

  /// Consulta el endpoint para obtener la variable "url_logo".
  /// Actualiza solo si el valor remoto es mayor que el valor local (comparados como enteros).
  Future<void> _checkAndUpdateLogo() async {
    try {
      final response = await http.get(Uri.parse(
          "https://biblioteca1.info/fly2w/getVariable.php?var_nombre=url_logo"));
      if (response.statusCode == 200) {
        final Map<String, dynamic> remoteData = jsonDecode(response.body);
        String remoteValueStr = remoteData['var_valor'].toString();
        String remoteUrl = remoteData['var_descripcion'].toString();
        print("Valor remoto de url_logo: $remoteValueStr, URL: $remoteUrl");
        int? remoteValue = int.tryParse(remoteValueStr);
        int? localValue = int.tryParse(_localLogoVersion);
        if (remoteValue != null && localValue != null && remoteValue > localValue) {
          setState(() {
            _logoLink = remoteUrl;
            _localLogoVersion = remoteValueStr;
          });
          await _writeLocalLogoVariable(remoteValueStr);
          print("Logo actualizado. Nueva versión local: $_localLogoVersion");
        } else {
          if (_logoLink.isEmpty) {
            setState(() {
              _logoLink = remoteUrl;
            });
          }
          print("Logo está actualizado (versión local: $_localLogoVersion, remoto: $remoteValueStr)");
        }
      } else {
        print("Error consultando url_logo: ${response.statusCode}");
      }
    } catch (e) {
      print("Excepción consultando url_logo: $e");
    }
  }

  /// Lanza la URL del logo usando url_launcher.
  Future<void> _launchLogoUrl() async {
    if (_logoLink.isNotEmpty) {
      final Uri url = Uri.parse(_logoLink);
      print("Intentando lanzar URL: $_logoLink");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
        print("URL lanzada correctamente.");
      } else {
        print("No se pudo abrir la URL: $_logoLink");
      }
    } else {
      print("El valor de _logoLink está vacío.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blanco,
      body: SafeArea(
        child: Column(
          children: [
            // SECCIÓN SUPERIOR: Logo y título (logo clickeable)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _launchLogoUrl,
                    child: Image.asset(
                      'lib/assets/images/logo.png',
                      height: 60,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Vuelos privados al mundo",
                    style: TextStyle(
                      color: azulVibrante,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // SECCIÓN MEDIA: Carrusel de imágenes
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: CarouselImages(),
              ),
            ),
            // SECCIÓN INFERIOR: Botón "solicitar cotización"
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulVibrante,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 32.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/form');
                },
                child: Text(
                  'solicitar cotización',
                  style: TextStyle(
                    color: blanco,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modelo para cada imagen obtenida de la vista vw_vector_img
class CarouselImageFromView {
  final String id;
  final String? promo;

  CarouselImageFromView({required this.id, this.promo});

  factory CarouselImageFromView.fromJson(Map<String, dynamic> json) {
    return CarouselImageFromView(
      id: json['id'].toString(),
      promo: json['promo'], // Será null si no hay promoción
    );
  }
}

// Widget del Carrusel que consume el API getVectorImg.php y maneja cacheo
class CarouselImages extends StatefulWidget {
  @override
  _CarouselImagesState createState() => _CarouselImagesState();
}

class _CarouselImagesState extends State<CarouselImages> {
  List<CarouselImageFromView> images = [];
  int currentIndex = 0;
  late PageController _pageController;
  Timer? _timer;
  final double imageHeight = 300;

  // Variable local para Img_cambio y lista de nombres de archivo predeterminados
  String _localImgCambio = "0";
  final List<String> defaultFilenames = [
    'destino1.jpg',
    'destino2.jpg',
    'destino3.jpg',
    'destino4.jpg',
    'destino5.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: currentIndex);
    // Primero, leemos el valor local de Img_cambio y luego verificamos si hay cambios.
    _readLocalImgCambio().then((localVal) {
      _localImgCambio = localVal ?? "0";
      _checkAndUpdateVariable();
    });
    _timer = Timer.periodic(Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients && images.isNotEmpty) {
        currentIndex = (currentIndex + 1) % images.length;
        _pageController.animateToPage(
          currentIndex,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<String?> _readLocalImgCambio() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/variables.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(contents);
        return data["Img_cambio"]?.toString();
      }
    } catch (e) {
      print("Error leyendo variable local Img_cambio: $e");
    }
    return null;
  }

  Future<void> _writeLocalImgCambio(String value) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/variables.json');
      Map<String, dynamic> data = {"Img_cambio": value};
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print("Error escribiendo variable local Img_cambio: $e");
    }
  }

  Future<void> _checkAndUpdateVariable() async {
    try {
      final response = await http.get(Uri.parse("https://biblioteca1.info/fly2w/getVariable.php?var_nombre=Img_cambio"));
      if (response.statusCode == 200) {
        final Map<String, dynamic> remoteData = jsonDecode(response.body);
        String remoteValueStr = remoteData['var_valor'].toString();
        int? remoteValue = int.tryParse(remoteValueStr);
        int? localValue = int.tryParse(_localImgCambio);
        if (remoteValue != null && localValue != null && remoteValue > localValue) {
          // Si hay cambio, evictamos la cache de cada imagen usando la lista predeterminada.
          for (String fname in defaultFilenames) {
            String url = "https://fly2w.biblioteca1.info/images/$fname";
            await CachedNetworkImage.evictFromCache(url);
            print("Cache evicted for $fname");
          }
          setState(() {
            _localImgCambio = remoteValueStr;
          });
          await _writeLocalImgCambio(remoteValueStr);
        }
      } else {
        print("Error consultando Img_cambio: ${response.statusCode}");
      }
    } catch (e) {
      print("Excepción consultando Img_cambio: $e");
    } finally {
      // Luego de verificar (y evictar si es necesario) se cargan las imágenes.
      _fetchVectorImages();
    }
  }

  Future<void> _fetchVectorImages() async {
    try {
      final response = await http.get(
        Uri.parse("https://biblioteca1.info/fly2w/getVectorImg.php"),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          images = data
              .map((json) => CarouselImageFromView.fromJson(json))
              .toList();
        });
      } else {
        print("Error al obtener imágenes: ${response.statusCode}");
      }
    } catch (e) {
      print("Excepción al obtener imágenes: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return images.isEmpty
        ? Center(child: CircularProgressIndicator())
        : Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final imageData = images[index];
              // Asumimos que las imágenes se llaman "destino{id}.jpg"
              final imageUrl =
                  "https://fly2w.biblioteca1.info/images/destino${imageData.id}.jpg";
              return GestureDetector(
                onTap: () {
                  // Al pulsar la imagen, se navega al formulario y se pasa el código de promoción (si existe)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormScreen(
                        promoCode: imageData.promo,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: imageHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      imageBuilder: (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      placeholder: (context, url) => Container(
                        height: imageHeight,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: imageHeight,
                        child: Center(child: Text('Error al cargar la imagen')),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (index) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentIndex == index ? azulVibrante : amarilloCalido,
              ),
            );
          }),
        ),
      ],
    );
  }
}
