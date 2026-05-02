import 'dart:async';

import 'package:flutter/material.dart';

import '../models/campus_models.dart';
import '../repositories/auth_session.dart';
import '../repositories/campus_repository.dart';
import '../screens/main_shell.dart';
import '../theme/app_theme.dart';

class AuthAwareCampusShell extends StatefulWidget {
  const AuthAwareCampusShell({super.key});

  @override
  State<AuthAwareCampusShell> createState() => _AuthAwareCampusShellState();
}

class _AuthAwareCampusShellState extends State<AuthAwareCampusShell> {
  var _currentTab = campusTabIndexNotifier.value;
  var _unreadCount = 0;
  Timer? _unreadSyncTimer;

  @override
  void initState() {
    super.initState();
    campusTabIndexNotifier.addListener(_syncTabIndex);
    _loadUnreadCount();
    _unreadSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_currentTab == 0 || _currentTab == 2) {
        _loadUnreadCount();
      }
    });
  }

  @override
  void dispose() {
    _unreadSyncTimer?.cancel();
    campusTabIndexNotifier.removeListener(_syncTabIndex);
    super.dispose();
  }

  void _syncTabIndex() {
    if (!mounted) return;
    final nextTab = campusTabIndexNotifier.value;
    setState(() => _currentTab = nextTab);
    if (nextTab == 0 || nextTab == 2) {
      _loadUnreadCount();
    }
  }

  Future<void> _loadUnreadCount() async {
    if (!AuthSession.isLoggedIn) {
      if (mounted && _unreadCount != 0) setState(() => _unreadCount = 0);
      return;
    }

    try {
      final notifications = await CampusRepository.instance.fetchNotifications();
      final count = notifications.where((item) => item.unread).length;
      if (mounted && _unreadCount != count) setState(() => _unreadCount = count);
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
          _HomeUserHeaderOverlay(
            user: AuthSession.user,
            unreadCount: _unreadCount,
            onOpenMessages: () {
              campusTabIndexNotifier.value = 2;
              _loadUnreadCount();
            },
          ),
        if (_unreadCount > 0)
          _BottomMessageUnreadOverlay(
            currentTab: _currentTab,
            unreadCount: _unreadCount,
          ),
      ],
    );
  }
}

class _HomeUserHeaderOverlay extends StatelessWidget {
  const _HomeUserHeaderOverlay({
    required this.user,
    required this.unreadCount,
    required this.onOpenMessages,
  });

  final CampusUser? user;
  final int unreadCount;
  final VoidCallback onOpenMessages;

  @override
  Widget build(BuildContext context) {
    final name = user?.name.trim().isNotEmpty == true ? user!.name.trim() : '同学';
    final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.white,
          child: Container(
            height: 86,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  onPressed: onOpenMessages,
                  icon: unreadCount > 0
                      ? Badge(
                          label: Text(badgeText),
                          child: const Icon(Icons.notifications_none_rounded),
                        )
                      : const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomMessageUnreadOverlay extends StatelessWidget {
  const _BottomMessageUnreadOverlay({
    required this.currentTab,
    required this.unreadCount,
  });

  final int currentTab;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final left = media.size.width * 0.5 + (currentTab == 2 ? 14 : 12);
    final bottom = media.padding.bottom + (currentTab == 2 ? 54 : 57);

    return Positioned(
      left: left,
      bottom: bottom,
      child: IgnorePointer(
        child: Badge(
          label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
          child: const SizedBox(width: 8, height: 8),
        ),
      ),
    );
  }
}
