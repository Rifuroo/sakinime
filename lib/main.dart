import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

// Windows-specific imports
import 'package:window_manager/window_manager.dart'
    if (dart.library.io) 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:smtc_windows/smtc_windows.dart';

import 'providers/anime_provider.dart';
import 'providers/player_provider.dart';
import 'providers/global_player_provider.dart';
import 'providers/source_provider.dart';
import 'services/download_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/all_anime_screen.dart';
import 'screens/browse_screen.dart';
import 'screens/search_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/player_screen.dart';
import 'utils/platform_utils.dart';
import 'widgets/app_drawer.dart';
import 'widgets/mini_player_widget.dart';
import 'widgets/windows_title_bar.dart';
import 'utils/navigator_key.dart';

void main() async {
  // ✅ Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize MediaKit for video playback
  MediaKit.ensureInitialized();

  // ✅ Initialize window manager for Windows
  if (PlatformUtils.isWindows) {
    // Initialize SMTC for Windows media controls
    await SMTCWindows
        .initialize(); // Can throw on restart if not cleaned up, but no easy fix

    // Initialize window manager for frameless window
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // Hide native title bar
      title: 'Sukinime',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // ✅ Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ✅ Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class AppInitializer extends StatefulWidget {
  final Widget child;
  const AppInitializer({Key? key, required this.child}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<AnimeProvider>(context, listen: false).loadThemeColor();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SourceProvider()),
        ChangeNotifierProxyProvider<SourceProvider, AnimeProvider>(
          create: (_) => AnimeProvider(),
          update: (_, source, anime) => anime!..update(source),
        ),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(
            create: (_) => GlobalPlayerProvider()), // New Global Player
        ChangeNotifierProvider(create: (_) => DownloadService()),
      ],
      child: AppInitializer(
        child: Consumer<AnimeProvider>(
          builder: (context, provider, child) {
            return MaterialApp(
              navigatorKey: navigatorKey, // ✅ Added Global Key
              title: 'Sukinime',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF0a0e27),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1a1f3a),
                  elevation: 0,
                ),
                textTheme: GoogleFonts.poppinsTextTheme(
                  Theme.of(context).textTheme.apply(
                        bodyColor: Colors.white,
                        displayColor: Colors.white,
                      ),
                ),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: provider.primaryColor,
                  brightness: Brightness.dark,
                  surface: const Color(0xFF0a0e27),
                ),
              ),
              home: const SplashScreen(),
              builder: (context, child) {
                return Stack(
                  children: [
                    if (child != null) child,
                    const MiniPlayerWidget(),
                  ],
                );
              },
              routes: {
                '/home': (context) => const MainNavigation(),
                '/player': (context) => const PlayerScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    AllAnimeScreen(),
    BrowseScreen(),
    SearchScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      _animationController.reset();
      setState(() {
        _selectedIndex = index;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive Layout Decision
    final isDesktop = PlatformUtils.isDesktop;

    return Scaffold(
      extendBody: true,
      drawer: !isDesktop
          ? const AppDrawer()
          : null, // Drawer only on mobile usually
      body: Column(
        children: [
          if (isDesktop) const WindowsTitleBar(),
          Expanded(
            child: Row(
              children: [
                // Sidebar for Desktop
                if (isDesktop) _buildDesktopSidebar(),

                // Main Content
                Expanded(
                  child: Stack(
                    children: [
                      // Animated gradient background
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0a0e27),
                              _selectedIndex == 0
                                  ? const Color(0xFF1a1f3a)
                                  : _selectedIndex == 1
                                      ? const Color(0xFF1a1535)
                                      : const Color(0xFF1a152e),
                            ],
                          ),
                        ),
                      ),
                      // Screen content with fade and slide animation
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _screens[_selectedIndex],
                        ),
                      ),

                      // Mini Player Overlay
                      // const MiniPlayerWidget(), // Moved to MaterialApp builder
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop ? _buildLiquidGlassNavBar() : null,
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Provider.of<AnimeProvider>(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Text(
                  'Sukinime',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Navigation
                  _buildSidebarItem(Icons.home_rounded, 'Home', 0),
                  _buildSidebarItem(
                      Icons.video_library_rounded, 'Semua Anime', 1),
                  _buildSidebarItem(Icons.explore_rounded, 'Browse', 2),
                  _buildSidebarItem(Icons.search_rounded, 'Search', 3),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Divider(color: Colors.white10),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Text(
                      'CATEGORIES',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  _buildSidebarActionItem(
                      Icons.whatshot_rounded,
                      'Most Popular',
                      () => _navigateToBrowseCategory('most-popular')),
                  _buildSidebarActionItem(
                      Icons.favorite_rounded,
                      'Most Favorite',
                      () => _navigateToBrowseCategory('most-favorite')),
                  _buildSidebarActionItem(Icons.movie_rounded, 'Movies',
                      () => _navigateToBrowseCategory('movie')),
                  _buildSidebarActionItem(Icons.tv_rounded, 'TV Series',
                      () => _navigateToBrowseCategory('tv')),
                  _buildSidebarActionItem(Icons.album_rounded, 'OVAs',
                      () => _navigateToBrowseCategory('ova')),
                  _buildSidebarActionItem(Icons.public_rounded, 'ONAs',
                      () => _navigateToBrowseCategory('ona')),
                  _buildSidebarActionItem(Icons.star_rounded, 'Specials',
                      () => _navigateToBrowseCategory('special')),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Divider(color: Colors.white10),
                  ),

                  _buildSidebarActionItem(Icons.calendar_month_rounded,
                      'Schedule', _navigateToSchedule,
                      color: Provider.of<AnimeProvider>(context).primaryColor),
                ],
              ),
            ),
          ),

          // Version Info
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'v1.0.0 Windows',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToBrowseCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrowseScreen(initialCategory: category),
      ),
    );
  }

  void _navigateToSchedule() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ScheduleScreen()));
  }

  Widget _buildSidebarActionItem(
      IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.05),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color ?? Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.grey[300],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Provider.of<AnimeProvider>(context).primaryColor;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: primaryColor.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidGlassNavBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Provider.of<AnimeProvider>(context)
                .primaryColor
                .withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                _buildNavItem(
                    Icons.home_outlined, Icons.home_filled, 'Home', 0),
                _buildNavItem(Icons.video_library_outlined, Icons.video_library,
                    'Semua', 1),
                _buildNavItem(
                    Icons.explore_outlined, Icons.explore, 'Browse', 2),
                _buildNavItem(Icons.search_outlined, Icons.search, 'Search', 3),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.grey[500],
              showUnselectedLabels: true,
              selectedLabelStyle: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Provider.of<AnimeProvider>(context).primaryColor;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: 24,
        ),
      ),
      activeIcon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withValues(alpha: 0.4),
              primaryColor.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          activeIcon,
          size: 24,
        ),
      ),
      label: label,
    );
  }
}
