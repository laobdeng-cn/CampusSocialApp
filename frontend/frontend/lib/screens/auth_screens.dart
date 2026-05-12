import 'package:flutter/material.dart';

import '../repositories/campus_repository.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

// ENROLLMENT_YEAR_LIST_START
const List<String> _enrollmentYears = <String>[
  '2020',
  '2021',
  '2022',
  '2023',
  '2024',
  '2025',
  '2026',
];
// ENROLLMENT_YEAR_LIST_END

// YITONG_MAJOR_LIST_START
const Map<String, List<String>> _yitongCollegeMajors = <String, List<String>>{
  '计算机学院': <String>['计算机科学与技术', '智能科学与技术', '电子与计算机工程'],
  '大数据学院': <String>['数据科学与大数据技术', '数字媒体技术', '虚拟现实技术'],
  '通信与信息工程学院': <String>['通信工程', '电子信息工程', '电子信息科学与技术', '电信工程及管理', '人工智能'],
  '智能工程学院': <String>[
    '机械设计制造及其自动化',
    '机器人工程',
    '自动化',
    '电气工程及其自动化',
    '轨道交通信号与控制',
    '车辆工程',
  ],
  '信息安全学院': <String>['信息安全', '网络工程', '物联网工程', '区块链工程', '网络空间安全'],
  '数字经济商学院': <String>[
    '财务管理',
    '工商管理',
    '市场营销',
    '资产评估',
    '数字经济',
    '供应链管理',
    '工程管理',
    '信息管理与信息系统',
  ],
  '艺术传媒学院': <String>['广播电视编导', '数字媒体艺术', '动画', '网络与新媒体', '视觉传达设计'],
  '戏剧影视学院': <String>['戏剧影视文学', '戏剧影视导演', '表演', '播音与主持艺术'],
  '大健康管理学院': <String>['健康服务与管理', '体育经济与管理'],
  '德国工程学院': <String>['机械设计制造及其自动化（中外合作办学）', '电气工程及其自动化（中外合作办学）'],
  '外国语学院': <String>['英语', '德语'],
  '国际教育学院': <String>['软件工程', '互联网金融'],
  '远景学院': <String>['通识实验班'],
};
// YITONG_MAJOR_LIST_END

