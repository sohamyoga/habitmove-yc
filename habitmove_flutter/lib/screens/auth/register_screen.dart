import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onGoLogin;
  const RegisterScreen({super.key, this.onGoLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _name       = TextEditingController();
  final _email      = TextEditingController();
  final _password   = TextEditingController();
  final _confirm    = TextEditingController();
  bool _showPass    = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _name.dispose(); _email.dispose();
    _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    await context.read<AuthProvider>().register(
      _name.text.trim(), _email.text.trim(),
      _password.text, _confirm.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sage50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Consumer<AuthProvider>(
            builder: (ctx, auth, _) => Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _Logo(),
                  const SizedBox(height: 40),

                  Text('Begin your journey', style: AppTextStyles.displayMd),
                  const SizedBox(height: 6),
                  Text("It's free to get started.",
                      style: AppTextStyles.body.copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 32),

                  if (auth.error != null) ...[
                    AlertBanner(message: auth.error!),
                    const SizedBox(height: 16),
                  ],

                  AppTextField(
                    label: 'Full name',
                    hint: 'Jane Doe',
                    controller: _name,
                    validator: (v) => v!.trim().length >= 2 ? null : 'Enter your name',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Password',
                    hint: 'Minimum 8 characters',
                    controller: _password,
                    obscure: !_showPass,
                    suffix: IconButton(
                      icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility,
                          size: 20, color: AppColors.grey400),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                    validator: (v) => v!.length >= 8 ? null : 'At least 8 characters',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Confirm password',
                    hint: '••••••••',
                    controller: _confirm,
                    obscure: !_showConfirm,
                    suffix: IconButton(
                      icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility,
                          size: 20, color: AppColors.grey400),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                    validator: (v) => v == _password.text ? null : 'Passwords must match',
                  ),
                  const SizedBox(height: 24),

                  PrimaryButton(
                    label: 'Create account',
                    loading: auth.loading,
                    onPressed: _register,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'By signing up you agree to our Terms of Service.',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ',
                          style: AppTextStyles.body.copyWith(color: AppColors.grey400)),
                      GestureDetector(
                        onTap: widget.onGoLogin,
                        child: Text('Sign in',
                            style: AppTextStyles.body.copyWith(
                                color: AppColors.sage700, fontWeight: FontWeight.w600)),
                      ),
                    ],
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

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.sage700, shape: BoxShape.circle),
        child: const Icon(Icons.spa_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      const Text('HabitMove',
          style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22, color: AppColors.sage900)),
    ],
  );
}
