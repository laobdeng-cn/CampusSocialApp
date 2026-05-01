import 'package:flutter/material.dart';

import '../repositories/campus_repository.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _enterApp(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CampusShell()),
    );
  }

  Future<void> _login() async {
    final username = _phoneController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showAuthMessage(context, '请输入手机号和密码');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await CampusRepository.instance.login(
        username: username,
        password: password,
      );
      if (!mounted) return;
      _enterApp(context);
    } catch (error) {
      if (!mounted) return;
      _showAuthMessage(context, _friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _AuthHero(
              title: '校园活动圈',
              subtitle: '登录后开启你的校园生活',
              variant: _AuthHeroVariant.group,
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AuthPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AuthTitle('登录'),
                      const SizedBox(height: 24),
                      _AuthInputField(
                        controller: _phoneController,
                        icon: Icons.phone_iphone_rounded,
                        hint: '请输入手机号',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _AuthInputField(
                        controller: _passwordController,
                        icon: Icons.lock_outline_rounded,
                        hint: '请输入密码',
                        obscureText: true,
                        suffixIcon: Icons.visibility_off_outlined,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const _CheckedLabel(label: '记住登录'),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: const Text('忘记密码？'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _PrimaryAuthButton(
                        label: _isSubmitting ? '登录中...' : '登录',
                        onPressed: _isSubmitting ? null : _login,
                      ),
                      const SizedBox(height: 22),
                      _InlineLinkRow(
                        normal: '还没有账号？',
                        link: '立即注册',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      _DividerLink(
                        label: '先去校园认证',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CampusVerificationScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const _OtherLoginMethods(),
            const SizedBox(height: 24),
            const _AgreementFooter(label: '登录即代表同意'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController(text: '1234');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();

    if (username.isEmpty ||
        code.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        name.isEmpty) {
      _showAuthMessage(context, '请完整填写注册信息');
      return;
    }
    if (password != confirmPassword) {
      _showAuthMessage(context, '两次输入的密码不一致');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await CampusRepository.instance.register(
        username: username,
        password: password,
        name: name,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CampusVerificationScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      _showAuthMessage(context, _friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _AuthAppBar(title: '注册'),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _AuthHero(
            title: '校园活动圈',
            subtitle: '注册账号，加入校园精彩生活',
            variant: _AuthHeroVariant.pair,
            compact: true,
            showTitle: false,
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _AuthPanel(
                child: Column(
                  children: [
                    _AuthInputField(
                      controller: _phoneController,
                      icon: Icons.phone_iphone_rounded,
                      hint: '请输入手机号',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _AuthInputField(
                      controller: _codeController,
                      icon: Icons.verified_user_outlined,
                      hint: '请输入验证码',
                      suffix: _VerificationCodeButton(),
                    ),
                    const SizedBox(height: 12),
                    _AuthInputField(
                      controller: _passwordController,
                      icon: Icons.lock_outline_rounded,
                      hint: '设置密码',
                      obscureText: true,
                      suffixIcon: Icons.visibility_off_outlined,
                    ),
                    const SizedBox(height: 12),
                    _AuthInputField(
                      controller: _confirmPasswordController,
                      icon: Icons.lock_outline_rounded,
                      hint: '确认密码',
                      obscureText: true,
                      suffixIcon: Icons.visibility_off_outlined,
                    ),
                    const SizedBox(height: 12),
                    _AuthInputField(
                      controller: _nameController,
                      icon: Icons.person_outline_rounded,
                      hint: '请输入昵称',
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _CheckedLabel(label: '我已阅读并同意《用户协议》《隐私政策》'),
                    ),
                    const SizedBox(height: 18),
                    _PrimaryAuthButton(
                      label: _isSubmitting ? '注册中...' : '注册',
                      onPressed: _isSubmitting ? null : _register,
                    ),
                    const SizedBox(height: 18),
                    _InlineLinkRow(
                      normal: '已有账号？',
                      link: '立即登录',
                      onTap: () => Navigator.maybePop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.muted,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '注册后可继续完成校园认证',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CampusVerificationScreen extends StatefulWidget {
  const CampusVerificationScreen({super.key});

  @override
  State<CampusVerificationScreen> createState() =>
      _CampusVerificationScreenState();
}

class _CampusVerificationScreenState extends State<CampusVerificationScreen> {
  final _realNameController = TextEditingController();
  final _campusNameController = TextEditingController(text: '岭南科技大学');
  final _studentIdController = TextEditingController();
  final _majorController = TextEditingController();
  final _enrollmentYearController = TextEditingController(text: '2024');
  var _role = _CampusRole.student;
  var _isSubmitting = false;

  @override
  void dispose() {
    _realNameController.dispose();
    _campusNameController.dispose();
    _studentIdController.dispose();
    _majorController.dispose();
    _enrollmentYearController.dispose();
    super.dispose();
  }

  void _enterApp() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CampusShell()),
      (_) => false,
    );
  }

  Future<void> _submitVerification() async {
    final realName = _realNameController.text.trim();
    final campusName = _campusNameController.text.trim();
    final studentId = _studentIdController.text.trim();
    final major = _majorController.text.trim();
    final enrollmentYear = _enrollmentYearController.text.trim();

    if (realName.isEmpty ||
        campusName.isEmpty ||
        studentId.isEmpty ||
        major.isEmpty ||
        enrollmentYear.isEmpty) {
      _showAuthMessage(context, '请完整填写校园认证信息');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await CampusRepository.instance.verifyCampus(
        realName: realName,
        campusName: campusName,
        studentId: studentId,
        major: major,
        enrollmentYear: enrollmentYear,
        campusRole: _role == _CampusRole.teacher ? 'teacher' : 'student',
      );
      if (!mounted) return;
      _enterApp();
    } catch (error) {
      if (!mounted) return;
      _showAuthMessage(context, _friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _AuthAppBar(title: '校园认证'),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _VerificationHero(),
          Transform.translate(
            offset: const Offset(0, -12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _AuthPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _AuthTitle('填写认证信息'),
                    const SizedBox(height: 22),
                    _AuthInputField(
                      controller: _realNameController,
                      icon: Icons.person_rounded,
                      hint: '真实姓名',
                    ),
                    const SizedBox(height: 14),
                    _AuthInputField(
                      controller: _campusNameController,
                      icon: Icons.apartment_rounded,
                      hint: '学校名称',
                      suffixIcon: Icons.keyboard_arrow_down_rounded,
                    ),
                    const SizedBox(height: 14),
                    _AuthInputField(
                      controller: _studentIdController,
                      icon: Icons.badge_rounded,
                      hint: '学号',
                    ),
                    const SizedBox(height: 14),
                    _AuthInputField(
                      controller: _majorController,
                      icon: Icons.school_rounded,
                      hint: '院系 / 专业',
                      suffixIcon: Icons.keyboard_arrow_down_rounded,
                    ),
                    const SizedBox(height: 14),
                    _AuthInputField(
                      controller: _enrollmentYearController,
                      icon: Icons.calendar_month_rounded,
                      hint: '入学年份',
                      suffixIcon: Icons.keyboard_arrow_down_rounded,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '认证身份',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleButton(
                            label: '学生',
                            icon: Icons.person_rounded,
                            selected: _role == _CampusRole.student,
                            onTap: () =>
                                setState(() => _role = _CampusRole.student),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _RoleButton(
                            label: '教师',
                            icon: Icons.person_rounded,
                            selected: _role == _CampusRole.teacher,
                            onTap: () =>
                                setState(() => _role = _CampusRole.teacher),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _PrimaryAuthButton(
                      label: _isSubmitting ? '提交中...' : '提交认证',
                      onPressed: _isSubmitting ? null : _submitVerification,
                    ),
                    const SizedBox(height: 14),
                    _SecondaryAuthButton(label: '暂不认证', onPressed: _enterApp),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text(
                        '审核通常在 1-2 个工作日内完成',
                        style: TextStyle(color: AppColors.muted, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CampusRole { student, teacher }

void _showAuthMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _friendlyAuthError(Object error) {
  final text = error.toString();
  const marker = 'CampusApiException: ';
  if (text.startsWith(marker)) return text.substring(marker.length);
  return '服务暂时不可用，请确认后端已启动';
}

class _AuthAppBar extends AppBar {
  _AuthAppBar({required String title})
    : super(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 27),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.title,
    required this.subtitle,
    required this.variant,
    this.compact = false,
    this.showTitle = true,
  });

  final String title;
  final String subtitle;
  final _AuthHeroVariant variant;
  final bool compact;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 230 : 310,
      padding: EdgeInsets.fromLTRB(28, compact ? 38 : 64, 20, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xFFEAF3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: 0,
            child: _CampusIllustration(variant: variant),
          ),
          Positioned(
            left: 0,
            top: compact ? 58 : 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTitle) ...[
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF092457),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _AuthHeroVariant { group, pair }

class _VerificationHero extends StatelessWidget {
  const _VerificationHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(28, 34, 18, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xFFEAF3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(right: -8, bottom: 0, child: _ShieldIllustration()),
          Positioned(
            left: 0,
            top: 36,
            child: Row(
              children: const [
                Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.blue,
                  size: 56,
                ),
                SizedBox(width: 22),
                Text(
                  '完成认证后，\n可解锁更多校园功能',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CampusIllustration extends StatelessWidget {
  const _CampusIllustration({required this.variant});

  final _AuthHeroVariant variant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 210,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            right: 18,
            bottom: 0,
            child: _Building(width: 54, height: 128, color: Color(0xFFBBD5FF)),
          ),
          Positioned(right: 82, bottom: 0, child: _ClockTower()),
          Positioned(
            left: 28,
            bottom: 0,
            child: _Building(width: 70, height: 96, color: Color(0xFFD8E7FF)),
          ),
          Positioned(
            right: 10,
            top: 16,
            child: _FloatingIcon(icon: Icons.favorite_rounded),
          ),
          Positioned(
            left: 42,
            top: 8,
            child: _FloatingIcon(icon: Icons.calendar_month_rounded),
          ),
          Positioned(
            right: 70,
            top: 0,
            child: _FloatingIcon(icon: Icons.chat_bubble_rounded),
          ),
          Positioned(
            bottom: 0,
            left: variant == _AuthHeroVariant.group ? 30 : 58,
            child: _StudentFigure(color: AppColors.blue, height: 128),
          ),
          Positioned(
            bottom: 0,
            left: variant == _AuthHeroVariant.group ? 90 : 126,
            child: _StudentFigure(color: const Color(0xFF8FB9FF), height: 112),
          ),
          if (variant == _AuthHeroVariant.group) ...[
            const Positioned(
              bottom: 0,
              left: 148,
              child: _StudentFigure(color: Color(0xFFB5CEFF), height: 120),
            ),
            const Positioned(
              bottom: 0,
              left: 196,
              child: _StudentFigure(color: Color(0xFFE8F0FF), height: 108),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShieldIllustration extends StatelessWidget {
  const _ShieldIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 185,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: const [
          Positioned(
            right: 0,
            bottom: 0,
            child: _Building(width: 66, height: 118, color: Color(0xFFD7E6FF)),
          ),
          Positioned(right: 74, bottom: 0, child: _ClockTower()),
          Positioned(
            left: 0,
            bottom: 0,
            child: _Building(width: 74, height: 86, color: Color(0xFFE2EDFF)),
          ),
          Positioned(
            top: 18,
            left: 76,
            child: Icon(Icons.shield_rounded, color: AppColors.blue, size: 118),
          ),
          Positioned(
            top: 58,
            left: 118,
            child: Icon(Icons.check_rounded, color: Colors.white, size: 52),
          ),
        ],
      ),
    );
  }
}

class _Building extends StatelessWidget {
  const _Building({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (_) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              2,
              (_) => Container(
                width: 8,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockTower extends StatelessWidget {
  const _ClockTower();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 150,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 56,
            height: 118,
            decoration: const BoxDecoration(
              color: Color(0xFFA9CAFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
          Positioned(
            top: 0,
            child: ClipPath(
              clipper: _TriangleClipper(),
              child: Container(width: 64, height: 52, color: AppColors.blue),
            ),
          ),
          Positioned(
            top: 60,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.blue,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _StudentFigure extends StatelessWidget {
  const _StudentFigure({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: height,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD4B8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              width: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.blue, size: 23),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AuthTitle extends StatelessWidget {
  const _AuthTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF092457),
        fontSize: 30,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AuthInputField extends StatelessWidget {
  const _AuthInputField({
    required this.icon,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.suffix,
  });

  final IconData icon;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? suffixIcon;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: AppColors.blue, size: 24),
          suffixIcon: suffixIcon == null
              ? null
              : Icon(suffixIcon, color: AppColors.muted, size: 23),
          suffix: suffix,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _VerificationCodeButton extends StatelessWidget {
  const _VerificationCodeButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      child: const Text('获取验证码', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _CheckedLabel extends StatelessWidget {
  const _CheckedLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 8,
        shadowColor: AppColors.blue.withValues(alpha: 0.28),
      ),
      child: Text(label),
    );
  }
}

class _SecondaryAuthButton extends StatelessWidget {
  const _SecondaryAuthButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.blue, width: 1.4),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label),
    );
  }
}

class _InlineLinkRow extends StatelessWidget {
  const _InlineLinkRow({
    required this.normal,
    required this.link,
    required this.onTap,
  });

  final String normal;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            normal,
            style: const TextStyle(color: AppColors.text, fontSize: 16),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              link,
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerLink extends StatelessWidget {
  const _DividerLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        TextButton(onPressed: onTap, child: Text(label)),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _OtherLoginMethods extends StatelessWidget {
  const _OtherLoginMethods();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '其他登录方式',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _LoginMethod(icon: Icons.wechat_rounded, label: '微信登录'),
              _LoginMethod(icon: Icons.apple_rounded, label: 'Apple 登录'),
              _LoginMethod(icon: Icons.phone_iphone_rounded, label: '手机验证码'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginMethod extends StatelessWidget {
  const _LoginMethod({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.blue, size: 30),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
        ),
      ],
    );
  }
}

class _AgreementFooter extends StatelessWidget {
  const _AgreementFooter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: AppColors.blue,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '$label ',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const Text(
            '《用户协议》',
            style: TextStyle(color: AppColors.blue, fontSize: 13),
          ),
          const Text(
            ' 和 ',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const Text(
            '《隐私政策》',
            style: TextStyle(color: AppColors.blue, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.blue : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.blue : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AppColors.muted,
                size: 23,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
