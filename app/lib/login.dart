import 'package:material_ui/material_ui.dart';

import 'theme.dart';
import 'travel_data.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.travel});
  final TravelState travel;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    // thành công thì router tự chuyển sang Home
    final message = await widget.travel.signIn(
      email.text,
      password.text,
      name: register ? name.text : null,
    );
    if (mounted) {
      setState(() {
        busy = false;
        error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          const PageHeader(
            title: 'Hanoi\nTravel Planner',
            subtitle: 'Lên kế hoạch · Khám phá · Đi cùng AI',
            home: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Panel(
              child: Form(
                key: form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        register ? 'Tạo tài khoản' : 'Đăng nhập',
                        style: display(22, italic: true),
                      ),
                      const SizedBox(height: 8),
                      if (register)
                        TextFormField(
                          controller: name,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Tên'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nhập tên hiển thị'
                              : null,
                        ),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) =>
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Email không hợp lệ',
                      ),
                      TextFormField(
                        controller: password,
                        obscureText: true,
                        autofillHints: [
                          register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) => submit(),
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu',
                        ),
                        validator: (v) => register && (v?.length ?? 0) < 8
                            ? 'Mật khẩu tối thiểu 8 ký tự'
                            : (v ?? '').isEmpty
                            ? 'Nhập mật khẩu'
                            : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error!,
                          style: const TextStyle(color: Color(0xffa3321b)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      busy
                          ? const Center(child: CircularProgressIndicator())
                          : Pill(
                              register ? 'Đăng ký' : 'Đăng nhập',
                              icon: Icons.login,
                              filled: true,
                              onTap: submit,
                            ),
                      TextButton(
                        onPressed: () => setState(() {
                          register = !register;
                          error = null;
                        }),
                        child: Text(
                          register
                              ? 'Đã có tài khoản? Đăng nhập'
                              : 'Chưa có tài khoản? Đăng ký',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
