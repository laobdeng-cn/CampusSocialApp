import 'dart:async';

import 'package:flutter/material.dart';

import '../models/campus_models.dart';
import '../repositories/auth_session.dart';
import '../repositories/campus_repository.dart';
import '../screens/main_shell.dart';
import '../theme/app_theme.dart';
import 'campus_widgets.dart';

class AuthAwareCampusShell extends StatefulWidget {
  const AuthAwareCampusShell({super.key});

  @override
  State<AuthAwareCampusShell> createState() => _AuthAwareCampusShellState();
}

class _AuthAwareCampusShellState extends State<AuthAwareCampusShell> {
  var _currentTab = campusTabIndexNotifier.value;
  var _unreadCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    campusTabIndexNotifier.addListener(_onTabChanged);
    _loadUnreadCount();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _loadUnreadCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    campusTabIndexNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() => _currentTab = campusTabIndexNotifier.value);
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (!AuthSession.isLoggedIn) {
      if (mounted && _unreadCount != 0) setState(() => _unreadCount = 0);
      return;
    }
    try {
      final records = await CampusRepository.instance.fetchNotifications();
      final nextCount = records.where((item) => item.unread).length;
      if (mounted && nextCount != _unreadCount) {
        setState(() => _unreadCount = nextCount);
      }
    } catch (_) {
      if (mounted && _unreadCount != 0) setState(() => _unreadCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const CampusShell(),
        if (_currentTab == 0)
          _HomeUserHeader(
            user: AuthSession.user,
            unreadCount: _unreadCount,
            onTapNotice: () {
              campusTabIndexNotifier.value = 2;
              _loadUnreadCount();
            },
          ),
        if (_unreadCount > 0)
          _BottomUnreadBadge(currentTab: _currentTab, unreadCount: _unreadCount),
      ],
    );
  }
}

class _HomeUserHeader extends StatelessWidget {
  const _HomeUserHeader({
    required this.user,
    required this.unreadCount,
    required this.onTapNotice,
  });

  final CampusUser? user;
  final int unreadCount;
  final VoidCallback onTapNotice;

  @override
  Widget build(BuildContext context) {
    final name = user?.name.trim().isNotEmpty == true ? user!.name.trim() : '同学';
    final label = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.white,
          child: SizedBox(
            height: 86,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '早上好，$name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '今天也是元气满满的一天',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onTapNotice,
                    icon: unreadCount > 0
                        ? Badge(
                            label: Text(label),
                            child: const Icon(Icons.notifications_none_rounded),
                          )
                        : const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomUnreadBadge extends StatelessWidget {
  const _BottomUnreadBadge({required this.currentTab, required this.unreadCount});

  final int currentTab;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      left: media.size.width * 0.5 + (currentTab == 2 ? 14 : 12),
      bottom: media.padding.bottom + (currentTab == 2 ? 54 : 57),
      child: IgnorePointer(
        child: Badge(
          label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
          child: const SizedBox(width: 8, height: 8),
        ),
      ),
    );
  }
}
