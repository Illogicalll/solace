import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'game_detail_view.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int gamesWon = 0;
  int gamesLost = 0;
  bool isLoading = true;
  List<Map<String, dynamic>> recentGames = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final won = prefs.getInt('solace_games_won') ?? 0;
    final lost = prefs.getInt('solace_games_lost') ?? 0;

    final gamesHistoryJson = prefs.getString('solace_games_history') ?? '[]';
    List<dynamic> gamesHistoryList = [];
    try {
      gamesHistoryList = jsonDecode(gamesHistoryJson);
    } catch (e) {
      print('Error parsing games history: $e');
    }
    
    setState(() {
      gamesWon = won;
      gamesLost = lost;
      recentGames = List<Map<String, dynamic>>.from(gamesHistoryList);
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'statistics',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'CabinetGrotesk',
            fontWeight: FontWeight.w300,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: _buildPieChart(),
                  ),
                  const SizedBox(height: 40),
                  _buildStatsList(),
                  const SizedBox(height: 20),
                  const Text(
                    'Recent Games',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentGames(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildPieChart() {
    final total = gamesWon + gamesLost;
    if (total == 0) {
      return const Center(
        child: Text(
          'No games played yet',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        )
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 50,
        sections: [
          PieChartSectionData(
            value: gamesWon.toDouble(),
            title: '${((gamesWon / total) * 100).round()}%',
            color: Colors.green,
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: gamesLost.toDouble(),
            title: '${((gamesLost / total) * 100).round()}%',
            color: Colors.red,
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsList() {
    final winRate = gamesWon + gamesLost > 0 
      ? (gamesWon / (gamesWon + gamesLost) * 100).toStringAsFixed(1) 
      : '0.0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          _buildStatRow('Games Won', gamesWon.toString(), Colors.green),
          const SizedBox(height: 10),
          _buildStatRow('Games Lost', gamesLost.toString(), Colors.red),
          const SizedBox(height: 10),
          _buildStatRow('Total Games', (gamesWon + gamesLost).toString(), Colors.blue),
          const SizedBox(height: 10),
          _buildStatRow('Win Rate', '$winRate%', Colors.amber),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color iconColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.circle, color: iconColor, size: 12),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecentGames() {
    if (recentGames.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Text(
            'No game history yet',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentGames.length > 5 ? 5 : recentGames.length,
      itemBuilder: (context, index) {
        final game = recentGames[index];
        final isWin = game['result'] == 'win';
        final date = DateTime.fromMillisecondsSinceEpoch(game['timestamp']);
        final formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        final score = game['score'] ?? 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.grey[900],
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isWin ? Colors.green : Colors.red,
              ),
              child: Icon(
                isWin ? Icons.check : Icons.close,
                color: Colors.white,
              ),
            ),
            title: Text(
              isWin ? 'Victory!' : 'Defeat',
              style: TextStyle(
                color: isWin ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              formattedDate,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Text(
              'Score: $score',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              if (game.containsKey('gameState')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameDetailView(
                      gameState: game['gameState'],
                      date: formattedDate,
                      score: score,
                      isWin: isWin,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}