import 'package:flutter/material.dart';

import '../models/campus_models.dart';
import '../theme/app_theme.dart';

const kPagePadding = EdgeInsets.symmetric(horizontal: 18);

class CampusCard extends StatelessWidget {
  const CampusCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    super.key,
    this.action,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(18, 24, 18, 12),
  });

  final String title;
  final Widget? action;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.blue, size: 22),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ?action,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    super.key,
    this.color = AppColors.blue,
    this.selected = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? color : color.withValues(alpha: 0.1);
    final foreground = selected ? Colors.white : color;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground, size: 15),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CampusAvatar extends StatelessWidget {
  const CampusAvatar({
    required this.user,
    super.key,
    this.size = 46,
    this.showBadge = false,
  });

  final CampusUser user;
  final double size;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final image = avatarUrl.startsWith('asset:')
        ? Image.asset(
            avatarUrl.substring('asset:'.length),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                _AvatarFallback(name: user.name, size: size),
          )
        : Image.network(
            avatarUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                _AvatarFallback(name: user.name, size: size),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(child: image),
        if (showBadge)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppColors.blue.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1),
        style: TextStyle(
          color: AppColors.blue,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

class SmartImage extends StatelessWidget {
  const SmartImage({
    required this.url,
    super.key,
    this.width,
    this.height,
    this.borderRadius = 14,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = url.startsWith('asset:')
        ? Image.asset(
            url.substring('asset:'.length),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) =>
                _ImagePlaceholder(width: width, height: height),
          )
        : Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _ImagePlaceholder(width: width, height: height);
            },
            errorBuilder: (_, _, _) =>
                _ImagePlaceholder(width: width, height: height),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFE9FAF1)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.image_outlined, color: AppColors.blue),
    );
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({required this.users, super.key, this.size = 30});

  final List<CampusUser> users;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: users.take(4).length * (size * 0.68) + 8,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < users.take(4).length; i++)
            Positioned(
              left: i * size * 0.62,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CampusAvatar(user: users[i], size: size),
              ),
            ),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.text = '搜索好友、帖子、活动、话题...',
    this.onTap,
    this.autofocus = false,
  });

  final String text;
  final VoidCallback? onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: autofocus,
      readOnly: onTap != null,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: text,
        prefixIcon: const Icon(Icons.search, size: 22),
        suffixIcon: const Icon(Icons.crop_free, size: 20),
        filled: true,
        fillColor: const Color(0xFFF0F4FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.color = AppColors.blue,
    this.height = 52,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class IconBubble extends StatelessWidget {
  const IconBubble({
    required this.icon,
    super.key,
    this.color = AppColors.blue,
    this.size = 42,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class EmptySafeArea extends StatelessWidget {
  const EmptySafeArea({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: MediaQuery.paddingOf(context).bottom + 14);
  }
}

class BottomTabs extends StatelessWidget {
  const BottomTabs({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_available_rounded),
            label: '活动',
          ),
          BottomNavigationBarItem(
            icon: _MessageTabIcon(),
            activeIcon: _MessageTabIcon(selected: true),
            label: '消息',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum_rounded),
            label: '社区',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class _MessageTabIcon extends StatelessWidget {
  const _MessageTabIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: 18,
        ),
      );
    }
    return const Icon(Icons.chat_bubble_outline_rounded);
  }
}

final ValueNotifier<int> campusTabIndexNotifier = ValueNotifier<int>(0);

void navigateToTab(BuildContext context, int index) {
  campusTabIndexNotifier.value = index;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class TabSwitchNotification extends Notification {
  const TabSwitchNotification(this.index);

  final int index;
}