// CQ_SCHOOL_LIST_START
const List<String> _chongqingUniversities = <String>[
  '重庆大学',
  '重庆邮电大学',
  '重庆交通大学',
  '重庆医科大学',
  '西南大学',
  '重庆师范大学',
  '重庆文理学院',
  '重庆三峡科技大学',
  '长江师范学院',
  '四川外国语大学',
  '西南政法大学',
  '四川美术学院',
  '重庆科技大学',
  '重庆理工大学',
  '重庆工商大学',
  '重庆机电职业技术大学',
  '重庆工程学院',
  '重庆城市科技学院',
  '重庆警察学院',
  '重庆人文科技学院',
  '重庆外语外事学院',
  '重庆对外经贸学院',
  '重庆财经学院',
  '重庆工商大学派斯学院',
  '重庆移通学院',
  '重庆第二师范学院',
  '重庆中医药学院',
  '重庆电子科技职业大学',
  '重庆工业职业技术大学',
  '重庆航天职业技术学院',
  '重庆电力高等专科学校',
  '重庆三峡职业学院',
  '重庆工贸职业技术学院',
  '重庆海联职业技术学院',
  '重庆信息技术职业学院',
  '重庆传媒职业学院',
  '重庆城市管理职业学院',
  '重庆工程职业技术学院',
  '重庆建筑科技职业学院',
  '重庆城市职业学院',
  '重庆水利电力职业技术学院',
  '重庆工商职业学院',
  '重庆应用技术职业学院',
  '重庆三峡医药高等专科学校',
  '重庆医药高等专科学校',
  '重庆青年职业技术学院',
  '重庆财经职业学院',
  '重庆科创职业学院',
  '重庆建筑工程职业学院',
  '重庆电讯职业学院',
  '重庆能源职业学院',
  '重庆商务职业学院',
  '重庆交通职业学院',
  '重庆化工职业学院',
  '重庆旅游职业学院',
  '重庆安全技术职业学院',
  '重庆公共运输职业学院',
  '重庆艺术工程职业学院',
  '重庆轻工职业学院',
  '重庆电信职业学院',
  '重庆经贸职业学院',
  '重庆幼儿师范高等专科学校',
  '重庆文化艺术职业学院',
  '重庆科技职业学院',
  '重庆资源与环境保护职业学院',
  '重庆护理职业学院',
  '重庆理工职业学院',
  '重庆智能工程职业学院',
  '重庆健康职业学院',
  '重庆工信职业学院',
  '重庆五一职业技术学院',
  '重庆数字产业职业技术学院',
  '重庆现代制造职业学院',
  '重庆农业职业学院',
  '重庆安防职业学院',
];
// CQ_SCHOOL_LIST_END

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
  final _codeController = TextEditingController();
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
    final invitationCode = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();

    if (username.isEmpty ||
        invitationCode.isEmpty ||
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
        invitationCode: invitationCode,
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
                      icon: Icons.key_rounded,
                      hint: '请输入邀请码',
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
  final _campusNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _majorController = TextEditingController();
  final _enrollmentYearController = TextEditingController();
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
        campusRole: 'student',
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
                    _SchoolDropdownField(controller: _campusNameController),
                    const SizedBox(height: 14),
                    _AuthInputField(
                      controller: _studentIdController,
                      icon: Icons.badge_rounded,
                      hint: '学号',
                    ),
                    const SizedBox(height: 14),
                    _MajorDropdownField(controller: _majorController),
                    const SizedBox(height: 14),
                    _EnrollmentYearDropdownField(
                      controller: _enrollmentYearController,
                    ),

                    const SizedBox(height: 24),
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

// CQ_SCHOOL_DROPDOWN_START
class _SchoolDropdownField extends StatefulWidget {
  const _SchoolDropdownField({required this.controller});

  final TextEditingController controller;

  @override
  State<_SchoolDropdownField> createState() => _SchoolDropdownFieldState();
}

class _SchoolDropdownFieldState extends State<_SchoolDropdownField> {
  Future<void> _openPicker() async {
    FocusScope.of(context).unfocus();

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SchoolPickerSheet(initialValue: widget.controller.text),
    );

    if (selected == null || selected.trim().isEmpty) return;

    setState(() {
      widget.controller.text = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openPicker,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value.isEmpty ? AppColors.line : AppColors.blue,
            width: value.isEmpty ? 1 : 1.4,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.apartment_rounded,
              color: AppColors.blue,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.isEmpty ? '请选择学校' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value.isEmpty ? AppColors.muted : AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.muted,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolPickerSheet extends StatefulWidget {
  const _SchoolPickerSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_SchoolPickerSheet> createState() => _SchoolPickerSheetState();
}

class _SchoolPickerSheetState extends State<_SchoolPickerSheet> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredSchools {
    final keyword = _keyword.trim();
    if (keyword.isEmpty) return _chongqingUniversities;

    return _chongqingUniversities
        .where((school) => school.contains(keyword))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '选择学校',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _keyword = value),
            decoration: InputDecoration(
              hintText: '搜索重庆市高校',
              hintStyle: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.blue,
              ),
              filled: true,
              fillColor: const Color(0xFFF7FAFF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 12),
          Expanded(
            child: _filteredSchools.isEmpty
                ? const Center(
                    child: Text(
                      '未找到匹配学校',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredSchools.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, index) {
                      final school = _filteredSchools[index];
                      final selected = school == widget.initialValue;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          school,
                          style: TextStyle(
                            color: selected ? AppColors.blue : AppColors.text,
                            fontSize: 16,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.blue,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, school),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
// CQ_SCHOOL_DROPDOWN_END

// YITONG_MAJOR_DROPDOWN_START
class _MajorDropdownField extends StatefulWidget {
  const _MajorDropdownField({required this.controller});

  final TextEditingController controller;

  @override
  State<_MajorDropdownField> createState() => _MajorDropdownFieldState();
}

class _MajorDropdownFieldState extends State<_MajorDropdownField> {
  Future<void> _openPicker() async {
    FocusScope.of(context).unfocus();

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MajorPickerSheet(initialValue: widget.controller.text),
    );

    if (selected == null || selected.trim().isEmpty) return;

    setState(() {
      widget.controller.text = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openPicker,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value.isEmpty ? AppColors.line : AppColors.blue,
            width: value.isEmpty ? 1 : 1.4,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.school_rounded, color: AppColors.blue, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.isEmpty ? '请选择院系 / 专业' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value.isEmpty ? AppColors.muted : AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.muted,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _MajorPickerSheet extends StatefulWidget {
  const _MajorPickerSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_MajorPickerSheet> createState() => _MajorPickerSheetState();
}

class _MajorPickerSheetState extends State<_MajorPickerSheet> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _allItems {
    return _yitongCollegeMajors.entries
        .expand(
          (entry) => entry.value.map((major) => MapEntry(entry.key, major)),
        )
        .toList(growable: false);
  }

  List<MapEntry<String, String>> get _filteredItems {
    final keyword = _keyword.trim();
    if (keyword.isEmpty) return _allItems;

    return _allItems
        .where(
          (item) => item.key.contains(keyword) || item.value.contains(keyword),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.76,
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '选择院系 / 专业',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _keyword = value),
            decoration: InputDecoration(
              hintText: '搜索学院或专业',
              hintStyle: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.blue,
              ),
              filled: true,
              fillColor: const Color(0xFFF7FAFF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 12),
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(
                    child: Text(
                      '未找到匹配专业',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final display = '${item.key} / ${item.value}';
                      final selected = display == widget.initialValue;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.value,
                          style: TextStyle(
                            color: selected ? AppColors.blue : AppColors.text,
                            fontSize: 16,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          item.key,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.blue,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, display),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
// YITONG_MAJOR_DROPDOWN_END

// ENROLLMENT_YEAR_DROPDOWN_START
class _EnrollmentYearDropdownField extends StatefulWidget {
  const _EnrollmentYearDropdownField({required this.controller});

  final TextEditingController controller;

  @override
  State<_EnrollmentYearDropdownField> createState() =>
      _EnrollmentYearDropdownFieldState();
}

class _EnrollmentYearDropdownFieldState
    extends State<_EnrollmentYearDropdownField> {
  Future<void> _openPicker() async {
    FocusScope.of(context).unfocus();

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EnrollmentYearPickerSheet(initialValue: widget.controller.text),
    );

    if (selected == null || selected.trim().isEmpty) return;

    setState(() {
      widget.controller.text = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openPicker,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value.isEmpty ? AppColors.line : AppColors.blue,
            width: value.isEmpty ? 1 : 1.4,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.blue,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.isEmpty ? '请选择入学年份' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value.isEmpty ? AppColors.muted : AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.muted,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentYearPickerSheet extends StatelessWidget {
  const _EnrollmentYearPickerSheet({required this.initialValue});

  final String initialValue;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.55,
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '选择入学年份',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _enrollmentYears.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.line),
                itemBuilder: (context, index) {
                  final year = _enrollmentYears[index];
                  final selected = year == initialValue;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      year,
                      style: TextStyle(
                        color: selected ? AppColors.blue : AppColors.text,
                        fontSize: 18,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: AppColors.blue)
                        : null,
                    onTap: () => Navigator.pop(context, year),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ENROLLMENT_YEAR_DROPDOWN_END
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
