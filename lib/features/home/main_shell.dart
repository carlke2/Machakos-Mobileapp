import 'package:flutter/material.dart';
import 'package:mobileapp/core/network/socket_service.dart';
import 'package:mobileapp/core/theme/app_colors.dart';
import 'package:mobileapp/features/tasks/task_screen.dart';
import 'package:mobileapp/features/crew/crew_screen.dart';
import 'package:mobileapp/features/history/history_screen.dart';
import 'package:mobileapp/features/inventory/inventory_screen.dart';

/// Main navigation shell containing Assignment, Crew, History, and Inventory tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};

  @override
  void initState() {
    super.initState();
    SocketService.instance.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _loadedTabs.contains(0) ? const TaskScreen() : const SizedBox.shrink(),
          _loadedTabs.contains(1) ? const CrewScreen() : const SizedBox.shrink(),
          _loadedTabs.contains(2) ? const HistoryScreen() : const SizedBox.shrink(),
          _loadedTabs.contains(3) ? const InventoryScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() {
            _currentIndex = i;
            _loadedTabs.add(i);
          });
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: AppColors.primary),
            label: 'Assignment',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group, color: AppColors.primary),
            label: 'Crew',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: AppColors.primary),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
            label: 'Inventory',
          ),
        ],
      ),
    );
  }
}
