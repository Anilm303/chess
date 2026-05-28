// Ludo Home Screen - Main Menu
import 'package:flutter/material.dart';
import '../../../../models/ludo_models.dart';
import 'package:provider/provider.dart';
import '../../../../providers/game_provider.dart';
import '../screens/ludo_game_screen.dart';
import '../screens/ludo_lobby_screen.dart';
import '../../../../widgets/cancel_match_button.dart';

enum _PlayerSlotType { none, human, computer }

class LudoHomeScreen extends StatefulWidget {
  const LudoHomeScreen({Key? key}) : super(key: key);

  @override
  State<LudoHomeScreen> createState() => _LudoHomeScreenState();
}

class _LudoHomeScreenState extends State<LudoHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _navigating = false;
  final List<PlayerColor> _slotColors = const [
    PlayerColor.red,
    PlayerColor.green,
    PlayerColor.yellow,
    PlayerColor.blue,
  ];
  late List<_PlayerSlotType> _playerSlots;
  LudoRuleSettings _rules = const LudoRuleSettings();
  int _selectedBoardIndex = 0;
  int _selectedCoins = 4;
  bool _continuousRolling = false;
  bool _diceRollingFling = true;
  DifficultyLevel _difficulty = DifficultyLevel.hard;
  double _moveSpeed = 0.82;

  @override
  void initState() {
    super.initState();
    _playerSlots = [
      _PlayerSlotType.human,
      _PlayerSlotType.none,
      _PlayerSlotType.none,
      _PlayerSlotType.computer,
    ];
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GameProvider>(
        builder: (context, gp, child) {
          // if matchmaking produced a room, navigate to game screen once
          if (gp.matchedRoom != null && !_navigating) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigating = true;
              try {
                // extract players if provided, otherwise navigate with empty list
                final data = gp.matchedRoom as Map<String, dynamic>;
                final playersData = data['players'] as List<dynamic>?;
                List<Player> players = [];
                if (playersData != null) {
                  players = playersData.map((p) {
                    return Player(
                      id: p['id'] ?? p['playerId'] ?? UniqueKey().toString(),
                      name: p['name'] ?? 'Player',
                      color: PlayerColor.values[
                          (p['colorIndex'] ?? 0) % PlayerColor.values.length],
                      type: PlayerType.human,
                      tokenCount: _selectedCoins,
                    );
                  }).toList();
                }

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LudoGameScreen(
                      players: players,
                      gameMode: GameMode.online,
                      ruleSettings: _rules,
                    ),
                  ),
                );
              } catch (e) {
                // fallback: open empty online game screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LudoGameScreen(
                      players: [],
                      gameMode: GameMode.online,
                      ruleSettings: _rules,
                    ),
                  ),
                );
              }
            });
          }

          final children = <Widget>[
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF171717),
                    Color(0xFF2F2F2F),
                    Color(0xFF0C0C0C),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -60,
                    top: 120,
                    child: _glowBlob(
                      const Color(0xFF3DDC84).withAlpha(31),
                      180,
                    ),
                  ),
                  Positioned(
                    right: -70,
                    top: 30,
                    child: _glowBlob(
                      const Color(0xFFFFD54A).withAlpha(31),
                      220,
                    ),
                  ),
                  SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(context),
                                const SizedBox(height: 10),
                                _buildSetupPanel(),
                                const SizedBox(height: 12),
                                _buildPrimaryActions(context),
                                const SizedBox(height: 8),
                                _buildSecondaryActions(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];

          if (gp.isSearchingMatch) {
            children.add(
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text(
                          'Searching for match...',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        CancelMatchButton(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(children: children);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: const Text(
                  'LUDO',
                  style: TextStyle(
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: Color(0xFFFF4A4A),
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Neo-Classic',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: const Color(0xFFFFC233),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: () => _showSettings(context),
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
          ),
        ),
      ],
    );
  }

  Widget _buildSetupPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC233), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader('Select Players'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildPlayerSlotCard(0)),
                const SizedBox(width: 8),
                Expanded(child: _buildPlayerSlotCard(1)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildPlayerSlotCard(2)),
                const SizedBox(width: 8),
                Expanded(child: _buildPlayerSlotCard(3)),
              ],
            ),
            const SizedBox(height: 12),
            _sectionHeader('Select Board'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Board ${_selectedBoardIndex + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    _selectedBoardIndex = (_selectedBoardIndex + 1) % 3;
                  }),
                  child: _buildBoardPreview(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionHeader('Options'),
            const SizedBox(height: 8),
            _buildOptionRow(),
            const SizedBox(height: 8),
            _buildSpeedRow(),
            const SizedBox(height: 12),
            _sectionHeader('Game Rules'),
            const SizedBox(height: 8),
            _buildRuleRow(
              '6 also gives another turn',
              _rules.extraTurnOnSix,
              onTap: () => _setRules(
                _rules.copyWith(extraTurnOnSix: !_rules.extraTurnOnSix),
              ),
            ),
            _buildRuleRow(
              '6 also brings a coin out',
              _rules.openTokenOnSix,
              onTap: () => _setRules(
                _rules.copyWith(openTokenOnSix: !_rules.openTokenOnSix),
              ),
            ),
            _buildRuleRow(
              'Show safe cells (stars)',
              _rules.showSafeCells,
              onTap: () => _setRules(
                _rules.copyWith(showSafeCells: !_rules.showSafeCells),
              ),
            ),
            _buildRuleRow(
              '3 consecutive rolls of 1 cuts one own coin',
              _rules.threeConsecutiveOnesCutOwnCoin,
              onTap: () => _setRules(
                _rules.copyWith(
                  threeConsecutiveOnesCutOwnCoin:
                      !_rules.threeConsecutiveOnesCutOwnCoin,
                ),
              ),
            ),
            _buildRuleRow(
              'Skip a turn on 3 consecutive rolls of 1',
              _rules.skipTurnAfterThreeOnes,
              onTap: () => _setRules(
                _rules.copyWith(
                  skipTurnAfterThreeOnes: !_rules.skipTurnAfterThreeOnes,
                ),
              ),
            ),
            _buildRuleRow(
              '3 consecutive rolls of 6 brings a coin out',
              _rules.threeConsecutiveSixesBringCoinOut,
              onTap: () => _setRules(
                _rules.copyWith(
                  threeConsecutiveSixesBringCoinOut:
                      !_rules.threeConsecutiveSixesBringCoinOut,
                ),
              ),
            ),
            _buildRuleRow(
              'Gains another turn on cutting a coin',
              _rules.extraTurnOnCapture,
              onTap: () => _setRules(
                _rules.copyWith(extraTurnOnCapture: !_rules.extraTurnOnCapture),
              ),
            ),
            _buildRuleRow(
              'Gains another turn on reaching home',
              _rules.extraTurnOnHome,
              onTap: () => _setRules(
                _rules.copyWith(extraTurnOnHome: !_rules.extraTurnOnHome),
              ),
            ),
            _buildRuleRow(
              'Must cut a coin to enter home lane',
              _rules.mustCutIfCuttable,
              onTap: () => _setRules(
                _rules.copyWith(mustCutIfCuttable: !_rules.mustCutIfCuttable),
              ),
            ),
            _buildRuleRow(
              'Must cut the coin if it\'s cuttable',
              _rules.mustCutIfCuttable,
              onTap: () => _setRules(
                _rules.copyWith(mustCutIfCuttable: !_rules.mustCutIfCuttable),
              ),
            ),
            _buildRuleRow(
              'Must bring a coin out on 1',
              _rules.openTokenOnOne,
              onTap: () => _setRules(
                _rules.copyWith(openTokenOnOne: !_rules.openTokenOnOne),
              ),
            ),
            _buildRuleRow(
              '2 coins of same colour form a barrier',
              _rules.barrierEnabled,
              onTap: () => _setRules(
                _rules.copyWith(barrierEnabled: !_rules.barrierEnabled),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSlotCard(int index) {
    final color = _slotColors[index];
    final slotType = _playerSlots[index];
    final label = slotType == _PlayerSlotType.none
        ? 'None'
        : slotType == _PlayerSlotType.human
            ? 'Human ${index + 1}'
            : 'Computer ${index + 1}';

    final fillColor = switch (color) {
      PlayerColor.red => const Color(0xFFF1463A),
      PlayerColor.green => const Color(0xFF59A95A),
      PlayerColor.yellow => const Color(0xFFF0D63D),
      PlayerColor.blue => const Color(0xFF3B73F2),
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _slotToggleButton(
                  'None',
                  slotType == _PlayerSlotType.none,
                  onTap: () => setState(() {
                    _playerSlots[index] = _PlayerSlotType.none;
                  }),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _slotToggleButton(
                  'Human',
                  slotType == _PlayerSlotType.human,
                  onTap: () => setState(() {
                    _playerSlots[index] = _PlayerSlotType.human;
                  }),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _slotToggleButton(
                  'Comp',
                  slotType == _PlayerSlotType.computer,
                  onTap: () => setState(() {
                    _playerSlots[index] = _PlayerSlotType.computer;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotToggleButton(
    String label,
    bool selected, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withAlpha(71) : Colors.black12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white70),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildBoardPreview() {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC233), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Container(color: const Color(0xFFF1463A))),
                  Expanded(child: Container(color: const Color(0xFF3B73F2))),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Container(color: const Color(0xFF59A95A))),
                  Expanded(child: Container(color: const Color(0xFFF0D63D))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Coins:'),
        ...List.generate(4, (index) {
          final value = index + 1;
          final isSelected = _selectedCoins == value;
          return _pillChoice(
            '$value',
            isSelected,
            onTap: () => setState(() => _selectedCoins = value),
            selectedColor: const Color(0xFFFFC233),
          );
        }),
        const SizedBox(width: 4),
        const Text('Cont. Rolling:'),
        _pillChoice(
          _continuousRolling ? 'On' : 'Off',
          _continuousRolling,
          onTap: () => setState(() => _continuousRolling = !_continuousRolling),
          selectedColor: const Color(0xFF59A95A),
        ),
        const SizedBox(width: 4),
        const Text('Diff. Level:'),
        _pillChoice(
          _difficulty.name[0].toUpperCase() + _difficulty.name.substring(1),
          true,
          onTap: () => setState(() {
            _difficulty = switch (_difficulty) {
              DifficultyLevel.easy => DifficultyLevel.medium,
              DifficultyLevel.medium => DifficultyLevel.hard,
              DifficultyLevel.hard => DifficultyLevel.easy,
            };
          }),
          selectedColor: const Color(0xFFFF8A3D),
        ),
        const SizedBox(width: 4),
        const Text('Dice Rolling:'),
        _pillChoice(
          _diceRollingFling ? 'Fling' : 'Tap',
          _diceRollingFling,
          onTap: () => setState(() => _diceRollingFling = !_diceRollingFling),
          selectedColor: const Color(0xFF3B73F2),
        ),
      ],
    );
  }

  Widget _buildSpeedRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Coin moving speed:'),
        Slider(
          value: _moveSpeed,
          min: 0.2,
          max: 1.0,
          divisions: 8,
          activeColor: const Color(0xFF59A95A),
          onChanged: (value) => setState(() => _moveSpeed = value),
        ),
      ],
    );
  }

  Widget _buildRuleRow(
    String label,
    bool enabled, {
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE4D2A0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled
                      ? const Color(0xFF59A95A)
                      : const Color(0xFFF1463A),
                ),
                child: Icon(
                  enabled ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            'Exit',
            const Color(0xFFE24E44),
            () => Navigator.maybePop(context),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _actionButton(
            'Play',
            const Color(0xFF86D63B),
            () => _startSelectedGame(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => _showOnlineOptions(context),
          child: const Text('Online'),
        ),
        TextButton(
          onPressed: () {
            final gpLocal = context.read<GameProvider>();
            gpLocal.quickMatch();
          },
          child: const Text('Quick Match'),
        ),
        TextButton(
          onPressed: () => _showLeaderboard(context),
          child: const Text('Leaderboard'),
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withAlpha(217)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withAlpha(128)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(89),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC233),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _pillChoice(
    String label,
    bool selected, {
    required VoidCallback onTap,
    required Color selectedColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selectedColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _glowBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  void _setRules(LudoRuleSettings settings) {
    setState(() {
      _rules = settings;
    });
  }

  Widget _buildGameModeButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(102),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withAlpha(179)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOfflineOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('2 Players'),
              onTap: () {
                Navigator.pop(context);
                _startOfflineGame(context, 2);
              },
            ),
            ListTile(
              title: const Text('4 Players'),
              onTap: () {
                Navigator.pop(context);
                _startOfflineGame(context, 4);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOnlineOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Online Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Create Room'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement create room
              },
            ),
            ListTile(
              title: const Text('Join Room'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LudoLobbyScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startVsComputer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('VS Computer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Easy'),
              onTap: () {
                Navigator.pop(context);
                _startVsComputerGame(context, DifficultyLevel.easy);
              },
            ),
            ListTile(
              title: const Text('Medium'),
              onTap: () {
                Navigator.pop(context);
                _startVsComputerGame(context, DifficultyLevel.medium);
              },
            ),
            ListTile(
              title: const Text('Hard'),
              onTap: () {
                Navigator.pop(context);
                _startVsComputerGame(context, DifficultyLevel.hard);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startOfflineGame(BuildContext context, int playerCount) {
    _launchOfflineGame(context, playerCount);
  }

  void _launchOfflineGame(BuildContext context, int playerCount) {
    final players = <Player>[];

    for (int i = 0; i < playerCount && i < _slotColors.length; i++) {
      final slotType =
          i < _playerSlots.length ? _playerSlots[i] : _PlayerSlotType.human;
      players.add(
        Player(
          id: 'player_$i',
          name: slotType == _PlayerSlotType.computer
              ? 'Computer ${i + 1}'
              : 'Player ${i + 1}',
          color: _slotColors[i],
          type: slotType == _PlayerSlotType.computer
              ? PlayerType.ai
              : PlayerType.human,
          difficulty: slotType == _PlayerSlotType.computer ? _difficulty : null,
          tokenCount: _selectedCoins,
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LudoGameScreen(
          players: players,
          gameMode: GameMode.offline,
          ruleSettings: _rules,
        ),
      ),
    );
  }

  void _startSelectedGame(BuildContext context) {
    final players = <Player>[];

    for (int i = 0; i < _playerSlots.length; i++) {
      final slot = _playerSlots[i];
      if (slot == _PlayerSlotType.none) continue;

      players.add(
        Player(
          id: 'player_$i',
          name: slot == _PlayerSlotType.human
              ? 'Human ${i + 1}'
              : 'Computer ${i + 1}',
          color: _slotColors[i],
          type:
              slot == _PlayerSlotType.human ? PlayerType.human : PlayerType.ai,
          difficulty: slot == _PlayerSlotType.computer ? _difficulty : null,
          tokenCount: _selectedCoins,
        ),
      );
    }

    if (players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 players')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LudoGameScreen(
          players: players,
          gameMode: GameMode.offline,
          ruleSettings: _rules,
        ),
      ),
    );
  }

  void _startVsComputerGame(BuildContext context, DifficultyLevel difficulty) {
    final players = [
      Player(
        id: 'player_human',
        name: 'You',
        color: PlayerColor.red,
        type: PlayerType.human,
        tokenCount: _selectedCoins,
      ),
      Player(
        id: 'player_ai',
        name: 'Computer',
        color: PlayerColor.blue,
        type: PlayerType.ai,
        difficulty: difficulty,
        tokenCount: _selectedCoins,
      ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LudoGameScreen(
          players: players,
          gameMode: GameMode.vsComputer,
          ruleSettings: _rules,
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              title: Text('Sound Effects'),
              trailing: Icon(Icons.volume_up),
            ),
            ListTile(
              title: Text('Background Music'),
              trailing: Icon(Icons.music_note),
            ),
            ListTile(title: Text('Vibration'), trailing: Icon(Icons.vibration)),
            ListTile(title: Text('Language'), trailing: Icon(Icons.language)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLeaderboard(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leaderboard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(title: Text('1. Player Name'), trailing: Text('1500 pts')),
            ListTile(title: Text('2. Player Name'), trailing: Text('1200 pts')),
            ListTile(title: Text('3. Player Name'), trailing: Text('900 pts')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
