import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'play.dart';
import 'statistics.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final PageController _pageController;
  int _currentPage = 1;

  final List<Map<String, String>> options = [
    {
      'title': 'resume',
      'subtitle': 'continue where you left off',
      'icon': 'assets/icons/resume.svg',
    },
    {
      'title': 'start',
      'subtitle': 'a new challenge awaits',
      'icon': 'assets/icons/cards.svg',
    },
    {
      'title': 'statistics',
      'subtitle': 'check your progress',
      'icon': 'assets/icons/stats1.svg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.9,
      initialPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'solace',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'CabinetGrotesk',
                            fontSize: 72,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                        Text(
                          ' welcome back',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'CabinetGrotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w100,
                            height: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 80.0),
                        child: SizedBox(
                          height: 200,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: options.length,
                            onPageChanged: (page) {
                              setState(() {
                                _currentPage = page;
                              });
                            },
                            itemBuilder: (context, index) {
                              final option = options[index];
                              final isSelected = index == _currentPage;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                child: GestureDetector(
                                  onTap: () async {
                                    switch (option['title']) {
                                      case 'resume':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const PlayPage()),
                                        );
                                        break;
                                      case 'start':
                                        final prefs = await SharedPreferences.getInstance();
                                        await prefs.remove('solace_game_state');
                                        await prefs.remove('solace_move_count');
                                        await prefs.remove('solace_elapsed_time');
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const PlayPage()),
                                        );
                                        break;
                                      case 'statistics':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const StatisticsPage()),
                                        );
                                        break;
                                    }
                                  },
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                    opacity: isSelected ? 1.0 : 0.6,
                                    child: Container(
                                      width: screenWidth * 0.9,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: const LinearGradient(
                                          colors: [Colors.purpleAccent, Colors.pinkAccent],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.pinkAccent.withOpacity(0.6),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 6),
                                                )
                                              ]
                                            : null,
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SvgPicture.asset(
                                            option['icon']!,
                                            colorFilter: const ColorFilter.matrix([
                                              -1, 0, 0, 0, 255,
                                              0, -1, 0, 0, 255,
                                              0, 0, -1, 0, 255,
                                              0, 0, 0, 1, 0,
                                            ]),
                                            width: 42,
                                            height: 42,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            option['title']!,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              shadows: isSelected
                                                  ? [const Shadow(blurRadius: 5, color: Colors.white, offset: Offset(0, 0))]
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            option['subtitle']!,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/star.svg',
                            width: 18,
                            height: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'high score: 12345',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(width: 5),
                          SvgPicture.asset(
                            'assets/icons/star.svg',
                            width: 18,
                            height: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Center(
                  child: Text(
                    'by will murphy',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
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