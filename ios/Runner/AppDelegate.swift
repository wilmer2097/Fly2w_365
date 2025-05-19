import UIKit
import Flutter
// Importa servicios adicionales si usas Firebase u otros SDKs nativos.
// import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 🔧 Registra plugins de Flutter automáticamente
    GeneratedPluginRegistrant.register(with: self)

    // ✅ (Opcional) Inicializa Firebase si lo estás usando
    // if FirebaseApp.app() == nil {
    //   FirebaseApp.configure()
    // }

    // 🔁 Si usas notificaciones push o background fetch, puedes configurarlo aquí

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
