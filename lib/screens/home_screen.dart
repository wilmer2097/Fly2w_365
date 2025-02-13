import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Definición global de la paleta de colores
const Color blanco = Color(0xFFFFFFFF);
const Color amarilloCrema = Color(0xFFFFE3B3);
const Color amarilloCalido = Color(0xFFFFC973);
const Color azulClaro = Color(0xFF30A0E0);
const Color azulVibrante = Color(0xFF006BB9);

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blanco, // Fondo blanco
      body: SafeArea(
        child: Column(
          children: [
            // SECCIÓN SUPERIOR: Logo y título
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Image.asset(
                    'lib/assets/images/logo.png',
                    height: 60,
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
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
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

/// Clase para mapear la información de cada imagen (de la tabla ImagenesMenu)
class ImagenMenu {
  final String filename;
  final int updatedAt;
  final bool flagActualizar;

  ImagenMenu({
    required this.filename,
    required this.updatedAt,
    required this.flagActualizar,
  });

  factory ImagenMenu.fromJson(Map<String, dynamic> json) {
    return ImagenMenu(
      filename: json['filename'],
      updatedAt: int.parse(json['updated_at'].toString()),
      flagActualizar: json['flag_actualizar'].toString() == "1",
    );
  }
}

class CarouselImages extends StatefulWidget {
  @override
  _CarouselImagesState createState() => _CarouselImagesState();
}

class _CarouselImagesState extends State<CarouselImages> {
  // Lista base de nombres de archivos (se asume que la tabla ImagenesMenu tiene estos registros)
  final List<String> filenames = [
    'destino1.jpg',
    'destino2.jpg',
    'destino3.jpg',
    'destino4.jpg',
    'destino5.jpg',
  ];

  // Lista de objetos ImagenMenu obtenidos desde el endpoint
  List<ImagenMenu> imagenes = [];
  // Lista final de URLs a mostrar
  List<String> displayUrls = [];

  int currentIndex = 0;
  late PageController _pageController;
  Timer? _timer;
  final double imageHeight = 300; // Altura fija

  // Valor local de la variable Img_cambio, se guardará en un JSON local
  String _localImgCambio = "0";

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: currentIndex);
    // Primero, cargar el valor local desde el archivo y luego proceder a actualizarlo si es necesario.
    _readLocalVariable().then((localVal) {
      _localImgCambio = localVal ?? "0";
      // Consulta la variable remota y actualiza si es necesario.
      _checkAndUpdateVariable().then((_) {
        // Una vez que se tenga el valor correcto, carga la lista de imágenes.
        _loadImagenes();
      });
    });
    _timer = Timer.periodic(Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients && displayUrls.isNotEmpty) {
        currentIndex = (currentIndex + 1) % displayUrls.length;
        _pageController.animateToPage(
          currentIndex,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Obtiene el directorio local y lee el archivo variables.json para obtener Img_cambio.
  Future<String?> _readLocalVariable() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/variables.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(contents);
        return data["Img_cambio"]?.toString();
      }
    } catch (e) {
      print("Error leyendo variable local: $e");
    }
    return null;
  }

  /// Escribe el valor de Img_cambio en el archivo variables.json
  Future<void> _writeLocalVariable(String value) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/variables.json');
      Map<String, dynamic> data = {"Img_cambio": value};
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print("Error escribiendo variable local: $e");
    }
  }

  /// Consulta el endpoint para obtener Img_cambio y actualiza la caché si es necesario.
  Future<void> _checkAndUpdateVariable() async {
    try {
      final response = await http.get(Uri.parse(
          "https://biblioteca1.info/fly2w/getVariable.php?var_nombre=Img_cambio"));
      if (response.statusCode == 200) {
        final Map<String, dynamic> remoteData = jsonDecode(response.body);
        String remoteValue = remoteData['var_valor'].toString();
        print("Valor remoto de Img_cambio: $remoteValue");
        if (remoteValue != _localImgCambio) {
          // Si los valores difieren, evicta la caché de todas las imágenes.
          for (String fname in filenames) {
            String url = "https://biblioteca1.info/fly2w/images/$fname";
            await CachedNetworkImage.evictFromCache(url);
            print("Cache evicted for $fname");
          }
          // Actualiza el valor local y escribe en el archivo.
          setState(() {
            _localImgCambio = remoteValue;
          });
          await _writeLocalVariable(remoteValue);
          print("Variable local actualizada: $_localImgCambio");
        } else {
          print("Las imágenes están actualizadas (Img_cambio: $_localImgCambio)");
        }
      } else {
        print("Error consultando Img_cambio: ${response.statusCode}");
      }
    } catch (e) {
      print("Excepción consultando Img_cambio: $e");
    }
  }

  /// Carga la lista de imágenes desde el endpoint getImagenesMenu.php
  Future<void> _loadImagenes() async {
    try {
      final response = await http.get(Uri.parse("https://biblioteca1.info/fly2w/getImagenesMenu.php"));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        List<ImagenMenu> temp = data.map((json) => ImagenMenu.fromJson(json)).toList();
        setState(() {
          imagenes = temp;
          _buildDisplayUrls();
        });
      } else {
        print("Error al cargar imágenes, status: ${response.statusCode}");
      }
    } catch (e) {
      print("Excepción al cargar imágenes: $e");
    }
  }

  /// Construye la lista de URLs a mostrar a partir de la lista de imágenes.
  void _buildDisplayUrls() {
    setState(() {
      displayUrls = imagenes.map((img) {
        // Aquí podrías agregar un parámetro de versión si lo deseas
        return "https://biblioteca1.info/fly2w/images/${img.filename}";
      }).toList();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si displayUrls está vacío, usa un fallback basado en filenames.
    final List<String> urls = displayUrls.isNotEmpty
        ? displayUrls
        : filenames.map((fname) => "https://biblioteca1.info/fly2w/images/$fname").toList();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  height: imageHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: urls[index],
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
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: urls.map((url) {
            int index = urls.indexOf(url);
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentIndex == index ? azulVibrante : amarilloCalido,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
