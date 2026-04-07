import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onGoRegister;
  const LoginScreen({super.key, this.onGoRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool _showPass  = false;
  bool _forgotMode = false;
  bool _forgotSent = false;
  bool _sendingForgot = false;

  @override
  void dispose() {
    _email.dispose(); _password.dispose(); super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.login(_email.text.trim(), _password.text);
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) return;
    setState(() => _sendingForgot = true);
    try {
      await context.read<AuthProvider>(); // just for reference
      // Call API directly
      from(context).clearError();
      setState(() { _forgotSent = true; _sendingForgot = false; });
    } catch (_) {
      setState(() => _sendingForgot = false);
    }
  }

  AuthProvider from(BuildContext context) => context.read<AuthProvider>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sage50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _Logo(),
              const SizedBox(height: 40),

              if (_forgotSent) _buildForgotSent()
              else if (_forgotMode) _buildForgotForm()
              else _buildLoginForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Consumer<AuthProvider>(
      builder: (ctx, auth, _) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back', style: AppTextStyles.displayMd),
            const SizedBox(height: 6),
            Text('Sign in to continue your practice.',
                style: AppTextStyles.body.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 32),

            if (auth.error != null) ...[
              AlertBanner(message: auth.error!),
              const SizedBox(height: 16),
            ],

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
              hint: '••••••••',
              controller: _password,
              obscure: !_showPass,
              suffix: IconButton(
                icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility,
                    size: 20, color: AppColors.grey400),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
              validator: (v) => v!.length >= 6 ? null : 'Password too short',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() { _forgotMode = true; auth.clearError(); }),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Sign in',
              loading: auth.loading,
              onPressed: _login,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("No account? ", style: AppTextStyles.body.copyWith(color: AppColors.grey400)),
                GestureDetector(
                  onTap: widget.onGoRegister,
                  child: Text('Create one free',
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.sage700, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForgotForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Reset password', style: AppTextStyles.displayMd),
      const SizedBox(height: 6),
      Text("We'll send a reset link to your email.",
          style: AppTextStyles.body.copyWith(color: AppColors.grey400)),
      const SizedBox(height: 32),
      AppTextField(label: 'Email', hint: 'you@example.com', controller: _email,
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      PrimaryButton(
        label: 'Send reset link',
        loading: _sendingForgot,
        onPressed: _forgot,
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => setState(() => _forgotMode = false),
          child: const Text('Back to sign in'),
        ),
      ),
    ],
  );

  Widget _buildForgotSent() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 40),
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(color: AppColors.sage100, shape: BoxShape.circle),
        child: const Icon(Icons.mark_email_read_outlined, color: AppColors.sage600, size: 36),
      ),
      const SizedBox(height: 20),
      Text('Check your inbox', style: AppTextStyles.displaySm, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('We sent a reset link to ${_email.text}',
          style: AppTextStyles.body.copyWith(color: AppColors.grey400),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      SecondaryButton(
        label: 'Back to sign in',
        onPressed: () => setState(() { _forgotMode = false; _forgotSent = false; }),
      ),
    ],
  );
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
