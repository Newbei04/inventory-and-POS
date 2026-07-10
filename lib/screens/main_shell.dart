import 'package:flutter/material.dart';
import 'package:price_checker/utils/app_lifecycle.dart';
import 'package:price_checker/screens/dashboard_screen.dart';
import 'package:price_checker/screens/home_screen.dart';
import 'package:price_checker/screens/settings_screen.dart';
import 'package:price_checker/screens/price_check_screen.dart';
import 'package:price_checker/screens/stock_logs_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;

  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  static const _pages = [
    DashboardScreen(),
    HomeScreen(),
    PriceCheckScreen(),
    StockLogsScreen(),
    SettingsScreen(),
  ];

  late final List<AnimationController> _pulseControllers;
  late final List<Animation<double>> _pulseAnimations;

  @override
  void initState() {
    super.initState();
    _pulseControllers = List.generate(5, (_) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      );
    });
    _pulseAnimations = _pulseControllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.elasticOut);
    }).toList();
    _pulseControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _pulseControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTap(int i) {
    if (i == _currentIndex) {
      _navigatorKeys[i].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    _pulseControllers[_currentIndex].reverse();
    setState(() => _currentIndex = i);
    _pulseControllers[i].forward();
    _navigatorKeys[i].currentState?.popUntil((route) => route.isFirst);
  }

  void _showExitDialog() {
    showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    ).then((result) {
      if (result == true && mounted) {
        killApp();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom + _barHeight + 16;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final currentNav = _navigatorKeys[_currentIndex].currentState;
        if (currentNav != null && currentNav.canPop()) {
          currentNav.pop();
        } else {
          _showExitDialog();
        }
      },
      child: Scaffold(
        extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: IndexedStack(
          index: _currentIndex,
          children: _pages.asMap().entries.map((entry) {
            return _buildTabNavigator(entry.key, entry.value);
          }).toList(),
        ),
      ),
      bottomNavigationBar: _FloatingGlassBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        pulseAnimations: _pulseAnimations,
        colorScheme: cs,
      ),
      ),
    );
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }
}

// ── Nav sizing ──
const _iconSize = 22.0;
const _circleSize = 40.0;
const _fontSize = 10.0;
const _gap = 2.0;
const _pillInset = 6.0;
const _barHPadding = 4.0;

double get _labelHeight {
  final span = TextSpan(
    text: 'Hg',
    style: TextStyle(fontSize: _fontSize),
  );
  final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
    ..layout();
  return painter.height;
}

double get _barHeight => _circleSize + _gap + _labelHeight + _pillInset * 2;

double get _pillRadius => (_barHeight - _pillInset * 2) / 2;

// ── Floating glass bar ──

class _FloatingGlassBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<Animation<double>> pulseAnimations;
  final ColorScheme colorScheme;

  const _FloatingGlassBar({
    required this.currentIndex,
    required this.onTap,
    required this.pulseAnimations,
    required this.colorScheme,
  });

  static const _items = [
    _BarItemData(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
    _BarItemData(Icons.inventory_2_outlined, Icons.inventory_2, 'Products'),
    _BarItemData(
      Icons.qr_code_scanner_rounded,
      Icons.qr_code_scanner_rounded,
      'Scan',
    ),
    _BarItemData(Icons.history_outlined, Icons.history, 'Logs'),
    _BarItemData(Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final barHeight = _barHeight;
    final pillRadius = _pillRadius;
    final barBR = Radius.circular(barHeight / 2 + 2);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      height: barHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(barBR),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _barHPadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(barBR),
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / 5;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: currentIndex * itemWidth,
                  width: itemWidth,
                  top: _pillInset,
                  bottom: _pillInset,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(pillRadius),
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    return Expanded(
                      child: _BarTab(
                        isSelected: currentIndex == i,
                        animation: pulseAnimations[i],
                        item: _items[i],
                        colorScheme: colorScheme,
                        isCenter: i == 2,
                        onTap: () => onTap(i),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BarItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _BarItemData(this.icon, this.selectedIcon, this.label);
}

// ── Unified bar tab ──

class _BarTab extends StatelessWidget {
  final bool isSelected;
  final Animation<double> animation;
  final _BarItemData item;
  final ColorScheme colorScheme;
  final bool isCenter;
  final VoidCallback onTap;

  const _BarTab({
    required this.isSelected,
    required this.animation,
    required this.item,
    required this.colorScheme,
    required this.isCenter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final scale = isSelected
              ? 1.0 + (isCenter ? 0.1 : 0.06) * animation.value
              : 1.0;
          return Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCenter)
                  Container(
                    width: _circleSize,
                    height: _circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.darken(18),
                              ],
                            )
                          : LinearGradient(
                              colors: [
                                colorScheme.surfaceContainerHighest,
                                colorScheme.surfaceContainerHighest.darken(8),
                              ],
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: isSelected
                          ? Colors.white
                          : colorScheme.onSurfaceVariant,
                      size: _iconSize,
                    ),
                  )
                else
                  Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    size: _iconSize,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(height: _gap),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension on Color {
  Color darken(int percent) {
    final f = (100 - percent) / 100;
    return Color.from(
      alpha: a,
      red: (r * f).clamp(0.0, 1.0),
      green: (g * f).clamp(0.0, 1.0),
      blue: (b * f).clamp(0.0, 1.0),
    );
  }
}
