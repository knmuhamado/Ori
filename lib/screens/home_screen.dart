import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'permission_screen.dart';

class CampusGuiaApp extends StatelessWidget {
  const CampusGuiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusGuía',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.3,
          ),
          bodyLarge: TextStyle(
            fontSize: 20,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _mainButtonFocusNode = FocusNode();

  Future<void> _announce(String message) {
    return SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announce(
        'Bienvenido a CampusGuía. '
        'Aplicación de navegación para el campus universitario. '
        'El botón principal Iniciar navegación se encuentra al centro de la pantalla.',
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _mainButtonFocusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _mainButtonFocusNode.dispose();
    super.dispose();
  }

  // ── Navegar a permisos antes de iniciar navegación ──
  void _onStartNavigation() {
    HapticFeedback.heavyImpact();
    _announce('Abriendo pantalla de permisos necesarios.');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PermissionScreen(
          onPermissionsHandled: () {
            // Volver al home y luego ir a navegación
            Navigator.of(context).pop();
            // TODO: Navigator.of(context).pushNamed('/navigation');
            _announce('Permisos procesados. Listo para navegar.');
          },
        ),
      ),
    );
  }

  void _onHelp() {
    HapticFeedback.mediumImpact();
    _announce('Sección de ayuda. Próximamente disponible.');
  }

  void _onSettings() {
    HapticFeedback.mediumImpact();
    _announce('Sección de configuración. Próximamente disponible.');
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  label: 'CampusGuía, aplicación de navegación universitaria',
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.navigation_rounded,
                          size: 64,
                          color: Color(0xFF82B1FF),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'CampusGuía',
                          style: Theme.of(context).textTheme.displaySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label:
                      'Descripción: Aplicación de navegación por voz y audio '
                      'para desplazarte dentro del campus universitario.',
                  child: ExcludeSemantics(
                    child: Text(
                      'Navegación por voz y audio dentro del campus universitario.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const Spacer(),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: Semantics(
                    sortKey: const OrdinalSortKey(1),
                    button: true,
                    label: 'Iniciar navegación. Activa el modo de guía de voz.',
                    hint: 'Toca dos veces para comenzar. Se solicitarán permisos necesarios.',
                    onTap: _onStartNavigation,
                    child: ElevatedButton(
                      focusNode: _mainButtonFocusNode,
                      onPressed: _onStartNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        minimumSize: const Size(double.infinity, 80),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.play_arrow_rounded, size: 32),
                            SizedBox(width: 12),
                            Text('Iniciar navegación'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: Semantics(
                          sortKey: const OrdinalSortKey(2),
                          button: true,
                          label: 'Ayuda',
                          hint: 'Toca dos veces para escuchar instrucciones de uso.',
                          onTap: _onHelp,
                          child: OutlinedButton(
                            onPressed: _onHelp,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              minimumSize: const Size(0, 60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: ExcludeSemantics(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.help_outline_rounded, size: 22),
                                  SizedBox(width: 8),
                                  Text('Ayuda'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(3),
                        child: Semantics(
                          sortKey: const OrdinalSortKey(3),
                          button: true,
                          label: 'Configuración',
                          hint: 'Toca dos veces para ajustar preferencias.',
                          onTap: _onSettings,
                          child: OutlinedButton(
                            onPressed: _onSettings,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              minimumSize: const Size(0, 60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: ExcludeSemantics(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.settings_outlined, size: 22),
                                  SizedBox(width: 8),
                                  Text('Ajustes'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: Text(
                    'Requiere TalkBack activo',
                    style: TextStyle(fontSize: 13, color: Colors.white24),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}