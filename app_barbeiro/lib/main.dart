import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

const String api = 'http://10.133.126.23:3000';

String authToken = '';

String clienteAuthToken = '';
int? clienteIdLogado;
String clienteNomeLogado = '';
String clienteNumeroLogado = '';
String clienteEmailLogado = '';

Map<String, String> headersAutenticados({bool json = false}) {
  final headers = <String, String>{};

  if (authToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer $authToken';
  }

  if (json) {
    headers['Content-Type'] = 'application/json';
  }

  return headers;
}

Map<String, String> headersCliente({bool json = false}) {
  final headers = <String, String>{};

  if (clienteAuthToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer $clienteAuthToken';
  }

  if (json) {
    headers['Content-Type'] = 'application/json';
  }

  return headers;
}

const Color corFundo = Color(0xFF0F0F0F);
const Color corCard = Color(0xFF1A1A1A);
const Color corCard2 = Color(0xFF222222);
const Color corAzul = Color(0xFF79C5EA);
const Color corTexto = Colors.white;
const Color corTextoSecundario = Color(0xFFAAAAAA);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint('Notificação recebida em segundo plano: ${message.messageId}');
}

Future<void> configurarNotificacoes() async {
  try {
    final messaging = FirebaseMessaging.instance;

    final permissao = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Permissão de notificação: ${permissao.authorizationStatus}');

    try {
      final token = await messaging.getToken();

      debugPrint('TOKEN FIREBASE DO APARELHO:');
      debugPrint(token);
    } catch (e) {
      debugPrint('Não foi possível obter token Firebase: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Notificação recebida com app aberto');
      debugPrint('Título: ${message.notification?.title}');
      debugPrint('Mensagem: ${message.notification?.body}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Usuário abriu a notificação.');
    });
  } catch (e) {
    debugPrint('Erro ao configurar notificações: $e');
  }
}

Future<void> registrarTokenPush(String barbeiro) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();

    if (token == null || token.trim().isEmpty) {
      return;
    }

    await http.post(
      Uri.parse('$api/app/push-token'),
      headers: headersAutenticados(json: true),
      body: jsonEncode({'barbeiro': barbeiro, 'token': token}),
    );
  } catch (e) {
    debugPrint('Erro ao registrar token push: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Erro ao iniciar Firebase: $e');
  }

  // ABRE O APP PRIMEIRO
  runApp(const GBarberClubApp());

  // DEPOIS TENTA CONFIGURAR AS NOTIFICAÇÕES
  configurarNotificacoes();
}

class GBarberClubApp extends StatelessWidget {
  const GBarberClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GBarberClub',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: corFundo,
        colorScheme: const ColorScheme.dark(
          primary: corAzul,
          secondary: corAzul,
          surface: corCard,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: corFundo,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: corCard,
          labelStyle: const TextStyle(color: corTextoSecundario),
          prefixIconColor: corAzul,
          suffixIconColor: corTextoSecundario,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: corAzul, width: 2),
          ),
        ),
      ),
      home: const ClienteLoginPage(),
    );
  }
}

Widget logoGBarber({double tamanho = 145, bool mostrarNome = true}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/images/Logo.png',
        width: tamanho,
        height: tamanho,
        fit: BoxFit.contain,
      ),
      if (mostrarNome) ...[
        const SizedBox(height: 12),
        const Text(
          'GBARBERCLUB',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'BARBEARIA DO GUEL',
          style: TextStyle(
            color: corAzul,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
      ],
    ],
  );
}

void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: erro ? Colors.red.shade800 : corAzul,
      behavior: SnackBarBehavior.floating,
      content: Text(
        texto,
        style: TextStyle(
          color: erro ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

ButtonStyle botaoPrincipal() {
  return ElevatedButton.styleFrom(
    backgroundColor: corAzul,
    foregroundColor: Colors.black,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

// ======================================================
// LOGIN
// ======================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usuarioController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;
  bool mostrarSenha = false;

  Future<void> entrar() async {
    final usuario = usuarioController.text.trim();
    final senha = senhaController.text;

    if (usuario.isEmpty || senha.isEmpty) {
      mostrarMensagem(context, 'Digite usuário e senha.', erro: true);
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('$api/app/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario': usuario, 'senha': senha}),
      );

      final dados = jsonDecode(resposta.body);

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        authToken = (dados['token'] ?? '').toString();

        if (authToken.isEmpty) {
          mostrarMensagem(
            context,
            'O servidor não retornou o token de acesso.',
            erro: true,
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PainelBarbeiro(
              barbeiro: dados['barbeiro'].toString(),
              nome: dados['nome'].toString(),
            ),
          ),
        );
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Usuário ou senha incorretos.',
          erro: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    usuarioController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  logoGBarber(tamanho: 155),

                  const SizedBox(height: 45),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bem-vindo',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Acesse o painel administrativo',
                      style: TextStyle(color: corTextoSecundario),
                    ),
                  ),

                  const SizedBox(height: 25),

                  TextField(
                    controller: usuarioController,
                    decoration: const InputDecoration(
                      labelText: 'Usuário',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: senhaController,
                    obscureText: !mostrarSenha,
                    onSubmitted: (_) => entrar(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            mostrarSenha = !mostrarSenha;
                          });
                        },
                        icon: Icon(
                          mostrarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EsqueciSenhaPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Esqueci minha senha',
                        style: TextStyle(color: corAzul),
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: carregando ? null : entrar,
                      style: botaoPrincipal(),
                      child: carregando
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'ENTRAR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Acesso exclusivo para Guel e Gustavo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: corTextoSecundario,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClienteLoginPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline, size: 22),
                      label: const Text(
                        'SOU UM CLIENTE',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: corAzul,
                        side: const BorderSide(color: corAzul, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Acessar área de cliente',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: corTextoSecundario, fontSize: 11),
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

// ======================================================
// CADASTRO
// ======================================================

class ClienteLoginPage extends StatefulWidget {
  const ClienteLoginPage({super.key});

  @override
  State<ClienteLoginPage> createState() => _ClienteLoginPageState();
}

class _ClienteLoginPageState extends State<ClienteLoginPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool carregando = false;
  bool mostrarSenha = false;

  Future<void> entrar() async {
    final email = emailController.text.trim();
    final senha = senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      mostrarMensagem(context, 'Digite e-mail e senha.', erro: true);
      return;
    }

    setState(() => carregando = true);

    try {
      final resposta = await http.post(
        Uri.parse('$api/cliente/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      final dados = jsonDecode(resposta.body);

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        clienteAuthToken = dados['token']?.toString() ?? '';
        clienteIdLogado = int.tryParse(dados['id']?.toString() ?? '');
        clienteNomeLogado = dados['nome']?.toString() ?? 'Cliente';
        clienteNumeroLogado = dados['numero']?.toString() ?? '';
        clienteEmailLogado = dados['email']?.toString() ?? email;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClienteInicioPage(
              nome: clienteNomeLogado,
              email: clienteEmailLogado,
              numero: clienteNumeroLogado,
            ),
          ),
        );
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'E-mail ou senha incorretos.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Área do Cliente')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  logoGBarber(tamanho: 105),
                  const SizedBox(height: 20),
                  const Text(
                    'Bem-vindo de volta 👋',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Entre para acompanhar seus agendamentos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: corTextoSecundario),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: senhaController,
                    obscureText: !mostrarSenha,
                    onSubmitted: (_) => entrar(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => mostrarSenha = !mostrarSenha),
                        icon: Icon(
                          mostrarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: carregando ? null : entrar,
                      style: botaoPrincipal(),
                      child: carregando
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'ENTRAR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClienteCadastroPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Ainda não tenho conta — Criar cadastro',
                      style: TextStyle(color: corAzul),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      icon: const Icon(Icons.content_cut, size: 22),
                      label: const Text(
                        'SOU UM BARBEIRO',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: corAzul,
                        side: const BorderSide(color: corAzul, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Acessar painel administrativo',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: corTextoSecundario, fontSize: 11),
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

class ClienteCadastroPage extends StatefulWidget {
  const ClienteCadastroPage({super.key});

  @override
  State<ClienteCadastroPage> createState() => _ClienteCadastroPageState();
}

class _ClienteCadastroPageState extends State<ClienteCadastroPage> {
  final nomeController = TextEditingController();
  final telefoneController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarController = TextEditingController();
  bool carregando = false;
  bool mostrarSenha = false;

  Future<void> cadastrar() async {
    final nome = nomeController.text.trim();
    final telefone = telefoneController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text;
    final confirmar = confirmarController.text;

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      mostrarMensagem(context, 'Preencha os campos obrigatórios.', erro: true);
      return;
    }

    if (!email.contains('@')) {
      mostrarMensagem(context, 'Digite um e-mail válido.', erro: true);
      return;
    }

    if (senha.length < 6) {
      mostrarMensagem(
        context,
        'A senha deve ter pelo menos 6 caracteres.',
        erro: true,
      );
      return;
    }

    if (senha != confirmar) {
      mostrarMensagem(context, 'As senhas não coincidem.', erro: true);
      return;
    }

    setState(() => carregando = true);

    try {
      final resposta = await http.post(
        Uri.parse('$api/cliente/cadastro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'numero': telefone,
          'email': email,
          'senha': senha,
        }),
      );

      final dados = jsonDecode(resposta.body);

      if (!mounted) return;

      if (resposta.statusCode == 201 || resposta.statusCode == 200) {
        mostrarMensagem(context, 'Cadastro realizado com sucesso!');
        Navigator.pop(context);
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível criar sua conta.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    telefoneController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Cliente')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Crie sua conta',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Os campos com * são obrigatórios.',
                      style: TextStyle(color: corTextoSecundario),
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: telefoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: senhaController,
                    obscureText: !mostrarSenha,
                    decoration: InputDecoration(
                      labelText: 'Senha *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => mostrarSenha = !mostrarSenha),
                        icon: Icon(
                          mostrarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: confirmarController,
                    obscureText: !mostrarSenha,
                    onSubmitted: (_) => cadastrar(),
                    decoration: const InputDecoration(
                      labelText: 'Confirmar senha *',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: carregando ? null : cadastrar,
                      style: botaoPrincipal(),
                      child: carregando
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'CRIAR CONTA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
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

class ClienteInicioPage extends StatelessWidget {
  final String nome;
  final String email;
  final String numero;

  const ClienteInicioPage({
    super.key,
    required this.nome,
    required this.email,
    required this.numero,
  });

  Future<void> abrirPagina(BuildContext context, Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Área do Cliente'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () {
              clienteAuthToken = '';
              clienteIdLogado = null;
              clienteNomeLogado = '';
              clienteNumeroLogado = '';
              clienteEmailLogado = '';

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: corCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: corAzul.withOpacity(.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 31,
                          color: corAzul,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá, $nome 👋',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(color: corTextoSecundario),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await abrirPagina(
                          context,
                          ClienteAgendamentoPage(nome: nome, numero: numero),
                        );
                      },
                      style: botaoPrincipal(),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text(
                        'AGENDAR HORÁRIO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _clienteMenuCard(
              context,
              Icons.calendar_month_outlined,
              'Meus agendamentos',
              'Veja, remarque ou cancele seus horários.',
              () => abrirPagina(context, const ClienteAgendamentosPage()),
            ),
            _clienteMenuCard(
              context,
              Icons.history,
              'Meu histórico',
              'Consulte seus atendimentos anteriores.',
              () => abrirPagina(context, const ClienteHistoricoPage()),
            ),
            _clienteMenuCard(
              context,
              Icons.person_outline,
              'Meu perfil',
              'Atualize seus dados e sua senha.',
              () => abrirPagina(context, const ClientePerfilPage()),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF303030)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: corTextoSecundario, size: 19),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seus agendamentos ficam vinculados à sua conta.',
                      style: TextStyle(color: corTextoSecundario, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clienteMenuCard(
    BuildContext context,
    IconData icone,
    String titulo,
    String subtitulo,
    VoidCallback onTap,
  ) {
    return Card(
      color: corCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        leading: CircleAvatar(
          backgroundColor: corAzul.withOpacity(.12),
          child: Icon(icone, color: corAzul),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(subtitulo),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ======================================================
// CLIENTE - MEUS AGENDAMENTOS
// ======================================================

class ClienteAgendamentosPage extends StatefulWidget {
  const ClienteAgendamentosPage({super.key});

  @override
  State<ClienteAgendamentosPage> createState() =>
      _ClienteAgendamentosPageState();
}

class _ClienteAgendamentosPageState extends State<ClienteAgendamentosPage> {
  List<dynamic> agendamentos = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  String dataTela(String data) {
    if (data.length < 10) return data;
    final p = data.split('-');
    if (p.length != 3) return data;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  String dinheiro(dynamic valor) {
    final n = double.tryParse(valor.toString()) ?? 0;
    return 'R\$ ${n.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Color corStatus(String status) {
    if (status == 'Cancelado') return Colors.redAccent;
    if (status == 'Finalizado') return Colors.greenAccent;
    return corAzul;
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final resposta = await http.get(
        Uri.parse('$api/cliente/agendamentos'),
        headers: headersCliente(),
      );
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        setState(() => agendamentos = dados is List ? dados : []);
      } else {
        dynamic dados = {};
        try {
          dados = jsonDecode(resposta.body);
        } catch (_) {}
        mostrarMensagem(
          context,
          dados['erro']?.toString() ??
              'Não foi possível carregar seus agendamentos.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> cancelar(dynamic item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: corCard,
        title: const Text('Cancelar horário?'),
        content: const Text('Esse horário será liberado para outro cliente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('VOLTAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('CANCELAR'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final resposta = await http.delete(
        Uri.parse('$api/cliente/agendamentos/${numeroInt(item['id'])}'),
        headers: headersCliente(),
      );
      if (!mounted) return;
      dynamic dados = {};
      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}
      if (resposta.statusCode == 200) {
        mostrarMensagem(context, 'Agendamento cancelado.');
        await carregar();
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível cancelar.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    }
  }

  Future<void> remarcar(dynamic item) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClienteRemarcarPage(
          agendamento: item,
          nome: clienteNomeLogado,
          numero: clienteNumeroLogado,
        ),
      ),
    );
    if (alterou == true && mounted) await carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus agendamentos'),
        actions: [
          IconButton(onPressed: carregar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        color: corAzul,
        onRefresh: carregar,
        child: carregando
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  Center(child: CircularProgressIndicator(color: corAzul)),
                ],
              )
            : agendamentos.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(22),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.event_available_outlined,
                    size: 65,
                    color: corTextoSecundario,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Você ainda não tem agendamentos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toque em AGENDAR HORÁRIO na tela anterior para marcar seu atendimento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: corTextoSecundario),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const Text(
                    'Seus horários',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Aqui aparecem os horários marcados pela sua conta.',
                    style: TextStyle(color: corTextoSecundario),
                  ),
                  const SizedBox(height: 16),
                  ...agendamentos.map((item) => _card(item)),
                ],
              ),
      ),
    );
  }

  Widget _card(dynamic item) {
    final status = (item['status'] ?? 'Confirmado').toString();
    final cor = corStatus(status);
    final fixo = numeroInt(item['fixo']) == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF303030)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (item['horario'] ?? '').toString(),
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dataTela((item['dia'] ?? '').toString()),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: cor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: cor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _linha(
            Icons.person_outline,
            'Barbeiro',
            (item['barbeiro'] ?? '').toString().toUpperCase(),
          ),
          _linha(
            Icons.content_cut,
            'Serviço',
            (item['servico'] ?? '').toString(),
          ),
          _linha(Icons.payments_outlined, 'Valor', dinheiro(item['valor'])),
          if (!fixo && status == 'Confirmado') ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => remarcar(item),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('REMARCAR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: corAzul,
                      side: const BorderSide(color: corAzul),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => cancelar(item),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('CANCELAR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _linha(IconData icone, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icone, size: 18, color: corTextoSecundario),
          const SizedBox(width: 9),
          Text('$titulo: ', style: const TextStyle(color: corTextoSecundario)),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// CLIENTE - AVALIAÇÃO
// ======================================================

class _AvaliacaoDialog extends StatefulWidget {
  final String barbeiro;

  const _AvaliacaoDialog({required this.barbeiro});

  @override
  State<_AvaliacaoDialog> createState() => _AvaliacaoDialogState();
}

class _AvaliacaoDialogState extends State<_AvaliacaoDialog> {
  final TextEditingController comentarioController = TextEditingController();
  int estrelas = 5;

  @override
  void dispose() {
    comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.barbeiro.trim().isEmpty
        ? 'BARBEIRO'
        : widget.barbeiro.trim().toUpperCase();

    return AlertDialog(
      backgroundColor: corCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      title: const Text(
        'Avalie seu atendimento',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Como foi seu atendimento com $nome?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: corTextoSecundario, fontSize: 14),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final numero = index + 1;
                return IconButton(
                  tooltip: '$numero estrela${numero == 1 ? '' : 's'}',
                  onPressed: () {
                    setState(() => estrelas = numero);
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  iconSize: 39,
                  icon: Icon(
                    numero <= estrelas
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '$estrelas de 5 estrelas',
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: comentarioController,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Comentário (opcional)',
                hintText: 'Conte o que achou do atendimento...',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 55),
                  child: Icon(Icons.chat_bubble_outline),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop({
              'estrelas': estrelas,
              'comentario': comentarioController.text.trim(),
            });
          },
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('ENVIAR'),
          style: botaoPrincipal(),
        ),
      ],
    );
  }
}

// ======================================================
// CLIENTE - HISTÓRICO
// ======================================================

class ClienteHistoricoPage extends StatefulWidget {
  const ClienteHistoricoPage({super.key});

  @override
  State<ClienteHistoricoPage> createState() => _ClienteHistoricoPageState();
}

class _ClienteHistoricoPageState extends State<ClienteHistoricoPage> {
  List<dynamic> historico = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final resposta = await http.get(
        Uri.parse('$api/cliente/historico'),
        headers: headersCliente(),
      );
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        setState(() => historico = dados is List ? dados : []);
      } else {
        dynamic dados = {};
        try {
          dados = jsonDecode(resposta.body);
        } catch (_) {}
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível carregar o histórico.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  String dataTela(String data) {
    if (data.length < 10) return data;
    final p = data.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : data;
  }

  Future<void> avaliar(dynamic item) async {
    final dados = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _AvaliacaoDialog(barbeiro: (item['barbeiro'] ?? '').toString()),
    );

    if (dados == null || !mounted) return;

    try {
      final resposta = await http.post(
        Uri.parse('$api/cliente/avaliar'),
        headers: headersCliente(json: true),
        body: jsonEncode({
          'agendamento_id': numeroInt(item['id']),
          'estrelas': dados['estrelas'],
          'comentario': dados['comentario'],
        }),
      );

      dynamic retorno = {};
      try {
        retorno = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(context, 'Obrigado pela avaliação! ⭐');
        await carregar();
      } else {
        mostrarMensagem(
          context,
          retorno['erro']?.toString() ?? 'Não foi possível enviar a avaliação.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu histórico'),
        actions: [
          IconButton(onPressed: carregar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: corAzul))
          : historico.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Text(
                  'Nenhum atendimento no histórico ainda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: corTextoSecundario, fontSize: 16),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: historico.length,
              itemBuilder: (context, index) {
                final item = historico[index];
                final status = (item['status'] ?? '').toString();
                final cor = status == 'Cancelado'
                    ? Colors.redAccent
                    : Colors.greenAccent;
                final valor = double.tryParse(item['valor'].toString()) ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: corCard,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFF303030)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: cor.withOpacity(.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          status == 'Cancelado'
                              ? Icons.event_busy_outlined
                              : Icons.check_circle_outline,
                          color: cor,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dataTela((item['dia'] ?? '').toString()),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item['horario'] ?? ''} • ${item['servico'] ?? ''}',
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (item['barbeiro'] ?? '').toString().toUpperCase(),
                              style: const TextStyle(
                                color: corTextoSecundario,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              color: cor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (status.trim().toLowerCase() == 'finalizado') ...[
                            const SizedBox(height: 8),
                            if (numeroInt(item['avaliado']) == 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(.35),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'AVALIADO',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () => avaliar(item),
                                icon: const Icon(Icons.star_outline, size: 17),
                                label: const Text(
                                  'AVALIAR ATENDIMENTO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: corAzul,
                                  side: const BorderSide(color: corAzul),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ======================================================
// CLIENTE - PERFIL
// ======================================================

class ClientePerfilPage extends StatefulWidget {
  const ClientePerfilPage({super.key});

  @override
  State<ClientePerfilPage> createState() => _ClientePerfilPageState();
}

class _ClientePerfilPageState extends State<ClientePerfilPage> {
  late final TextEditingController nomeController;
  late final TextEditingController numeroController;
  late final TextEditingController emailController;
  final senhaAtualController = TextEditingController();
  final novaSenhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();
  bool salvando = false;
  bool alterandoSenha = false;
  bool mostrarSenha = false;

  @override
  void initState() {
    super.initState();
    nomeController = TextEditingController(text: clienteNomeLogado);
    numeroController = TextEditingController(text: clienteNumeroLogado);
    emailController = TextEditingController(text: clienteEmailLogado);
  }

  @override
  void dispose() {
    nomeController.dispose();
    numeroController.dispose();
    emailController.dispose();
    senhaAtualController.dispose();
    novaSenhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> salvarPerfil() async {
    final nome = nomeController.text.trim();
    final numero = numeroController.text.trim();
    final email = emailController.text.trim();
    if (nome.isEmpty || email.isEmpty || !email.contains('@')) {
      mostrarMensagem(context, 'Informe nome e e-mail válidos.', erro: true);
      return;
    }
    setState(() => salvando = true);
    try {
      final resposta = await http.put(
        Uri.parse('$api/cliente/me'),
        headers: headersCliente(json: true),
        body: jsonEncode({'nome': nome, 'numero': numero, 'email': email}),
      );
      dynamic dados = {};
      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        clienteNomeLogado = nome;
        clienteNumeroLogado = numero;
        clienteEmailLogado = email;
        mostrarMensagem(context, 'Perfil atualizado!');
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível atualizar o perfil.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> alterarSenha() async {
    final atual = senhaAtualController.text;
    final nova = novaSenhaController.text;
    final confirmar = confirmarSenhaController.text;
    if (atual.isEmpty || nova.isEmpty || confirmar.isEmpty) {
      mostrarMensagem(
        context,
        'Preencha todos os campos da senha.',
        erro: true,
      );
      return;
    }
    if (nova.length < 6) {
      mostrarMensagem(
        context,
        'A nova senha precisa ter pelo menos 6 caracteres.',
        erro: true,
      );
      return;
    }
    if (nova != confirmar) {
      mostrarMensagem(context, 'As novas senhas não coincidem.', erro: true);
      return;
    }
    setState(() => alterandoSenha = true);
    try {
      final resposta = await http.put(
        Uri.parse('$api/cliente/alterar-senha'),
        headers: headersCliente(json: true),
        body: jsonEncode({
          'senhaAtual': atual,
          'novaSenha': nova,
          'confirmarSenha': confirmar,
        }),
      );
      dynamic dados = {};
      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        senhaAtualController.clear();
        novaSenhaController.clear();
        confirmarSenhaController.clear();
        mostrarMensagem(context, 'Senha alterada com sucesso!');
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível alterar a senha.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    } finally {
      if (mounted) setState(() => alterandoSenha = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: corAzul.withOpacity(.12),
                shape: BoxShape.circle,
                border: Border.all(color: corAzul.withOpacity(.35)),
              ),
              child: const Icon(Icons.person, color: corAzul, size: 42),
            ),
          ),
          const SizedBox(height: 15),
          const Center(
            child: Text(
              'Dados pessoais',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nomeController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: numeroController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 53,
            child: ElevatedButton.icon(
              onPressed: salvando ? null : salvarPerfil,
              style: botaoPrincipal(),
              icon: salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                salvando ? 'SALVANDO...' : 'SALVAR PERFIL',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Divider(color: Color(0xFF333333)),
          const SizedBox(height: 22),
          const Text(
            'Alterar senha',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'Use sua senha atual para definir uma nova.',
            style: TextStyle(color: corTextoSecundario),
          ),
          const SizedBox(height: 17),
          TextField(
            controller: senhaAtualController,
            obscureText: !mostrarSenha,
            decoration: InputDecoration(
              labelText: 'Senha atual',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => mostrarSenha = !mostrarSenha),
                icon: Icon(
                  mostrarSenha
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: novaSenhaController,
            obscureText: !mostrarSenha,
            decoration: const InputDecoration(
              labelText: 'Nova senha',
              prefixIcon: Icon(Icons.password_outlined),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: confirmarSenhaController,
            obscureText: !mostrarSenha,
            decoration: const InputDecoration(
              labelText: 'Confirmar nova senha',
              prefixIcon: Icon(Icons.password_outlined),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 53,
            child: OutlinedButton.icon(
              onPressed: alterandoSenha ? null : alterarSenha,
              icon: alterandoSenha
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: corAzul,
                      ),
                    )
                  : const Icon(Icons.lock_reset),
              label: Text(
                alterandoSenha ? 'ALTERANDO...' : 'ALTERAR SENHA',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// CLIENTE - REMARCAR
// ======================================================

class ClienteRemarcarPage extends StatefulWidget {
  final dynamic agendamento;
  final String nome;
  final String numero;

  const ClienteRemarcarPage({
    super.key,
    required this.agendamento,
    required this.nome,
    required this.numero,
  });

  @override
  State<ClienteRemarcarPage> createState() => _ClienteRemarcarPageState();
}

class _ClienteRemarcarPageState extends State<ClienteRemarcarPage> {
  late String barbeiroSelecionado;
  late String servicoSelecionado;
  DateTime? dataSelecionada;
  String? horarioSelecionado;
  List<String> horariosLivres = [];
  bool carregando = false;
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    barbeiroSelecionado = (widget.agendamento['barbeiro'] ?? 'guel')
        .toString()
        .toLowerCase();
    servicoSelecionado = (widget.agendamento['servico'] ?? 'Corte').toString();
    final data = (widget.agendamento['dia'] ?? '').toString();
    if (data.length >= 10) {
      final p = data.substring(0, 10).split('-');
      if (p.length == 3) {
        dataSelecionada = DateTime.tryParse('${p[0]}-${p[1]}-${p[2]}');
      }
    }
    carregarHorarios();
  }

  String formatarDataBackend(DateTime data) {
    return '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
  }

  String formatarDataTela(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  bool trabalha(DateTime data) {
    if (barbeiroSelecionado == 'gustavo')
      return data.weekday == DateTime.saturday;
    return data.weekday >= DateTime.wednesday &&
        data.weekday <= DateTime.saturday;
  }

  Future<void> escolherData() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    var inicial = dataSelecionada ?? hoje;
    if (inicial.isBefore(hoje)) inicial = hoje;
    while (!trabalha(inicial)) inicial = inicial.add(const Duration(days: 1));

    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: hoje,
      lastDate: DateTime(agora.year + 2),
      selectableDayPredicate: trabalha,
      helpText: 'Escolha a nova data',
      cancelText: 'CANCELAR',
      confirmText: 'SELECIONAR',
    );
    if (escolhida == null) return;
    setState(() {
      dataSelecionada = escolhida;
      horarioSelecionado = null;
      horariosLivres = [];
    });
    await carregarHorarios();
  }

  Future<void> carregarHorarios() async {
    if (dataSelecionada == null) return;
    setState(() {
      carregando = true;
      horarioSelecionado = null;
    });
    try {
      final resposta = await http.get(
        Uri.parse(
          '$api/horarios-livres/${formatarDataBackend(dataSelecionada!)}/$barbeiroSelecionado',
        ),
      );
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        var lista = (dados as List).map((e) => e.toString()).toList();
        final agora = DateTime.now();
        final hoje = DateTime(agora.year, agora.month, agora.day);
        final selecionada = DateTime(
          dataSelecionada!.year,
          dataSelecionada!.month,
          dataSelecionada!.day,
        );
        if (selecionada == hoje) {
          final minutosAgora = agora.hour * 60 + agora.minute;
          lista = lista.where((h) {
            final p = h.split(':');
            final minutos =
                (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
            return minutos > minutosAgora;
          }).toList();
        }
        setState(() {
          horariosLivres = lista;
          horarioSelecionado = lista.isNotEmpty ? lista.first : null;
        });
      } else {
        mostrarMensagem(
          context,
          'Não foi possível carregar os horários.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  double get valorServico => servicoSelecionado == 'Corte + Barba' ? 50 : 30;

  Future<void> confirmar() async {
    if (dataSelecionada == null || horarioSelecionado == null) {
      mostrarMensagem(context, 'Escolha data e horário.', erro: true);
      return;
    }
    setState(() => salvando = true);
    try {
      final resposta = await http.put(
        Uri.parse(
          '$api/cliente/agendamentos/${numeroInt(widget.agendamento['id'])}',
        ),
        headers: headersCliente(json: true),
        body: jsonEncode({
          'dia': formatarDataBackend(dataSelecionada!),
          'horario': horarioSelecionado,
          'barbeiro': barbeiroSelecionado,
          'servico': servicoSelecionado,
          'valor': valorServico,
        }),
      );
      dynamic dados = {};
      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Remarcado!'),
              ],
            ),
            content: Text(
              'Seu novo horário:\n\n${formatarDataTela(dataSelecionada!)} às $horarioSelecionado\n${barbeiroSelecionado.toUpperCase()}\n$servicoSelecionado',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível remarcar.',
          erro: true,
        );
        await carregarHorarios();
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remarcar horário')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Escolha o novo horário',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'O horário antigo só muda depois da confirmação.',
            style: TextStyle(color: corTextoSecundario),
          ),
          const SizedBox(height: 24),
          const Text(
            'Barbeiro',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _opcao('guel', 'Guel')),
              const SizedBox(width: 10),
              Expanded(child: _opcao('gustavo', 'Gustavo')),
            ],
          ),
          const SizedBox(height: 23),
          const Text(
            'Serviço',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _servico('Corte', 30)),
              const SizedBox(width: 10),
              Expanded(child: _servico('Corte + Barba', 50)),
            ],
          ),
          const SizedBox(height: 23),
          const Text(
            'Nova data',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: escolherData,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: corCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: corAzul),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: corAzul),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dataSelecionada == null
                          ? 'Selecionar data'
                          : formatarDataTela(dataSelecionada!),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: corTextoSecundario),
                ],
              ),
            ),
          ),
          const SizedBox(height: 23),
          const Text(
            'Novo horário',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (carregando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: CircularProgressIndicator(color: corAzul),
              ),
            )
          else if (dataSelecionada == null)
            const Text(
              'Escolha uma data.',
              style: TextStyle(color: corTextoSecundario),
            )
          else if (horariosLivres.isEmpty)
            const Text(
              'Não há horários livres nesta data.',
              style: TextStyle(color: corTextoSecundario),
            )
          else
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: horariosLivres.map((h) {
                final selecionado = h == horarioSelecionado;
                return ChoiceChip(
                  label: Text(
                    h,
                    style: TextStyle(
                      color: selecionado ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: selecionado,
                  selectedColor: corAzul,
                  backgroundColor: corCard,
                  onSelected: (_) => setState(() => horarioSelecionado = h),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: salvando || horarioSelecionado == null
                  ? null
                  : confirmar,
              style: botaoPrincipal(),
              icon: salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                salvando ? 'SALVANDO...' : 'CONFIRMAR NOVO HORÁRIO',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcao(String valor, String nome) {
    final selecionado = barbeiroSelecionado == valor;
    return InkWell(
      onTap: () async {
        setState(() {
          barbeiroSelecionado = valor;
          dataSelecionada = null;
          horariosLivres = [];
          horarioSelecionado = null;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: selecionado ? corAzul.withOpacity(.12) : corCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? corAzul : const Color(0xFF333333),
          ),
        ),
        child: Column(
          children: [
            Icon(
              selecionado ? Icons.check_circle : Icons.person,
              color: corAzul,
            ),
            const SizedBox(height: 6),
            Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _servico(String nome, double valor) {
    final selecionado = servicoSelecionado == nome;
    return InkWell(
      onTap: () => setState(() => servicoSelecionado = nome),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selecionado ? corAzul.withOpacity(.12) : corCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? corAzul : const Color(0xFF333333),
          ),
        ),
        child: Column(
          children: [
            Icon(
              selecionado ? Icons.check_circle : Icons.content_cut,
              color: corAzul,
            ),
            const SizedBox(height: 6),
            Text(
              nome,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(color: corTextoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// AGENDAMENTO DO CLIENTE
// ======================================================

class ClienteAgendamentoPage extends StatefulWidget {
  final String nome;
  final String numero;

  const ClienteAgendamentoPage({
    super.key,
    required this.nome,
    required this.numero,
  });

  @override
  State<ClienteAgendamentoPage> createState() => _ClienteAgendamentoPageState();
}

class _ClienteAgendamentoPageState extends State<ClienteAgendamentoPage> {
  DateTime? dataSelecionada;
  String barbeiroSelecionado = 'guel';
  String servicoSelecionado = 'Corte';
  String? horarioSelecionado;
  List<String> horariosLivres = [];
  bool carregandoHorarios = false;
  bool salvando = false;

  double get valorServico => servicoSelecionado == 'Corte + Barba' ? 50 : 30;

  String nomeBarbeiro(String barbeiro) {
    return barbeiro == 'gustavo' ? 'Gustavo' : 'Guel';
  }

  bool barbeiroTrabalha(DateTime data) {
    final dia = data.weekday;
    if (barbeiroSelecionado == 'gustavo') {
      return dia == DateTime.saturday;
    }
    if (barbeiroSelecionado == 'guel') {
      return dia >= DateTime.wednesday && dia <= DateTime.saturday;
    }
    return false;
  }

  String formatarDataBackend(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return '$ano-$mes-$dia';
  }

  String formatarDataTela(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  Future<void> escolherData() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    var inicial = hoje;
    while (!barbeiroTrabalha(inicial)) {
      inicial = inicial.add(const Duration(days: 1));
    }

    final escolhida = await showDatePicker(
      context: context,
      initialDate: dataSelecionada ?? inicial,
      firstDate: hoje,
      lastDate: DateTime(agora.year + 2),
      selectableDayPredicate: barbeiroTrabalha,
      helpText: 'Escolha a data',
      cancelText: 'CANCELAR',
      confirmText: 'SELECIONAR',
    );

    if (escolhida == null) return;

    setState(() {
      dataSelecionada = escolhida;
      horarioSelecionado = null;
      horariosLivres = [];
    });

    await carregarHorarios();
  }

  Future<void> carregarHorarios() async {
    if (dataSelecionada == null) return;

    setState(() {
      carregandoHorarios = true;
      horarioSelecionado = null;
    });

    try {
      final dia = formatarDataBackend(dataSelecionada!);
      final resposta = await http.get(
        Uri.parse('$api/horarios-livres/$dia/$barbeiroSelecionado'),
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        var lista = (dados as List).map((e) => e.toString()).toList();

        // Se for hoje, não mostra horários que já passaram.
        final agora = DateTime.now();
        final hoje = DateTime(agora.year, agora.month, agora.day);
        final selecionada = DateTime(
          dataSelecionada!.year,
          dataSelecionada!.month,
          dataSelecionada!.day,
        );

        if (selecionada == hoje) {
          final minutosAgora = agora.hour * 60 + agora.minute;
          lista = lista.where((horario) {
            final partes = horario.split(':');
            if (partes.length != 2) return true;
            final minutos =
                (int.tryParse(partes[0]) ?? 0) * 60 +
                (int.tryParse(partes[1]) ?? 0);
            return minutos > minutosAgora;
          }).toList();
        }

        setState(() {
          horariosLivres = lista;
          horarioSelecionado = lista.isEmpty ? null : lista.first;
        });
      } else {
        dynamic dados = {};
        try {
          dados = jsonDecode(resposta.body);
        } catch (_) {}

        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível carregar os horários.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregandoHorarios = false);
      }
    }
  }

  Future<void> confirmarAgendamento() async {
    if (dataSelecionada == null) {
      mostrarMensagem(context, 'Escolha uma data.', erro: true);
      return;
    }

    if (horarioSelecionado == null) {
      mostrarMensagem(context, 'Escolha um horário disponível.', erro: true);
      return;
    }

    setState(() => salvando = true);

    try {
      final resposta = await http.post(
        Uri.parse('$api/cliente/agendar'),
        headers: headersCliente(json: true),
        body: jsonEncode({
          'nome': widget.nome,
          'numero': widget.numero,
          'dia': formatarDataBackend(dataSelecionada!),
          'horario': horarioSelecionado,
          'barbeiro': barbeiroSelecionado,
          'servico': servicoSelecionado,
          'valor': valorServico,
        }),
      );

      dynamic dados = {};
      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Agendado!'),
                ],
              ),
              content: Text(
                '${servicoSelecionado}\n'
                '${nomeBarbeiro(barbeiroSelecionado)}\n'
                '${formatarDataTela(dataSelecionada!)} às $horarioSelecionado\n\n'
                'Seu horário foi reservado com sucesso.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );

        if (mounted) Navigator.pop(context, true);
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível criar o agendamento.',
          erro: true,
        );
        await carregarHorarios();
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar horário')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: logoGBarber(tamanho: 85, mostrarNome: false)),
            const SizedBox(height: 10),
            const Text(
              'Escolha seu horário',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'Olá, ${widget.nome}. Escolha barbeiro, serviço, data e horário.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: corTextoSecundario),
            ),
            const SizedBox(height: 25),

            const Text(
              '1. Escolha o barbeiro',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _opcaoBarbeiro('guel', 'Guel', Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: _opcaoBarbeiro('gustavo', 'Gustavo', Icons.person),
                ),
              ],
            ),

            const SizedBox(height: 25),
            const Text(
              '2. Escolha o serviço',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _opcaoServico('Corte', 30)),
                const SizedBox(width: 12),
                Expanded(child: _opcaoServico('Corte + Barba', 50)),
              ],
            ),

            const SizedBox(height: 25),
            const Text(
              '3. Escolha a data',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: escolherData,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: corCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: dataSelecionada == null
                        ? const Color(0xFF333333)
                        : corAzul,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: corAzul),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dataSelecionada == null
                            ? 'Selecionar data'
                            : formatarDataTela(dataSelecionada!),
                        style: TextStyle(
                          fontSize: 16,
                          color: dataSelecionada == null
                              ? corTextoSecundario
                              : Colors.white,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: corTextoSecundario),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            const Text(
              '4. Escolha o horário',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (carregandoHorarios)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Center(child: CircularProgressIndicator(color: corAzul)),
              )
            else if (dataSelecionada == null)
              _avisoAgenda(
                Icons.touch_app_outlined,
                'Escolha uma data para ver os horários disponíveis.',
              )
            else if (horariosLivres.isEmpty)
              _avisoAgenda(
                Icons.event_busy_outlined,
                'Não há horários disponíveis nesta data.',
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: horariosLivres.map((horario) {
                  final selecionado = horarioSelecionado == horario;
                  return ChoiceChip(
                    label: Text(
                      horario,
                      style: TextStyle(
                        color: selecionado ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: selecionado,
                    selectedColor: corAzul,
                    backgroundColor: corCard,
                    side: BorderSide(
                      color: selecionado ? corAzul : const Color(0xFF333333),
                    ),
                    onSelected: (_) {
                      setState(() => horarioSelecionado = horario);
                    },
                  );
                }).toList(),
              ),

            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: corCard,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: corAzul),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Valor do serviço',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    'R\$ ${valorServico.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      color: corAzul,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: salvando || horarioSelecionado == null
                    ? null
                    : confirmarAgendamento,
                style: botaoPrincipal(),
                icon: salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  salvando ? 'CONFIRMANDO...' : 'CONFIRMAR AGENDAMENTO',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'O horário só será confirmado se ainda estiver disponível no servidor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: corTextoSecundario, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcaoBarbeiro(String valor, String nome, IconData icone) {
    final selecionado = barbeiroSelecionado == valor;
    return InkWell(
      onTap: () async {
        setState(() {
          barbeiroSelecionado = valor;
          dataSelecionada = null;
          horariosLivres = [];
          horarioSelecionado = null;
        });
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
        decoration: BoxDecoration(
          color: selecionado ? corAzul.withOpacity(.12) : corCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selecionado ? corAzul : const Color(0xFF333333),
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              selecionado ? Icons.check_circle : icone,
              color: corAzul,
              size: 28,
            ),
            const SizedBox(height: 7),
            Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _opcaoServico(String nome, double valor) {
    final selecionado = servicoSelecionado == nome;
    return InkWell(
      onTap: () => setState(() => servicoSelecionado = nome),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: selecionado ? corAzul.withOpacity(.12) : corCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selecionado ? corAzul : const Color(0xFF333333),
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              selecionado ? Icons.check_circle : Icons.content_cut,
              color: corAzul,
            ),
            const SizedBox(height: 7),
            Text(
              nome,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(color: corTextoSecundario),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avisoAgenda(IconData icone, String texto) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        children: [
          Icon(icone, color: corTextoSecundario),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: corTextoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final nomeController = TextEditingController();
  final usuarioController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarController = TextEditingController();

  bool carregando = false;
  bool mostrarSenha = false;

  Future<void> cadastrar() async {
    final nome = nomeController.text.trim();
    final usuario = usuarioController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text;
    final confirmarSenha = confirmarController.text;

    if (nome.isEmpty ||
        usuario.isEmpty ||
        email.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty) {
      mostrarMensagem(context, 'Preencha todos os campos.', erro: true);
      return;
    }

    if (senha != confirmarSenha) {
      mostrarMensagem(context, 'As senhas não coincidem.', erro: true);
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('$api/app/cadastrar-barbeiro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'usuario': usuario,
          'email': email,
          'senha': senha,
          'confirmarSenha': confirmarSenha,
        }),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(context, 'Conta criada com sucesso!');

        await Future.delayed(const Duration(milliseconds: 700));

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Erro ao cadastrar.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    usuarioController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  logoGBarber(tamanho: 110, mostrarNome: false),

                  const SizedBox(height: 25),

                  const Text(
                    'Cadastro',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    controller: nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: usuarioController,
                    decoration: const InputDecoration(
                      labelText: 'Usuário',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: senhaController,
                    obscureText: !mostrarSenha,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            mostrarSenha = !mostrarSenha;
                          });
                        },
                        icon: Icon(
                          mostrarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: confirmarController,
                    obscureText: !mostrarSenha,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar senha',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: carregando ? null : cadastrar,
                      style: botaoPrincipal(),
                      child: carregando
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'CADASTRAR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
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

// ======================================================
// ESQUECI SENHA
// ======================================================

class EsqueciSenhaPage extends StatefulWidget {
  const EsqueciSenhaPage({super.key});

  @override
  State<EsqueciSenhaPage> createState() => _EsqueciSenhaPageState();
}

class _EsqueciSenhaPageState extends State<EsqueciSenhaPage> {
  final emailController = TextEditingController();

  bool carregando = false;

  Future<void> enviarCodigo() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      mostrarMensagem(context, 'Digite seu e-mail cadastrado.', erro: true);
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('$api/app/esqueci-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(context, 'Código enviado para seu e-mail.');

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RedefinirSenhaPage(email: email)),
        );
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível enviar o código.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  logoGBarber(tamanho: 110, mostrarNome: false),

                  const SizedBox(height: 25),

                  const Text(
                    'Recuperar senha',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Digite o e-mail usado no seu cadastro.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: corTextoSecundario),
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail cadastrado',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: carregando ? null : enviarCodigo,
                      style: botaoPrincipal(),
                      child: carregando
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'ENVIAR CÓDIGO',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
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

// ======================================================
// REDEFINIR SENHA
// ======================================================

class RedefinirSenhaPage extends StatefulWidget {
  final String email;

  const RedefinirSenhaPage({super.key, required this.email});

  @override
  State<RedefinirSenhaPage> createState() => _RedefinirSenhaPageState();
}

class _RedefinirSenhaPageState extends State<RedefinirSenhaPage> {
  final codigoController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarController = TextEditingController();

  bool carregando = false;
  bool mostrarSenha = false;

  Future<void> redefinir() async {
    final codigo = codigoController.text.trim();
    final novaSenha = senhaController.text;
    final confirmarSenha = confirmarController.text;

    if (codigo.isEmpty || novaSenha.isEmpty || confirmarSenha.isEmpty) {
      mostrarMensagem(context, 'Preencha todos os campos.', erro: true);
      return;
    }

    if (novaSenha != confirmarSenha) {
      mostrarMensagem(context, 'As senhas não coincidem.', erro: true);
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('$api/app/redefinir-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'codigo': codigo,
          'novaSenha': novaSenha,
          'confirmarSenha': confirmarSenha,
        }),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(context, 'Senha alterada com sucesso!');

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Erro ao redefinir senha.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    codigoController.dispose();
    senhaController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova senha')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  logoGBarber(tamanho: 100, mostrarNome: false),

                  const SizedBox(height: 25),

                  const Text(
                    'Crie sua nova senha',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(widget.email, style: const TextStyle(color: corAzul)),

                  const SizedBox(height: 30),

                  TextField(
                    controller: codigoController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: const TextStyle(fontSize: 23, letterSpacing: 7),
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: senhaController,
                    obscureText: !mostrarSenha,
                    decoration: InputDecoration(
                      labelText: 'Nova senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            mostrarSenha = !mostrarSenha;
                          });
                        },
                        icon: Icon(
                          mostrarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: confirmarController,
                    obscureText: !mostrarSenha,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar nova senha',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: carregando ? null : redefinir,
                      style: botaoPrincipal(),
                      child: carregando
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'ALTERAR SENHA',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
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
// ======================================================
// PAINEL
// ======================================================

class PainelBarbeiro extends StatefulWidget {
  final String barbeiro;
  final String nome;

  const PainelBarbeiro({super.key, required this.barbeiro, required this.nome});

  @override
  State<PainelBarbeiro> createState() => _PainelBarbeiroState();
}

class _PainelBarbeiroState extends State<PainelBarbeiro> {
  String formatarDataBackend(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return '$ano-$mes-$dia';
  }

  List<dynamic> hoje = [];
  List<dynamic> semana = [];
  List<dynamic> agendaSelecionada = [];
  List<dynamic> fixos = [];
  List<dynamic> bloqueios = [];
  List<dynamic> historico = [];
  List<dynamic> clientes = [];

  final TextEditingController pesquisaHistoricoController =
      TextEditingController();
  final TextEditingController pesquisaClientesController =
      TextEditingController();
  String? dataFiltroHistorico;

  // Data atualmente selecionada na Agenda.
  DateTime dataAgendaSelecionada = DateTime.now();

  int total = 0;

  double previsto = 0;
  double recebido = 0;
  double pendente = 0;

  int pagina = 0;

  bool carregando = true;

  String nomePainel = '';
  String fotoPerfilBase64 = '';

  Timer? timer;
  StreamSubscription<String>? tokenRefreshSubscription;

  @override
  void initState() {
    super.initState();

    nomePainel = widget.nome;

    carregarTudo();

    registrarTokenPush(widget.barbeiro);

    tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        try {
          await http.post(
            Uri.parse('$api/app/push-token'),
            headers: headersAutenticados(json: true),
            body: jsonEncode({'barbeiro': widget.barbeiro, 'token': token}),
          );
        } catch (e) {
          debugPrint('Erro ao atualizar token push: $e');
        }
      },
    );

    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      carregarTudo(exibirLoading: false);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    tokenRefreshSubscription?.cancel();
    pesquisaHistoricoController.dispose();
    pesquisaClientesController.dispose();
    super.dispose();
  }

  Future<void> carregarAgendaSelecionada({bool exibirLoading = false}) async {
    final dia = formatarDataBackend(dataAgendaSelecionada);

    try {
      final resposta = await http.get(
        Uri.parse('$api/app/agendamentos-dia/${widget.barbeiro}/$dia'),
        headers: headersAutenticados(),
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        setState(() {
          agendaSelecionada = dados is List ? dados : [];
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar agenda do dia: $e');
    }
  }

  Future<void> carregarTudo({bool exibirLoading = true}) async {
    if (exibirLoading && mounted) {
      setState(() {
        carregando = true;
      });
    }

    try {
      final respostas = await Future.wait([
        http.get(
          Uri.parse('$api/app/agendamentos-hoje/${widget.barbeiro}'),
          headers: headersAutenticados(),
        ),
        http.get(
          Uri.parse('$api/app/agendamentos-semana/${widget.barbeiro}'),
          headers: headersAutenticados(),
        ),
        http.get(
          Uri.parse(
            '$api/app/agendamentos-dia/${widget.barbeiro}/${formatarDataBackend(dataAgendaSelecionada)}',
          ),
          headers: headersAutenticados(),
        ),
        http.get(
          Uri.parse('$api/app/resumo-hoje/${widget.barbeiro}'),
          headers: headersAutenticados(),
        ),
        http.get(
          Uri.parse('$api/app/fixos/${widget.barbeiro}'),
          headers: headersAutenticados(),
        ),
        http.get(
          Uri.parse('$api/app/bloqueios/${widget.barbeiro}'),
          headers: headersAutenticados(),
        ),
        http.get(
          Uri.parse('$api/app/historico/${widget.barbeiro}'),
          headers: headersAutenticados(),
        ),
        http.get(
          Uri.parse('$api/app/clientes/${widget.barbeiro}'),
          headers: headersAutenticados(),
        ),
        http.get(
          Uri.parse('$api/app/perfil/${widget.barbeiro}'),
          headers: headersAutenticados(),
        ),
      ]);

      if (!mounted) return;

      if (respostas[0].statusCode == 200) {
        hoje = jsonDecode(respostas[0].body);
      }

      if (respostas[1].statusCode == 200) {
        semana = jsonDecode(respostas[1].body);
      }

      if (respostas[2].statusCode == 200) {
        final dadosAgenda = jsonDecode(respostas[2].body);
        agendaSelecionada = dadosAgenda is List ? dadosAgenda : [];
      }

      if (respostas[3].statusCode == 200) {
        final resumo = jsonDecode(respostas[3].body);

        total = numeroInt(resumo['total']);
        previsto = numeroDouble(resumo['previsto']);
        recebido = numeroDouble(resumo['recebido']);
        pendente = numeroDouble(resumo['pendente']);
      }

      if (respostas[4].statusCode == 200) {
        fixos = jsonDecode(respostas[4].body);
      }

      if (respostas[5].statusCode == 200) {
        bloqueios = jsonDecode(respostas[5].body);
      }

      if (respostas[6].statusCode == 200) {
        historico = jsonDecode(respostas[6].body);
      }

      if (respostas[7].statusCode == 200) {
        clientes = jsonDecode(respostas[7].body);
      }

      if (respostas[8].statusCode == 200) {
        final perfil = jsonDecode(respostas[8].body);

        nomePainel = (perfil['nome'] ?? widget.nome).toString().trim();

        if (nomePainel.isEmpty) {
          nomePainel = widget.nome;
        }

        fotoPerfilBase64 = (perfil['foto'] ?? '').toString();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        carregando = false;
      });
    }
  }

  // ====================================================
  // FINALIZAR AGENDAMENTO
  // ====================================================

  Future<void> finalizar(int id) async {
    try {
      final resposta = await http.put(
        Uri.parse('$api/finalizar/$id'),
        headers: headersAutenticados(),
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(context, 'Agendamento finalizado!');

        await carregarTudo();
      } else {
        mostrarMensagem(context, 'Não foi possível finalizar.', erro: true);
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    }
  }

  // ====================================================
  // CANCELAR AGENDAMENTO
  // ====================================================

  Future<void> cancelar(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: corCard,
          title: const Text('Cancelar agendamento'),
          content: const Text('Deseja realmente cancelar este agendamento?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'VOLTAR',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      final resposta = await http.delete(
        Uri.parse('$api/cancelar/$id'),
        headers: headersAutenticados(),
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(context, 'Agendamento cancelado.');

        await carregarTudo();
      } else {
        mostrarMensagem(context, 'Não foi possível cancelar.', erro: true);
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    }
  }

  // ====================================================
  // EXCLUIR FIXO
  // ====================================================

  Future<void> excluirFixo(dynamic item) async {
    final id = numeroInt(item['id']);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: corCard,
          title: const Text('Excluir horário fixo'),
          content: Text(
            'Excluir o horário fixo de '
            '${(item['nome'] ?? '').toString()}?\n\n'
            '${nomeDiaSemana(numeroInt(item['dia_semana']))} '
            'às ${(item['horario'] ?? '').toString()}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('VOLTAR'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('EXCLUIR'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      final resposta = await http.delete(
        Uri.parse('$api/app/fixos/$id'),
        headers: headersAutenticados(),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(
          context,
          dados['mensagem']?.toString() ?? 'Horário fixo excluído.',
        );

        await carregarTudo();
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Erro ao excluir horário fixo.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    }
  }

  // ====================================================
  // EXCLUIR BLOQUEIO
  // ====================================================

  Future<void> excluirBloqueio(dynamic item) async {
    final id = numeroInt(item['id']);

    final diaInteiro = numeroInt(item['dia_inteiro']) == 1;

    final dia = (item['dia'] ?? '').toString();
    final horario = (item['horario'] ?? '').toString();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: corCard,
          title: const Text('Remover bloqueio'),
          content: Text(
            diaInteiro
                ? 'Deseja desbloquear o dia ${formatarData(dia)} inteiro?'
                : 'Deseja desbloquear ${formatarData(dia)} às $horario?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('VOLTAR'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('DESBLOQUEAR'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      final resposta = await http.delete(
        Uri.parse('$api/app/bloqueios/$id'),
        headers: headersAutenticados(),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(
          context,
          dados['mensagem']?.toString() ?? 'Bloqueio removido.',
        );

        await carregarTudo();
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível remover o bloqueio.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    }
  }

  // ====================================================
  // ABRIR CADASTRO FIXO
  // ====================================================

  Future<void> abrirCadastroFixo() async {
    final cadastrado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CadastroFixoPage(
          barbeiro: widget.barbeiro,
          nomeBarbeiro: widget.nome,
        ),
      ),
    );

    if (cadastrado == true) {
      await carregarTudo();
    }
  }

  // ====================================================
  // ABRIR CADASTRO BLOQUEIO
  // ====================================================

  Future<void> abrirCadastroBloqueio() async {
    final cadastrado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CadastroBloqueioPage(
          barbeiro: widget.barbeiro,
          nomeBarbeiro: widget.nome,
        ),
      ),
    );

    if (cadastrado == true) {
      await carregarTudo();
    }
  }

  // ====================================================
  // DASHBOARD / TELA HOJE
  // ====================================================

  Future<void> abrirNovoAgendamento() async {
    final cadastrado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NovoAgendamentoPage(
          barbeiro: widget.barbeiro,
          nomeBarbeiro: nomePainel.isEmpty ? widget.nome : nomePainel,
        ),
      ),
    );

    if (cadastrado == true && mounted) {
      await carregarTudo(exibirLoading: false);
    }
  }

  String dataHojeTexto() {
    final agora = DateTime.now();

    const dias = [
      'segunda-feira',
      'terça-feira',
      'quarta-feira',
      'quinta-feira',
      'sexta-feira',
      'sábado',
      'domingo',
    ];

    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    return '${dias[agora.weekday - 1]}, ${agora.day} de ${meses[agora.month - 1]}';
  }

  int minutosDoHorario(String horario) {
    final partes = horario.split(':');

    if (partes.length != 2) {
      return 99999;
    }

    final hora = int.tryParse(partes[0]) ?? 99;
    final minuto = int.tryParse(partes[1]) ?? 99;

    return (hora * 60) + minuto;
  }

  bool agendamentoCancelado(dynamic item) {
    return (item['status'] ?? '').toString().toLowerCase() == 'cancelado';
  }

  bool agendamentoFinalizado(dynamic item) {
    return (item['status'] ?? '').toString().toLowerCase() == 'finalizado';
  }

  List<dynamic> agendamentosHojeOrdenados() {
    final lista = List<dynamic>.from(hoje);

    lista.sort((a, b) {
      final horarioA = (a['horario'] ?? '').toString();
      final horarioB = (b['horario'] ?? '').toString();

      return minutosDoHorario(horarioA).compareTo(minutosDoHorario(horarioB));
    });

    return lista;
  }

  dynamic proximoAgendamentoHoje() {
    final lista = agendamentosHojeOrdenados()
        .where(
          (item) => !agendamentoFinalizado(item) && !agendamentoCancelado(item),
        )
        .toList();

    if (lista.isEmpty) {
      return null;
    }

    final agora = DateTime.now();
    final minutosAgora = (agora.hour * 60) + agora.minute;

    for (final item in lista) {
      final horario = (item['horario'] ?? '').toString();

      if (minutosDoHorario(horario) >= minutosAgora) {
        return item;
      }
    }

    // Se ainda existem clientes não finalizados com horário já passado,
    // mostra o primeiro deles para o barbeiro não perder o atendimento.
    return lista.first;
  }

  int atendimentosConcluidosHoje() {
    return hoje.where(agendamentoFinalizado).length;
  }

  Widget avatarBarbeiro({double tamanho = 48}) {
    Uint8List? bytes;

    if (fotoPerfilBase64.trim().isNotEmpty) {
      try {
        bytes = base64Decode(fotoPerfilBase64);
      } catch (_) {}
    }

    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: tamanho,
          height: tamanho,
          fit: BoxFit.cover,
        ),
      );
    }

    final nome = nomePainel.trim().isEmpty ? widget.nome : nomePainel.trim();
    final inicial = nome.isEmpty ? 'G' : nome[0].toUpperCase();

    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF22343D),
        shape: BoxShape.circle,
      ),
      child: Text(
        inicial,
        style: TextStyle(
          color: corAzul,
          fontSize: tamanho * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget cardProximoCliente(dynamic item) {
    final nome = (item['nome'] ?? 'Cliente').toString();
    final horario = (item['horario'] ?? '--:--').toString();
    final servico = (item['servico'] ?? 'Serviço não informado').toString();
    final numero = (item['numero'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17252C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: corAzul.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: corAzul.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'PRÓXIMO CLIENTE',
                  style: TextStyle(
                    color: corAzul,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.schedule_outlined, color: corAzul, size: 19),
              const SizedBox(width: 5),
              Text(
                horario,
                style: const TextStyle(
                  color: corAzul,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            nome,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            servico,
            style: const TextStyle(color: corTextoSecundario, fontSize: 14),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: numero.isEmpty
                      ? null
                      : () {
                          abrirWhatsApp(item);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.greenAccent,
                    side: BorderSide(
                      color: numero.isEmpty
                          ? Colors.grey.shade700
                          : Colors.greenAccent,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: Text(
                    numero.isEmpty ? 'SEM TELEFONE' : 'WHATSAPP',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: numeroInt(item['fixo']) == 1
                      ? null
                      : () {
                          editarAgendamento(item);
                        },
                  style: botaoPrincipal(),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text(
                    'REMARCAR',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====================================================
  // WHATSAPP
  // ====================================================

  Future<void> abrirWhatsApp(dynamic item) async {
    final nome = (item['nome'] ?? '').toString().trim();
    final numeroOriginal = (item['numero'] ?? '').toString().trim();
    final dia = (item['dia'] ?? '').toString().trim();
    final horario = (item['horario'] ?? '').toString().trim();

    if (numeroOriginal.isEmpty) {
      mostrarMensagem(
        context,
        'Este cliente não possui telefone cadastrado.',
        erro: true,
      );
      return;
    }

    var numero = numeroOriginal.replaceAll(RegExp(r'[^0-9]'), '');

    if (numero.startsWith('0')) {
      numero = numero.substring(1);
    }

    // Telefones brasileiros salvos sem DDI recebem o 55.
    if (!numero.startsWith('55')) {
      numero = '55$numero';
    }

    final dataTexto = dia.isEmpty ? '' : formatarData(dia);

    final mensagem = [
      'Olá${nome.isEmpty ? '' : ', $nome'}! Aqui é da G Barber Club.',
      if (dataTexto.isNotEmpty && horario.isNotEmpty)
        'Estou entrando em contato sobre seu agendamento do dia $dataTexto às $horario.',
    ].join(' ');

    final uri = Uri.parse(
      'https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}',
    );

    try {
      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!abriu && mounted) {
        mostrarMensagem(
          context,
          'Não foi possível abrir o WhatsApp.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível abrir o WhatsApp.',
        erro: true,
      );
    }
  }

  // ====================================================
  // EDITAR / REMARCAR AGENDAMENTO
  // ====================================================

  Future<void> editarAgendamento(dynamic item) async {
    if (numeroInt(item['fixo']) == 1) {
      mostrarMensagem(
        context,
        'Horários fixos são editados pela aba Fixos.',
        erro: true,
      );
      return;
    }

    final alterado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditarAgendamentoPage(agendamento: item, barbeiro: widget.barbeiro),
      ),
    );

    if (alterado == true) {
      await carregarTudo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulos = ['Hoje', 'Semana', 'Clientes', 'Mais'];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        titleSpacing: 15,
        title: Row(
          children: [
            avatarBarbeiro(tamanho: 44),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GBARBERCLUB',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    nomePainel.isEmpty ? widget.nome : nomePainel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: corAzul),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: carregarTudo, icon: const Icon(Icons.refresh)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(35),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            alignment: Alignment.centerLeft,
            child: Text(
              titulos[pagina],
              style: const TextStyle(
                color: corAzul,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: corAzul))
          : pagina == 0
          ? telaHoje()
          : pagina == 1
          ? telaSemana()
          : pagina == 2
          ? telaClientes()
          : telaMais(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF151515),
        indicatorColor: const Color(0xFF263B45),
        selectedIndex: pagina,
        onDestinationSelected: (valor) {
          setState(() {
            pagina = valor;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today, color: corAzul),
            label: 'Hoje',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: corAzul),
            label: 'Semana',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: corAzul),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz, color: corAzul),
            label: 'Mais',
          ),
        ],
      ),
    );
  }

  Widget telaMais() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Gerenciamento',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Acesse as outras ferramentas do painel.',
          style: TextStyle(color: corTextoSecundario),
        ),
        const SizedBox(height: 18),
        _opcaoMais(
          icone: Icons.person_outline,
          titulo: 'Perfil',
          subtitulo: 'Seus dados, e-mail e senha',
          aoClicar: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerfilBarbeiroPage(
                  barbeiro: widget.barbeiro,
                  nomeBarbeiro: widget.nome,
                ),
              ),
            );
          },
        ),
        _opcaoMais(
          icone: Icons.add_circle_outline,
          titulo: 'Novo agendamento',
          subtitulo: 'Agende manualmente um cliente',
          aoClicar: abrirNovoAgendamento,
        ),
        _opcaoMais(
          icone: Icons.event_repeat_outlined,
          titulo: 'Horários fixos',
          subtitulo: 'Gerencie clientes com horário semanal',
          aoClicar: () => _abrirPaginaMais('Horários fixos', telaFixos),
        ),
        _opcaoMais(
          icone: Icons.block_outlined,
          titulo: 'Bloqueios',
          subtitulo: 'Bloqueie horários ou dias da agenda',
          aoClicar: () => _abrirPaginaMais('Bloqueios', telaBloqueios),
        ),
        _opcaoMais(
          icone: Icons.history_outlined,
          titulo: 'Histórico',
          subtitulo: 'Consulte atendimentos anteriores',
          aoClicar: () => _abrirPaginaMais('Histórico', telaHistorico),
        ),
        _opcaoMais(
          icone: Icons.bar_chart_outlined,
          titulo: 'Relatórios',
          subtitulo: 'Faturamento, serviços e desempenho',
          aoClicar: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RelatoriosPage(
                  barbeiro: widget.barbeiro,
                  nomeBarbeiro: widget.nome,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _opcaoMais(
          icone: Icons.star_outline,
          titulo: 'Avaliações',
          subtitulo: 'Veja as notas e comentários dos clientes',
          aoClicar: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AvaliacoesBarbeiroPage(
                  barbeiro: widget.barbeiro,
                  nomeBarbeiro: widget.nome,
                ),
              ),
            );
          },
        ),
        _opcaoMais(
          icone: Icons.logout,
          titulo: 'Sair da conta',
          subtitulo: 'Voltar para a tela de login',
          corIcone: Colors.redAccent,
          aoClicar: () {
            authToken = '';
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _opcaoMais({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required VoidCallback aoClicar,
    Color corIcone = corAzul,
  }) {
    return Card(
      color: corCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: corIcone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icone, color: corIcone),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(color: corTextoSecundario),
        ),
        trailing: const Icon(Icons.chevron_right, color: corTextoSecundario),
        onTap: aoClicar,
      ),
    );
  }

  Future<void> _abrirPaginaMais(
    String titulo,
    Widget Function() construirTela,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(titulo)),
          body: construirTela(),
        ),
      ),
    );
    if (mounted) {
      await carregarTudo(exibirLoading: false);
    }
  }

  // ====================================================
  // TELA HOJE
  // ====================================================

  Widget telaHoje() {
    final listaHoje = agendamentosHojeOrdenados();
    final proximo = proximoAgendamentoHoje();
    final concluidos = atendimentosConcluidosHoje();

    return RefreshIndicator(
      color: corAzul,
      onRefresh: carregarTudo,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, ${nomePainel.isEmpty ? widget.nome : nomePainel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dataHojeTexto(),
                      style: const TextStyle(
                        color: corTextoSecundario,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: abrirNovoAgendamento,
                  style: botaoPrincipal(),
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text(
                    'AGENDAR',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (proximo != null) ...[
            cardProximoCliente(proximo),
            const SizedBox(height: 22),
          ],

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Resumo do dia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF183126),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$concluidos concluído${concluidos == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final largura = constraints.maxWidth;

              int colunas;
              double proporcao;

              if (largura >= 900) {
                colunas = 4;
                proporcao = 3.15;
              } else if (largura >= 600) {
                colunas = 4;
                proporcao = 2.25;
              } else {
                colunas = 2;
                proporcao = 1.9;
              }

              return GridView.count(
                crossAxisCount: colunas,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: proporcao,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  cardResumo(
                    titulo: 'Agenda',
                    valor: '$total',
                    icone: Icons.calendar_month_outlined,
                    cor: corAzul,
                  ),
                  cardResumo(
                    titulo: 'Recebido',
                    valor: dinheiro(recebido),
                    icone: Icons.check_circle_outline,
                    cor: Colors.greenAccent,
                  ),
                  cardResumo(
                    titulo: 'Pendente',
                    valor: dinheiro(pendente),
                    icone: Icons.schedule,
                    cor: Colors.orangeAccent,
                  ),
                  cardResumo(
                    titulo: 'Previsto',
                    valor: dinheiro(previsto),
                    icone: Icons.trending_up,
                    cor: corAzul,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 25),

          Row(
            children: [
              const Icon(Icons.content_cut, color: corAzul, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Agenda de hoje',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${listaHoje.length} horário${listaHoje.length == 1 ? '' : 's'}',
                style: const TextStyle(color: corTextoSecundario, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (listaHoje.isEmpty) mensagemVazia('Nenhum agendamento para hoje.'),

          ...listaHoje.map(
            (item) => cardAgendamento(
              item,
              destaqueProximo:
                  proximo != null &&
                  numeroInt(item['id']) == numeroInt(proximo['id']),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // TELA SEMANA
  // ====================================================

  Widget telaSemana() {
    final agora = DateTime.now();

    // Segunda-feira da semana atual.
    final segunda = DateTime(
      agora.year,
      agora.month,
      agora.day,
    ).subtract(Duration(days: agora.weekday - 1));

    final diasSemana = List.generate(
      7,
      (index) => segunda.add(Duration(days: index)),
    );

    final dataSelecionada = DateTime(
      dataAgendaSelecionada.year,
      dataAgendaSelecionada.month,
      dataAgendaSelecionada.day,
    );

    final dataSelecionadaTexto = formatarDataBackend(dataSelecionada);

    final agendamentosDoDia = List<dynamic>.from(agendaSelecionada);

    agendamentosDoDia.sort((a, b) {
      return minutosDoHorario(
        (a['horario'] ?? '').toString(),
      ).compareTo(minutosDoHorario((b['horario'] ?? '').toString()));
    });

    final ativos = agendamentosDoDia.where((item) {
      return !agendamentoCancelado(item) && !agendamentoFinalizado(item);
    }).length;

    final concluidos = agendamentosDoDia.where(agendamentoFinalizado).length;

    final cancelados = agendamentosDoDia.where(agendamentoCancelado).length;

    double faturamento = 0;
    for (final item in agendamentosDoDia) {
      if (agendamentoFinalizado(item)) {
        faturamento += numeroDouble(item['valor']);
      }
    }

    String nomeCurtoDia(int weekday) {
      const nomes = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
      return nomes[weekday - 1];
    }

    return RefreshIndicator(
      color: corAzul,
      onRefresh: carregarTudo,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agenda',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Organize seus atendimentos da semana',
                      style: TextStyle(color: corTextoSecundario, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: abrirNovoAgendamento,
                style: OutlinedButton.styleFrom(
                  foregroundColor: corAzul,
                  side: const BorderSide(color: corAzul),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                ),
                icon: const Icon(Icons.add, size: 19),
                label: const Text(
                  'AGENDAR',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Seletor dos dias da semana.
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: diasSemana.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final dia = diasSemana[index];

                final selecionado =
                    dia.year == dataSelecionada.year &&
                    dia.month == dataSelecionada.month &&
                    dia.day == dataSelecionada.day;

                final ehHoje =
                    dia.year == agora.year &&
                    dia.month == agora.month &&
                    dia.day == agora.day;

                final diaTexto = formatarDataBackend(dia);

                final quantidade = semana.where((item) {
                  return (item['dia'] ?? '').toString() == diaTexto &&
                      !agendamentoCancelado(item);
                }).length;

                return SizedBox(
                  width: 65,
                  child: Material(
                    color: selecionado ? corAzul : corCard,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        setState(() {
                          dataAgendaSelecionada = dia;
                        });
                        await carregarAgendaSelecionada();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 5,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              nomeCurtoDia(dia.weekday),
                              style: TextStyle(
                                color: selecionado
                                    ? Colors.black
                                    : corTextoSecundario,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${dia.day}',
                              style: TextStyle(
                                color: selecionado
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (ehHoje && !selecionado)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(right: 3),
                                    decoration: const BoxDecoration(
                                      color: corAzul,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Text(
                                  quantidade == 0 ? 'livre' : '$quantidade',
                                  style: TextStyle(
                                    color: selecionado
                                        ? Colors.black87
                                        : corTextoSecundario,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Atalho para voltar para hoje.
          if (dataSelecionada.year != agora.year ||
              dataSelecionada.month != agora.month ||
              dataSelecionada.day != agora.day)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  setState(() {
                    dataAgendaSelecionada = DateTime.now();
                  });
                  await carregarAgendaSelecionada();
                },
                icon: const Icon(Icons.today_outlined, size: 18),
                label: const Text('VOLTAR PARA HOJE'),
                style: TextButton.styleFrom(
                  foregroundColor: corAzul,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),

          const SizedBox(height: 4),

          // Resumo do dia selecionado.
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: corCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B2B2B)),
            ),
            child: Row(
              children: [
                Container(
                  width: 47,
                  height: 47,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF202A2F),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color: corAzul,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatarData(dataSelecionadaTexto),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$ativos pendente${ativos == 1 ? '' : 's'} • '
                        '$concluidos concluído${concluidos == 1 ? '' : 's'}'
                        '${cancelados > 0 ? ' • $cancelados cancelado${cancelados == 1 ? '' : 's'}' : ''}',
                        style: const TextStyle(
                          color: corTextoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (faturamento > 0)
                  Text(
                    dinheiro(faturamento),
                    style: const TextStyle(
                      color: corAzul,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (agendamentosDoDia.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
              decoration: BoxDecoration(
                color: corCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2B2B2B)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    color: corTextoSecundario,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhum agendamento neste dia',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Você pode adicionar um cliente manualmente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: corTextoSecundario, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: abrirNovoAgendamento,
                      style: botaoPrincipal(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'NOVO AGENDAMENTO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...agendamentosDoDia.map((item) {
              final horario = (item['horario'] ?? '').toString();
              final cancelado = agendamentoCancelado(item);
              final finalizado = agendamentoFinalizado(item);
              final fixo = numeroInt(item['fixo']) == 1;

              final minutos = minutosDoHorario(horario);
              final agoraMinutos = (agora.hour * 60) + agora.minute;

              final ehHoje =
                  dataSelecionada.year == agora.year &&
                  dataSelecionada.month == agora.month &&
                  dataSelecionada.day == agora.day;

              final jaPassou = ehHoje && minutos < agoraMinutos;

              final corLinha = cancelado
                  ? Colors.redAccent
                  : finalizado
                  ? Colors.greenAccent
                  : jaPassou
                  ? Colors.orangeAccent
                  : corAzul;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: corCard,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF2B2B2B)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: corLinha,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(15),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 13, 12, 13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF202A2F),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      horario,
                                      style: TextStyle(
                                        color: corLinha,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  if (jaPassou && !finalizado && !cancelado)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'ATRASADO',
                                        style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (fixo) ...[
                                    if (jaPassou && !finalizado && !cancelado)
                                      const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22343D),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'FIXO',
                                        style: TextStyle(
                                          color: corAzul,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    dinheiro(numeroDouble(item['valor'])),
                                    style: const TextStyle(
                                      color: corAzul,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 11),

                              Text(
                                (item['nome'] ?? 'Cliente').toString(),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              if ((item['servico'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  (item['servico'] ?? '').toString(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],

                              if ((item['numero'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  (item['numero'] ?? '').toString(),
                                  style: const TextStyle(
                                    color: corTextoSecundario,
                                    fontSize: 12,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 11),

                              if (cancelado)
                                _statusAgenda(
                                  texto: 'CANCELADO',
                                  icone: Icons.cancel_outlined,
                                  cor: Colors.redAccent,
                                )
                              else if (finalizado)
                                _statusAgenda(
                                  texto: 'FINALIZADO',
                                  icone: Icons.check_circle_outline,
                                  cor: Colors.greenAccent,
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 40,
                                        child: OutlinedButton.icon(
                                          onPressed: fixo
                                              ? null
                                              : () {
                                                  abrirWhatsApp(item);
                                                },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.greenAccent,
                                            side: BorderSide(
                                              color: fixo
                                                  ? Colors.grey.shade800
                                                  : Colors.greenAccent,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.chat_outlined,
                                            size: 17,
                                          ),
                                          label: const Text(
                                            'WHATSAPP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: SizedBox(
                                        height: 40,
                                        child: OutlinedButton.icon(
                                          onPressed: fixo
                                              ? null
                                              : () {
                                                  editarAgendamento(item);
                                                },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: corAzul,
                                            side: BorderSide(
                                              color: fixo
                                                  ? Colors.grey.shade800
                                                  : corAzul,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.edit_calendar_outlined,
                                            size: 17,
                                          ),
                                          label: const Text(
                                            'REMARCAR',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    SizedBox(
                                      height: 40,
                                      width: 105,
                                      child: ElevatedButton.icon(
                                        onPressed: fixo
                                            ? null
                                            : () {
                                                finalizar(
                                                  numeroInt(item['id']),
                                                );
                                              },
                                        style: botaoPrincipal(),
                                        icon: const Icon(Icons.check, size: 17),
                                        label: const Text(
                                          'FINALIZAR',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statusAgenda({
    required String texto,
    required IconData icone,
    required Color cor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, color: cor, size: 18),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // TELA FIXOS
  // ====================================================

  Widget telaFixos() {
    return RefreshIndicator(
      color: corAzul,
      onRefresh: carregarTudo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Clientes fixos',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          const Text(
            'Horários que se repetem automaticamente toda semana.',
            style: TextStyle(color: corTextoSecundario),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 53,
            child: ElevatedButton.icon(
              onPressed: abrirCadastroFixo,
              style: botaoPrincipal(),
              icon: const Icon(Icons.add),
              label: const Text(
                'ADICIONAR HORÁRIO FIXO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (fixos.isEmpty) mensagemVazia('Nenhum horário fixo cadastrado.'),

          ...fixos.map((item) => cardFixo(item)),
        ],
      ),
    );
  }

  // ====================================================
  // TELA BLOQUEIOS
  // ====================================================

  Widget telaBloqueios() {
    return RefreshIndicator(
      color: corAzul,
      onRefresh: carregarTudo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Bloqueios da agenda',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          const Text(
            'Bloqueie horários ou um dia inteiro para impedir novos agendamentos pelo site.',
            style: TextStyle(color: corTextoSecundario),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 53,
            child: ElevatedButton.icon(
              onPressed: abrirCadastroBloqueio,
              style: botaoPrincipal(),
              icon: const Icon(Icons.add),
              label: const Text(
                'NOVO BLOQUEIO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (bloqueios.isEmpty) mensagemVazia('Nenhum bloqueio cadastrado.'),

          ...bloqueios.map((item) => cardBloqueio(item)),
        ],
      ),
    );
  }

  // ====================================================
  // TELA HISTÓRICO
  // ====================================================

  Widget telaHistorico() {
    final pesquisa = pesquisaHistoricoController.text.trim().toLowerCase();

    final listaFiltrada = historico.where((item) {
      final nome = (item['nome'] ?? '').toString().toLowerCase();
      final dia = (item['dia'] ?? '').toString();

      final bateNome = pesquisa.isEmpty || nome.contains(pesquisa);
      final bateData =
          dataFiltroHistorico == null || dia == dataFiltroHistorico;

      return bateNome && bateData;
    }).toList();

    final Map<String, List<dynamic>> porData = {};

    for (final item in listaFiltrada) {
      final dia = (item['dia'] ?? '').toString();
      porData.putIfAbsent(dia, () => []);
      porData[dia]!.add(item);
    }

    final datas = porData.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      color: corAzul,
      onRefresh: carregarTudo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Histórico de atendimentos',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            'Pesquise um cliente ou filtre os atendimentos por data.',
            style: TextStyle(color: corTextoSecundario),
          ),
          const SizedBox(height: 18),

          TextField(
            controller: pesquisaHistoricoController,
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Pesquisar cliente',
              hintText: 'Digite o nome do cliente',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: pesquisaHistoricoController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        pesquisaHistoricoController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final agora = DateTime.now();

                    final escolhida = await showDatePicker(
                      context: context,
                      initialDate: dataFiltroHistorico == null
                          ? agora
                          : DateTime.tryParse(dataFiltroHistorico!) ?? agora,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(agora.year + 2),
                      helpText: 'Selecionar data do histórico',
                      cancelText: 'CANCELAR',
                      confirmText: 'SELECIONAR',
                    );

                    if (escolhida == null) return;

                    setState(() {
                      dataFiltroHistorico =
                          '${escolhida.year.toString().padLeft(4, '0')}-'
                          '${escolhida.month.toString().padLeft(2, '0')}-'
                          '${escolhida.day.toString().padLeft(2, '0')}';
                    });
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    dataFiltroHistorico == null
                        ? 'FILTRAR POR DATA'
                        : formatarData(dataFiltroHistorico!),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: corAzul,
                    side: const BorderSide(color: corAzul),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              if (dataFiltroHistorico != null) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Limpar data',
                  onPressed: () {
                    setState(() {
                      dataFiltroHistorico = null;
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          if (listaFiltrada.isEmpty)
            mensagemVazia(
              pesquisa.isNotEmpty || dataFiltroHistorico != null
                  ? 'Nenhum atendimento encontrado com esse filtro.'
                  : 'Nenhum atendimento no histórico.',
            ),

          for (final data in datas) ...[
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF202A2F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: corAzul,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    formatarData(data),
                    style: const TextStyle(
                      color: corAzul,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${porData[data]!.length} atendimento${porData[data]!.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: corTextoSecundario,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ...porData[data]!.map((item) => cardHistorico(item)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ====================================================
  // TELA CLIENTES
  // ====================================================

  Widget telaClientes() {
    final pesquisa = pesquisaClientesController.text.trim().toLowerCase();
    final lista = clientes.where((item) {
      final nome = (item['nome'] ?? '').toString().toLowerCase();
      final numero = (item['numero'] ?? '').toString().toLowerCase();
      return pesquisa.isEmpty ||
          nome.contains(pesquisa) ||
          numero.contains(pesquisa);
    }).toList();

    return RefreshIndicator(
      color: corAzul,
      onRefresh: carregarTudo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clientes',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Cadastro e histórico dos seus clientes.',
                      style: TextStyle(color: corTextoSecundario),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Novo cliente',
                onPressed: () => abrirFormularioCliente(),
                icon: const Icon(Icons.person_add_alt_1),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: pesquisaClientesController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Pesquisar cliente',
              hintText: 'Nome ou telefone',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: pesquisaClientesController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        pesquisaClientesController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (lista.isEmpty) mensagemVazia('Nenhum cliente encontrado.'),
          ...lista.map(cardCliente),
        ],
      ),
    );
  }

  Widget cardCliente(dynamic item) {
    final nome = (item['nome'] ?? '').toString();
    final numero = (item['numero'] ?? '').toString();
    final atendimentos = numeroInt(item['total_atendimentos']);
    final gasto = numeroDouble(item['total_gasto']);
    final ultimo = (item['ultimo_atendimento'] ?? '').toString();

    return Card(
      color: corCard,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => abrirDetalhesCliente(item),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF263B45),
                child: Text(
                  nome.isEmpty ? '?' : nome[0].toUpperCase(),
                  style: const TextStyle(
                    color: corAzul,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (numero.isNotEmpty)
                      Text(
                        numero,
                        style: const TextStyle(color: corTextoSecundario),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '$atendimentos atendimento${atendimentos == 1 ? '' : 's'} • ${dinheiro(gasto)}',
                      style: const TextStyle(color: corAzul, fontSize: 12),
                    ),
                    if (ultimo.isNotEmpty)
                      Text(
                        'Último: ${formatarData(ultimo)}',
                        style: const TextStyle(
                          color: corTextoSecundario,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: corTextoSecundario),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> abrirFormularioCliente([dynamic cliente]) async {
    final nomeController = TextEditingController(
      text: cliente?['nome']?.toString() ?? '',
    );
    final numeroController = TextEditingController(
      text: cliente?['numero']?.toString() ?? '',
    );
    final editando = cliente != null;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: corCard,
        title: Text(editando ? 'Editar cliente' : 'Novo cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numeroController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: botaoPrincipal(),
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );

    if (salvar != true) return;
    final nome = nomeController.text.trim();
    final numero = numeroController.text.trim();
    if (nome.isEmpty) {
      if (mounted)
        mostrarMensagem(context, 'Digite o nome do cliente.', erro: true);
      return;
    }

    try {
      final resposta = editando
          ? await http.put(
              Uri.parse('$api/app/clientes/${cliente['id']}'),
              headers: headersAutenticados(json: true),
              body: jsonEncode({'nome': nome, 'numero': numero}),
            )
          : await http.post(
              Uri.parse('$api/app/clientes'),
              headers: headersAutenticados(json: true),
              body: jsonEncode({
                'nome': nome,
                'numero': numero,
                'barbeiro': widget.barbeiro,
              }),
            );
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        mostrarMensagem(
          context,
          editando ? 'Cliente atualizado!' : 'Cliente cadastrado!',
        );
        await carregarTudo(exibirLoading: false);
      } else {
        final dados = jsonDecode(resposta.body);
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Erro ao salvar cliente.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    }
  }

  Future<void> abrirDetalhesCliente(dynamic cliente) async {
    try {
      final resposta = await http.get(
        Uri.parse('$api/app/clientes/${cliente['id']}/historico'),
        headers: headersAutenticados(),
      );
      if (!mounted) return;
      if (resposta.statusCode != 200) {
        mostrarMensagem(
          context,
          'Erro ao carregar histórico do cliente.',
          erro: true,
        );
        return;
      }
      final dados = jsonDecode(resposta.body);
      final lista = (dados['historico'] as List?) ?? [];
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: corCard,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          maxChildSize: .92,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (cliente['nome'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      abrirFormularioCliente(cliente);
                    },
                    icon: const Icon(Icons.edit_outlined, color: corAzul),
                  ),
                ],
              ),
              Text(
                (cliente['numero'] ?? '').toString(),
                style: const TextStyle(color: corTextoSecundario),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _miniInfoCliente(
                      'Atendimentos',
                      '${numeroInt(dados['total_atendimentos'])}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniInfoCliente(
                      'Total gasto',
                      dinheiro(numeroDouble(dados['total_gasto'])),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Histórico',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (lista.isEmpty)
                mensagemVazia('Nenhum atendimento deste cliente.'),
              ...lista.map((item) => cardHistorico(item)),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    }
  }

  Widget _miniInfoCliente(String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: corCard2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(color: corTextoSecundario, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              color: corAzul,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget cardHistorico(dynamic item) {
    final status = (item['status'] ?? '').toString();
    final cancelado = status.toLowerCase() == 'cancelado';
    final nome = (item['nome'] ?? '').toString();
    final numero = (item['numero'] ?? '').toString().trim();
    final horario = (item['horario'] ?? '').toString();
    final servico = (item['servico'] ?? '').toString().trim();
    final valor = numeroDouble(item['valor']);
    final corStatus = cancelado ? Colors.redAccent : Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: corStatus.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: corStatus,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            horario,
            style: const TextStyle(
              color: corAzul,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (numero.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(numero, style: const TextStyle(color: corTextoSecundario)),
          ],
          if (servico.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(servico, style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 6),
          Text(
            dinheiro(valor),
            style: const TextStyle(color: corAzul, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // MENSAGEM VAZIA
  // ====================================================

  Widget mensagemVazia(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 20),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 35,
            color: corTextoSecundario,
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: corTextoSecundario),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // CARD RESUMO
  // ====================================================

  Widget cardResumo({
    required String titulo,
    required String valor,
    required IconData icone,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF292929)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cor.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 22),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: corTextoSecundario,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    valor,
                    style: TextStyle(
                      color: cor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // CARD AGENDAMENTO
  // ====================================================

  Widget cardAgendamento(
    dynamic item, {
    bool mostrarData = false,
    bool destaqueProximo = false,
  }) {
    final status = (item['status'] ?? '').toString().toLowerCase();

    final finalizado = status == 'finalizado';
    final cancelado = status == 'cancelado';

    final fixo = numeroInt(item['fixo']) == 1;

    final nome = (item['nome'] ?? '').toString();

    final numero = (item['numero'] ?? '').toString().trim();

    final horario = (item['horario'] ?? '').toString();

    final servico = (item['servico'] ?? '').toString().trim();

    final dia = (item['dia'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: destaqueProximo
              ? corAzul.withValues(alpha: 0.75)
              : cancelado
              ? Colors.red.shade900
              : const Color(0xFF2B2B2B),
          width: destaqueProximo ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (destaqueProximo) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: corAzul.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PRÓXIMO',
                      style: TextStyle(
                        color: corAzul,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            if (mostrarData && dia.isNotEmpty) ...[
              Text(
                formatarData(dia),
                style: const TextStyle(
                  color: corAzul,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
            ],

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202A2F),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    horario,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: corAzul,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nome,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          if (fixo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22343D),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'FIXO',
                                style: TextStyle(
                                  color: corAzul,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      if (numero.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          numero,
                          style: const TextStyle(
                            color: corTextoSecundario,
                            fontSize: 13,
                          ),
                        ),
                      ],

                      if (servico.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          servico,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],

                      const SizedBox(height: 5),

                      Text(
                        dinheiro(numeroDouble(item['valor'])),
                        style: const TextStyle(
                          color: corAzul,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (cancelado)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A1D1D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      color: Colors.redAccent,
                      size: 19,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'CANCELADO',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (finalizado)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF183126),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 19,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'FINALIZADO',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  if (!fixo) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: numero.isEmpty
                            ? null
                            : () {
                                abrirWhatsApp(item);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          side: BorderSide(
                            color: numero.isEmpty
                                ? Colors.grey.shade700
                                : Colors.greenAccent,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.chat_outlined, size: 19),
                        label: Text(
                          numero.isEmpty ? 'SEM TELEFONE' : 'WHATSAPP',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          editarAgendamento(item);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: corAzul,
                          side: const BorderSide(color: corAzul),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.edit_calendar_outlined,
                          size: 19,
                        ),
                        label: const Text(
                          'EDITAR / REMARCAR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            finalizar(numeroInt(item['id']));
                          },
                          style: botaoPrincipal(),
                          icon: const Icon(Icons.check, size: 19),
                          label: const Text(
                            'Finalizar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: fixo
                              ? () {
                                  setState(() {
                                    pagina = 2;
                                  });
                                }
                              : () {
                                  cancelar(numeroInt(item['id']));
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: fixo
                                ? corAzul
                                : Colors.red.shade300,
                            side: BorderSide(
                              color: fixo ? corAzul : Colors.red.shade700,
                            ),
                          ),
                          child: Text(fixo ? 'Ver Fixos' : 'Cancelar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ====================================================
  // CARD FIXO
  // ====================================================

  Widget cardFixo(dynamic item) {
    final nome = (item['nome'] ?? '').toString();

    final numero = (item['numero'] ?? '').toString().trim();

    final servico = (item['servico'] ?? '').toString().trim();

    final horario = (item['horario'] ?? '').toString();

    final diaSemana = numeroInt(item['dia_semana']);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF22343D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_repeat, color: corAzul),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${nomeDiaSemana(diaSemana)} • $horario',
                      style: const TextStyle(
                        color: corAzul,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () {
                  excluirFixo(item);
                },
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
              ),
            ],
          ),

          if (numero.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  color: corTextoSecundario,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(numero),
              ],
            ),
          ],

          if (servico.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.content_cut,
                  color: corTextoSecundario,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$servico • ${dinheiro(numeroDouble(item['valor']))}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ====================================================
  // CARD BLOQUEIO
  // ====================================================

  Widget cardBloqueio(dynamic item) {
    final dia = (item['dia'] ?? '').toString();

    final horario = (item['horario'] ?? '').toString();

    final motivo = (item['motivo'] ?? '').toString().trim();

    final diaInteiro = numeroInt(item['dia_inteiro']) == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF382126),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.block, color: Colors.redAccent),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatarData(dia),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  diaInteiro ? 'DIA INTEIRO' : 'Horário: $horario',
                  style: const TextStyle(
                    color: corAzul,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (motivo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    motivo,
                    style: const TextStyle(color: corTextoSecundario),
                  ),
                ],
              ],
            ),
          ),

          IconButton(
            tooltip: 'Desbloquear',
            onPressed: () {
              excluirBloqueio(item);
            },
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}
// ======================================================
// EDITAR / REMARCAR AGENDAMENTO
// ======================================================

class EditarAgendamentoPage extends StatefulWidget {
  final dynamic agendamento;
  final String barbeiro;

  const EditarAgendamentoPage({
    super.key,
    required this.agendamento,
    required this.barbeiro,
  });

  @override
  State<EditarAgendamentoPage> createState() => _EditarAgendamentoPageState();
}

class _EditarAgendamentoPageState extends State<EditarAgendamentoPage> {
  final List<String> todosHorarios = const [
    '08:00',
    '08:40',
    '09:20',
    '10:00',
    '10:40',
    '11:20',
    '12:00',
    '12:40',
    '13:20',
    '14:00',
    '14:40',
    '15:20',
    '16:00',
    '16:40',
    '17:20',
    '18:00',
    '18:40',
    '19:20',
    '20:00',
  ];

  late DateTime dataSelecionada;
  late String horarioSelecionado;
  late String servicoSelecionado;

  List<String> horariosLivres = [];

  bool carregandoHorarios = false;
  bool salvando = false;

  @override
  void initState() {
    super.initState();

    final dia = (widget.agendamento['dia'] ?? '').toString();

    dataSelecionada = DateTime.tryParse(dia) ?? DateTime.now();

    horarioSelecionado = (widget.agendamento['horario'] ?? '').toString();

    servicoSelecionado = (widget.agendamento['servico'] ?? '').toString();

    if (servicoSelecionado != 'Corte' &&
        servicoSelecionado != 'Corte + Barba') {
      servicoSelecionado = 'Corte';
    }

    carregarHorarios();
  }

  String dataApi(DateTime data) {
    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
  }

  bool barbeiroTrabalha(DateTime data) {
    final barbeiro = widget.barbeiro.trim().toLowerCase();

    if (barbeiro == 'gustavo') {
      return data.weekday == 6;
    }

    if (barbeiro == 'guel') {
      return data.weekday >= 3 && data.weekday <= 6;
    }

    return true;
  }

  Future<void> escolherData() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    DateTime inicial = dataSelecionada;

    if (inicial.isBefore(hoje)) {
      inicial = hoje;
    }

    while (!barbeiroTrabalha(inicial)) {
      inicial = inicial.add(const Duration(days: 1));
    }

    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: hoje,
      lastDate: DateTime(agora.year + 2),
      selectableDayPredicate: barbeiroTrabalha,
      helpText: 'Escolha a nova data',
      cancelText: 'CANCELAR',
      confirmText: 'SELECIONAR',
    );

    if (escolhida == null) return;

    setState(() {
      dataSelecionada = escolhida;
      horarioSelecionado = '';
    });

    await carregarHorarios();
  }

  Future<void> carregarHorarios() async {
    if (mounted) {
      setState(() {
        carregandoHorarios = true;
      });
    }

    try {
      final dia = dataApi(dataSelecionada);

      final resposta = await http.get(
        Uri.parse('$api/horarios-livres/$dia/${widget.barbeiro}'),
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);

        final lista = List<String>.from(
          (dados as List).map((item) => item.toString()),
        );

        final diaOriginal = (widget.agendamento['dia'] ?? '').toString();
        final horarioOriginal = (widget.agendamento['horario'] ?? '')
            .toString();

        if (dia == diaOriginal &&
            horarioOriginal.isNotEmpty &&
            !lista.contains(horarioOriginal)) {
          lista.add(horarioOriginal);
        }

        lista.sort(
          (a, b) =>
              todosHorarios.indexOf(a).compareTo(todosHorarios.indexOf(b)),
        );

        setState(() {
          horariosLivres = lista;

          if (horarioSelecionado.isNotEmpty &&
              !horariosLivres.contains(horarioSelecionado)) {
            horarioSelecionado = '';
          }
        });
      } else {
        mostrarMensagem(context, 'Erro ao carregar horários.', erro: true);
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregandoHorarios = false;
        });
      }
    }
  }

  Future<void> salvar() async {
    if (horarioSelecionado.isEmpty) {
      mostrarMensagem(context, 'Escolha um horário.', erro: true);
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final id = numeroInt(widget.agendamento['id']);

      final resposta = await http.put(
        Uri.parse('$api/app/agendamentos/$id'),
        headers: headersAutenticados(json: true),
        body: jsonEncode({
          'dia': dataApi(dataSelecionada),
          'horario': horarioSelecionado,
          'servico': servicoSelecionado,
        }),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(
          context,
          dados['mensagem']?.toString() ?? 'Agendamento atualizado!',
        );

        Navigator.pop(context, true);
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível atualizar.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome = (widget.agendamento['nome'] ?? '').toString();
    final numero = (widget.agendamento['numero'] ?? '').toString().trim();

    final valor = servicoSelecionado == 'Corte + Barba' ? 50.0 : 30.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar agendamento')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: corCard,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFF2B2B2B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cliente',
                          style: TextStyle(color: corTextoSecundario),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (numero.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            numero,
                            style: const TextStyle(color: corTextoSecundario),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Data',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 53,
                    child: OutlinedButton.icon(
                      onPressed: escolherData,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(formatarData(dataApi(dataSelecionada))),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: corAzul,
                        side: const BorderSide(color: corAzul),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Horário',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  if (carregandoHorarios)
                    const Center(
                      child: CircularProgressIndicator(color: corAzul),
                    )
                  else if (horariosLivres.isEmpty)
                    const Text(
                      'Nenhum horário disponível nesta data.',
                      style: TextStyle(color: Colors.redAccent),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: horariosLivres.map((horario) {
                        final selecionado = horario == horarioSelecionado;

                        return ChoiceChip(
                          label: Text(horario),
                          selected: selecionado,
                          onSelected: (_) {
                            setState(() {
                              horarioSelecionado = horario;
                            });
                          },
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 25),

                  const Text(
                    'Serviço',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: servicoSelecionado,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.content_cut_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Corte',
                        child: Text('Corte - R\$ 30,00'),
                      ),
                      DropdownMenuItem(
                        value: 'Corte + Barba',
                        child: Text('Corte + Barba - R\$ 50,00'),
                      ),
                    ],
                    onChanged: (valor) {
                      if (valor == null) return;

                      setState(() {
                        servicoSelecionado = valor;
                      });
                    },
                  ),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202A2F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Valor',
                          style: TextStyle(color: corTextoSecundario),
                        ),
                        const Spacer(),
                        Text(
                          dinheiro(valor),
                          style: const TextStyle(
                            color: corAzul,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: salvando ? null : salvar,
                      style: botaoPrincipal(),
                      icon: salvando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        salvando ? 'SALVANDO...' : 'SALVAR ALTERAÇÕES',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String formatarDataBackend(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return '$ano-$mes-$dia';
  }
}

// ======================================================
// CADASTRAR FIXO
// ======================================================

// ======================================================
// NOVO AGENDAMENTO MANUAL
// ======================================================

class NovoAgendamentoPage extends StatefulWidget {
  final String barbeiro;
  final String nomeBarbeiro;

  const NovoAgendamentoPage({
    super.key,
    required this.barbeiro,
    required this.nomeBarbeiro,
  });

  @override
  State<NovoAgendamentoPage> createState() => _NovoAgendamentoPageState();
}

class _NovoAgendamentoPageState extends State<NovoAgendamentoPage> {
  final nomeController = TextEditingController();
  final numeroController = TextEditingController();

  DateTime? dataSelecionada;
  List<String> horariosLivres = [];
  String? horarioSelecionado;
  String servicoSelecionado = 'Corte';
  bool carregandoHorarios = false;
  bool salvando = false;

  double get valorServico => servicoSelecionado == 'Corte + Barba' ? 50 : 30;

  String formatarDataBackend(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return '$ano-$mes-$dia';
  }

  String formatarDataTela(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  bool barbeiroTrabalha(DateTime data) {
    final barbeiro = widget.barbeiro.trim().toLowerCase();
    if (barbeiro == 'gustavo') return data.weekday == DateTime.saturday;
    if (barbeiro == 'guel') {
      return data.weekday >= DateTime.wednesday &&
          data.weekday <= DateTime.saturday;
    }
    return true;
  }

  Future<void> escolherData() async {
    final agora = DateTime.now();
    var inicial = DateTime(agora.year, agora.month, agora.day);
    while (!barbeiroTrabalha(inicial)) {
      inicial = inicial.add(const Duration(days: 1));
    }

    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(agora.year, agora.month, agora.day),
      lastDate: DateTime(agora.year + 2),
      selectableDayPredicate: barbeiroTrabalha,
      helpText: 'Selecione o dia do agendamento',
      cancelText: 'CANCELAR',
      confirmText: 'SELECIONAR',
    );

    if (escolhida == null) return;

    setState(() {
      dataSelecionada = escolhida;
      horarioSelecionado = null;
      horariosLivres = [];
    });
    await carregarHorarios();
  }

  Future<void> carregarHorarios() async {
    if (dataSelecionada == null) return;
    setState(() => carregandoHorarios = true);
    try {
      final dia = formatarDataBackend(dataSelecionada!);
      final resposta = await http.get(
        Uri.parse('$api/horarios-livres/$dia/${widget.barbeiro}'),
      );
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        final lista = (dados as List).map((e) => e.toString()).toList();
        setState(() {
          horariosLivres = lista;
          horarioSelecionado = lista.isEmpty ? null : lista.first;
        });
      } else {
        mostrarMensagem(
          context,
          'Não foi possível carregar os horários.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    } finally {
      if (mounted) setState(() => carregandoHorarios = false);
    }
  }

  Future<void> agendar() async {
    final nome = nomeController.text.trim();
    final numero = numeroController.text.trim();
    if (nome.isEmpty) {
      mostrarMensagem(context, 'Digite o nome do cliente.', erro: true);
      return;
    }
    if (dataSelecionada == null) {
      mostrarMensagem(context, 'Selecione a data.', erro: true);
      return;
    }
    if (horarioSelecionado == null) {
      mostrarMensagem(context, 'Selecione um horário disponível.', erro: true);
      return;
    }

    setState(() => salvando = true);
    try {
      final resposta = await http.post(
        Uri.parse('$api/agendar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'numero': numero,
          'dia': formatarDataBackend(dataSelecionada!),
          'horario': horarioSelecionado,
          'barbeiro': widget.barbeiro,
          'servico': servicoSelecionado,
          'valor': valorServico,
        }),
      );

      dynamic dados = {};
      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        mostrarMensagem(
          context,
          dados['mensagem']?.toString() ?? 'Agendamento criado!',
        );
        await Future.delayed(const Duration(milliseconds: 450));
        if (mounted) Navigator.pop(context, true);
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível criar o agendamento.',
          erro: true,
        );
        await carregarHorarios();
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    numeroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo agendamento')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: logoGBarber(tamanho: 90, mostrarNome: false)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: corCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF303030)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.content_cut, color: corAzul),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Barbeiro: ${widget.nomeBarbeiro}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome do cliente *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: numeroController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: escolherData,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data *',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(
                        dataSelecionada == null
                            ? 'Selecionar data'
                            : formatarDataTela(dataSelecionada!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (carregandoHorarios)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: corAzul),
                      ),
                    )
                  else if (dataSelecionada != null && horariosLivres.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: corCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Nenhum horário disponível nesta data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: corTextoSecundario),
                      ),
                    )
                  else if (dataSelecionada != null)
                    DropdownButtonFormField<String>(
                      initialValue: horarioSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Horário *',
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      items: horariosLivres
                          .map(
                            (h) => DropdownMenuItem(value: h, child: Text(h)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => horarioSelecionado = v),
                    ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: servicoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Serviço *',
                      prefixIcon: Icon(Icons.content_cut),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Corte',
                        child: Text('Corte - R\$ 30,00'),
                      ),
                      DropdownMenuItem(
                        value: 'Corte + Barba',
                        child: Text('Corte + Barba - R\$ 50,00'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => servicoSelecionado = v);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: salvando ? null : agendar,
                      style: botaoPrincipal(),
                      icon: salvando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        salvando ? 'AGENDANDO...' : 'CONFIRMAR AGENDAMENTO',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
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

class CadastroFixoPage extends StatefulWidget {
  final String barbeiro;
  final String nomeBarbeiro;

  const CadastroFixoPage({
    super.key,
    required this.barbeiro,
    required this.nomeBarbeiro,
  });

  @override
  State<CadastroFixoPage> createState() => _CadastroFixoPageState();
}

class _CadastroFixoPageState extends State<CadastroFixoPage> {
  final nomeController = TextEditingController();
  final numeroController = TextEditingController();

  final List<String> horarios = const [
    '08:00',
    '08:40',
    '09:20',
    '10:00',
    '10:40',
    '11:20',
    '12:00',
    '12:40',
    '13:20',
    '14:00',
    '14:40',
    '15:20',
    '16:00',
    '16:40',
    '17:20',
    '18:00',
    '18:40',
    '19:20',
    '20:00',
  ];

  int? diaSelecionado;
  String? horarioSelecionado;
  String servicoSelecionado = 'Corte';

  bool carregando = false;

  List<int> get diasDisponiveis {
    final barbeiro = widget.barbeiro.trim().toLowerCase();

    if (barbeiro == 'gustavo') {
      return [6];
    }

    if (barbeiro == 'guel') {
      return [3, 4, 5, 6];
    }

    return [];
  }

  double get valorServico {
    if (servicoSelecionado == 'Corte + Barba') {
      return 50;
    }

    return 30;
  }

  @override
  void initState() {
    super.initState();

    if (diasDisponiveis.isNotEmpty) {
      diaSelecionado = diasDisponiveis.first;
    }

    horarioSelecionado = horarios.first;
  }

  @override
  void dispose() {
    nomeController.dispose();
    numeroController.dispose();
    super.dispose();
  }

  Future<void> cadastrar() async {
    final nome = nomeController.text.trim();
    final numero = numeroController.text.trim();

    if (nome.isEmpty) {
      mostrarMensagem(context, 'Digite o nome do cliente.', erro: true);
      return;
    }

    if (diaSelecionado == null || horarioSelecionado == null) {
      mostrarMensagem(context, 'Selecione dia e horário.', erro: true);
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('$api/agendar-fixo'),
        headers: headersAutenticados(json: true),
        body: jsonEncode({
          'nome': nome,
          'numero': numero,
          'dia_semana': diaSelecionado,
          'horario': horarioSelecionado,
          'barbeiro': widget.barbeiro,
          'servico': servicoSelecionado,
          'valor': valorServico,
        }),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(
          context,
          dados['mensagem']?.toString() ?? 'Horário fixo cadastrado!',
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível cadastrar.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo horário fixo')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: logoGBarber(tamanho: 95, mostrarNome: false)),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: corCard,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.content_cut, color: corAzul),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Barbeiro: ${widget.nomeBarbeiro}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome do cliente',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: numeroController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp / telefone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<int>(
                    value: diaSelecionado,
                    dropdownColor: corCard,
                    decoration: const InputDecoration(
                      labelText: 'Dia da semana',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    items: diasDisponiveis.map((dia) {
                      return DropdownMenuItem<int>(
                        value: dia,
                        child: Text(nomeDiaSemana(dia)),
                      );
                    }).toList(),
                    onChanged: (valor) {
                      setState(() {
                        diaSelecionado = valor;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: horarioSelecionado,
                    dropdownColor: corCard,
                    decoration: const InputDecoration(
                      labelText: 'Horário',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: horarios.map((horario) {
                      return DropdownMenuItem<String>(
                        value: horario,
                        child: Text(horario),
                      );
                    }).toList(),
                    onChanged: (valor) {
                      setState(() {
                        horarioSelecionado = valor;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: servicoSelecionado,
                    dropdownColor: corCard,
                    decoration: const InputDecoration(
                      labelText: 'Serviço',
                      prefixIcon: Icon(Icons.content_cut),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'Corte',
                        child: Text('Corte - R\$ 30,00'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Corte + Barba',
                        child: Text('Corte + Barba - R\$ 50,00'),
                      ),
                    ],
                    onChanged: (valor) {
                      if (valor == null) return;

                      setState(() {
                        servicoSelecionado = valor;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: corCard,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFF303030)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined, color: corAzul),

                        const SizedBox(width: 10),

                        const Expanded(child: Text('Valor')),

                        Text(
                          dinheiro(valorServico),
                          style: const TextStyle(
                            color: corAzul,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: carregando ? null : cadastrar,
                      style: botaoPrincipal(),
                      icon: carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        carregando ? 'SALVANDO...' : 'SALVAR HORÁRIO FIXO',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
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

// ======================================================
// CADASTRAR BLOQUEIO
// ======================================================

class CadastroBloqueioPage extends StatefulWidget {
  final String barbeiro;
  final String nomeBarbeiro;

  const CadastroBloqueioPage({
    super.key,
    required this.barbeiro,
    required this.nomeBarbeiro,
  });

  @override
  State<CadastroBloqueioPage> createState() => _CadastroBloqueioPageState();
}

class _CadastroBloqueioPageState extends State<CadastroBloqueioPage> {
  final motivoController = TextEditingController();

  final List<String> horarios = const [
    '08:00',
    '08:40',
    '09:20',
    '10:00',
    '10:40',
    '11:20',
    '12:00',
    '12:40',
    '13:20',
    '14:00',
    '14:40',
    '15:20',
    '16:00',
    '16:40',
    '17:20',
    '18:00',
    '18:40',
    '19:20',
    '20:00',
  ];

  DateTime? dataSelecionada;

  bool diaInteiro = false;
  bool carregando = false;

  final Set<String> horariosSelecionados = {};

  bool barbeiroTrabalha(DateTime data) {
    final barbeiro = widget.barbeiro.trim().toLowerCase();

    final diaSemana = data.weekday;

    if (barbeiro == 'gustavo') {
      return diaSemana == DateTime.saturday;
    }

    if (barbeiro == 'guel') {
      return diaSemana >= DateTime.wednesday && diaSemana <= DateTime.saturday;
    }

    return true;
  }

  String formatarDataBackend(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');

    final mes = data.month.toString().padLeft(2, '0');

    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  String formatarDataTela(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');

    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  Future<void> escolherData() async {
    final agora = DateTime.now();

    DateTime inicial = dataSelecionada ?? agora;

    while (!barbeiroTrabalha(inicial)) {
      inicial = inicial.add(const Duration(days: 1));
    }

    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(agora.year, agora.month, agora.day),
      lastDate: DateTime(agora.year + 2),
      selectableDayPredicate: barbeiroTrabalha,
      helpText: 'Selecione o dia',
      cancelText: 'CANCELAR',
      confirmText: 'SELECIONAR',
    );

    if (escolhida == null) {
      return;
    }

    setState(() {
      dataSelecionada = escolhida;
    });
  }

  Future<void> salvarBloqueio() async {
    if (dataSelecionada == null) {
      mostrarMensagem(context, 'Selecione uma data.', erro: true);

      return;
    }

    if (!diaInteiro && horariosSelecionados.isEmpty) {
      mostrarMensagem(context, 'Selecione pelo menos um horário.', erro: true);

      return;
    }

    setState(() {
      carregando = true;
    });

    final motivo = motivoController.text.trim();

    final dia = formatarDataBackend(dataSelecionada!);

    try {
      final Map<String, dynamic> corpo;

      if (diaInteiro) {
        corpo = {
          'barbeiro': widget.barbeiro,
          'dia': dia,
          'dia_inteiro': true,
          'motivo': motivo,
        };
      } else {
        final lista = horariosSelecionados.toList()..sort();

        corpo = {
          'barbeiro': widget.barbeiro,
          'dia': dia,
          'horarios': lista,
          'dia_inteiro': false,
          'motivo': motivo,
        };
      }

      final resposta = await http.post(
        Uri.parse('$api/app/bloqueios'),
        headers: headersAutenticados(json: true),
        body: jsonEncode(corpo),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(
          context,
          dados['mensagem']?.toString() ?? 'Bloqueio criado com sucesso!',
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível criar o bloqueio.',
          erro: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      mostrarMensagem(
        context,
        'Não foi possível conectar ao servidor.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    motivoController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo bloqueio')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: logoGBarber(tamanho: 95, mostrarNome: false)),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: corCard,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFF303030)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.content_cut, color: corAzul),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            'Barbeiro: ${widget.nomeBarbeiro}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Data do bloqueio',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: escolherData,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: corCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: corAzul),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              dataSelecionada == null
                                  ? 'Selecionar data'
                                  : formatarDataTela(dataSelecionada!),
                              style: TextStyle(
                                color: dataSelecionada == null
                                    ? corTextoSecundario
                                    : Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),

                          const Icon(
                            Icons.chevron_right,
                            color: corTextoSecundario,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: corCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: corAzul,
                      title: const Text(
                        'Bloquear o dia inteiro',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Nenhum cliente poderá marcar neste dia',
                        style: TextStyle(
                          color: corTextoSecundario,
                          fontSize: 12,
                        ),
                      ),
                      value: diaInteiro,
                      onChanged: (valor) {
                        setState(() {
                          diaInteiro = valor;

                          if (valor) {
                            horariosSelecionados.clear();
                          }
                        });
                      },
                    ),
                  ),

                  if (!diaInteiro) ...[
                    const SizedBox(height: 22),

                    const Text(
                      'Horários para bloquear',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Você pode selecionar vários horários.',
                      style: TextStyle(color: corTextoSecundario),
                    ),

                    const SizedBox(height: 14),

                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: horarios.map((horario) {
                        final selecionado = horariosSelecionados.contains(
                          horario,
                        );

                        return FilterChip(
                          label: Text(horario),
                          selected: selecionado,
                          showCheckmark: true,
                          selectedColor: const Color(0xFF24404E),
                          checkmarkColor: corAzul,
                          side: BorderSide(
                            color: selecionado
                                ? corAzul
                                : const Color(0xFF3A3A3A),
                          ),
                          labelStyle: TextStyle(
                            color: selecionado ? corAzul : Colors.white,
                            fontWeight: selecionado
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (valor) {
                            setState(() {
                              if (valor) {
                                horariosSelecionados.add(horario);
                              } else {
                                horariosSelecionados.remove(horario);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    if (horariosSelecionados.isNotEmpty) ...[
                      const SizedBox(height: 14),

                      Text(
                        '${horariosSelecionados.length} horário(s) selecionado(s)',
                        style: const TextStyle(
                          color: corAzul,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 22),

                  TextField(
                    controller: motivoController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Motivo do bloqueio (opcional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                      hintText: 'Ex: compromisso, folga, médico...',
                    ),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: carregando ? null : salvarBloqueio,
                      style: botaoPrincipal(),
                      icon: carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.block),
                      label: Text(
                        carregando ? 'SALVANDO...' : 'SALVAR BLOQUEIO',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
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

// ======================================================
// PERFIL DO BARBEIRO
// ======================================================

class PerfilBarbeiroPage extends StatefulWidget {
  final String barbeiro;
  final String nomeBarbeiro;

  const PerfilBarbeiroPage({
    super.key,
    required this.barbeiro,
    required this.nomeBarbeiro,
  });

  @override
  State<PerfilBarbeiroPage> createState() => _PerfilBarbeiroPageState();
}

class _PerfilBarbeiroPageState extends State<PerfilBarbeiroPage> {
  final nomeController = TextEditingController();
  final usuarioController = TextEditingController();
  final emailController = TextEditingController();

  final senhaAtualController = TextEditingController();
  final novaSenhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  bool carregando = true;
  bool salvando = false;
  bool alterandoSenha = false;
  bool mostrarSenhas = false;

  String fotoBase64 = '';

  @override
  void initState() {
    super.initState();
    usuarioController.text = widget.barbeiro;
    nomeController.text = widget.nomeBarbeiro;
    carregarPerfil();
  }

  Uint8List? get fotoBytes {
    if (fotoBase64.trim().isEmpty) {
      return null;
    }

    try {
      return base64Decode(fotoBase64);
    } catch (_) {
      return null;
    }
  }

  Future<void> carregarPerfil() async {
    if (mounted) {
      setState(() => carregando = true);
    }

    try {
      final resposta = await http.get(
        Uri.parse('$api/app/perfil/${widget.barbeiro}'),
        headers: headersAutenticados(),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        setState(() {
          nomeController.text = (dados['nome'] ?? widget.nomeBarbeiro)
              .toString();

          usuarioController.text = (dados['usuario'] ?? widget.barbeiro)
              .toString();

          emailController.text = (dados['email'] ?? '').toString();

          fotoBase64 = (dados['foto'] ?? '').toString();
        });
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível carregar o perfil.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Future<void> escolherFoto(ImageSource origem) async {
    try {
      final arquivo = await _imagePicker.pickImage(
        source: origem,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (arquivo == null) {
        return;
      }

      final bytes = await arquivo.readAsBytes();

      if (bytes.length > 4 * 1024 * 1024) {
        if (mounted) {
          mostrarMensagem(
            context,
            'A foto ficou muito grande. Escolha outra imagem.',
            erro: true,
          );
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        fotoBase64 = base64Encode(bytes);
      });
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível selecionar a foto.',
          erro: true,
        );
      }
    }
  }

  Future<void> abrirOpcoesFoto() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: corCard,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: corAzul,
                  ),
                  title: const Text('Escolher da galeria'),
                  onTap: () {
                    Navigator.pop(context);
                    escolherFoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: corAzul,
                  ),
                  title: const Text('Tirar foto'),
                  onTap: () {
                    Navigator.pop(context);
                    escolherFoto(ImageSource.camera);
                  },
                ),
                if (fotoBase64.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    title: const Text('Remover foto'),
                    onTap: () {
                      Navigator.pop(context);

                      setState(() {
                        fotoBase64 = '';
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> salvarPerfil() async {
    final nome = nomeController.text.trim();
    final email = emailController.text.trim();

    if (nome.isEmpty || email.isEmpty) {
      mostrarMensagem(context, 'Preencha nome e e-mail.', erro: true);
      return;
    }

    setState(() => salvando = true);

    try {
      final resposta = await http.put(
        Uri.parse('$api/app/perfil/${widget.barbeiro}'),
        headers: headersAutenticados(json: true),
        body: jsonEncode({'nome': nome, 'email': email, 'foto': fotoBase64}),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        mostrarMensagem(
          context,
          dados['mensagem']?.toString() ?? 'Perfil atualizado com sucesso!',
        );
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível atualizar o perfil.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => salvando = false);
      }
    }
  }

  Future<void> trocarSenha() async {
    final senhaAtual = senhaAtualController.text;
    final novaSenha = novaSenhaController.text;
    final confirmarSenha = confirmarSenhaController.text;

    if (senhaAtual.isEmpty || novaSenha.isEmpty || confirmarSenha.isEmpty) {
      mostrarMensagem(context, 'Preencha os três campos de senha.', erro: true);
      return;
    }

    if (novaSenha.length < 4) {
      mostrarMensagem(
        context,
        'A nova senha precisa ter pelo menos 4 caracteres.',
        erro: true,
      );
      return;
    }

    if (novaSenha != confirmarSenha) {
      mostrarMensagem(context, 'As novas senhas não coincidem.', erro: true);
      return;
    }

    setState(() => alterandoSenha = true);

    try {
      final resposta = await http.post(
        Uri.parse('$api/app/alterar-senha'),
        headers: headersAutenticados(json: true),
        body: jsonEncode({
          'usuario': widget.barbeiro,
          'senhaAtual': senhaAtual,
          'novaSenha': novaSenha,
          'confirmarSenha': confirmarSenha,
        }),
      );

      dynamic dados = {};

      try {
        dados = jsonDecode(resposta.body);
      } catch (_) {}

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        senhaAtualController.clear();
        novaSenhaController.clear();
        confirmarSenhaController.clear();

        mostrarMensagem(
          context,
          dados['mensagem']?.toString() ?? 'Senha alterada com sucesso!',
        );

        await Future.delayed(const Duration(milliseconds: 900));

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      } else {
        mostrarMensagem(
          context,
          dados['erro']?.toString() ?? 'Não foi possível alterar a senha.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => alterandoSenha = false);
      }
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    usuarioController.dispose();
    emailController.dispose();
    senhaAtualController.dispose();
    novaSenhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = fotoBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: corAzul))
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 105,
                                height: 105,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF263B45),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: corAzul, width: 2),
                                  image: bytes != null
                                      ? DecorationImage(
                                          image: MemoryImage(bytes),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: bytes == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 58,
                                        color: corAzul,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -4,
                                bottom: -2,
                                child: Material(
                                  color: corAzul,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: abrirOpcoesFoto,
                                    child: const Padding(
                                      padding: EdgeInsets.all(9),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 20,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          nomeController.text.isEmpty
                              ? widget.nomeBarbeiro
                              : nomeController.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          '@${widget.barbeiro}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: corTextoSecundario),
                        ),

                        const SizedBox(height: 10),

                        TextButton.icon(
                          onPressed: abrirOpcoesFoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            bytes == null ? 'Adicionar foto' : 'Alterar foto',
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Dados da conta',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: nomeController,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) {
                            setState(() {});
                          },
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: usuarioController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            prefixIcon: Icon(Icons.person_outline),
                            helperText:
                                'O usuário não pode ser alterado para não afetar a agenda.',
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 53,
                          child: ElevatedButton.icon(
                            onPressed: salvando ? null : salvarPerfil,
                            style: botaoPrincipal(),
                            icon: salvando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              salvando ? 'SALVANDO...' : 'SALVAR PERFIL',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        const Divider(color: Color(0xFF333333)),

                        const SizedBox(height: 22),

                        const Text(
                          'Alterar senha',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        const Text(
                          'Depois da alteração você voltará para o login para testar a nova senha.',
                          style: TextStyle(color: corTextoSecundario),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: senhaAtualController,
                          obscureText: !mostrarSenhas,
                          decoration: InputDecoration(
                            labelText: 'Senha atual',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  mostrarSenhas = !mostrarSenhas;
                                });
                              },
                              icon: Icon(
                                mostrarSenhas
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: novaSenhaController,
                          obscureText: !mostrarSenhas,
                          decoration: const InputDecoration(
                            labelText: 'Nova senha',
                            prefixIcon: Icon(Icons.password_outlined),
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: confirmarSenhaController,
                          obscureText: !mostrarSenhas,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar nova senha',
                            prefixIcon: Icon(Icons.password_outlined),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 53,
                          child: OutlinedButton.icon(
                            onPressed: alterandoSenha ? null : trocarSenha,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: corAzul,
                              side: const BorderSide(color: corAzul),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: alterandoSenha
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: corAzul,
                                    ),
                                  )
                                : const Icon(Icons.lock_reset),
                            label: Text(
                              alterandoSenha ? 'ALTERANDO...' : 'ALTERAR SENHA',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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

// ======================================================
// FUNÇÕES AUXILIARES
// ======================================================

String nomeDiaSemana(int dia) {
  switch (dia) {
    case 0:
      return 'Domingo';

    case 1:
      return 'Segunda-feira';

    case 2:
      return 'Terça-feira';

    case 3:
      return 'Quarta-feira';

    case 4:
      return 'Quinta-feira';

    case 5:
      return 'Sexta-feira';

    case 6:
      return 'Sábado';

    default:
      return 'Dia inválido';
  }
}

class AvaliacoesBarbeiroPage extends StatefulWidget {
  final String barbeiro;
  final String nomeBarbeiro;
  const AvaliacoesBarbeiroPage({
    super.key,
    required this.barbeiro,
    required this.nomeBarbeiro,
  });
  @override
  State<AvaliacoesBarbeiroPage> createState() => _AvaliacoesBarbeiroPageState();
}

class _AvaliacoesBarbeiroPageState extends State<AvaliacoesBarbeiroPage> {
  bool carregando = true;
  double media = 0;
  int total = 0;
  List<dynamic> avaliacoes = [];
  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final resposta = await http.get(
        Uri.parse('$api/app/avaliacoes/${widget.barbeiro}'),
        headers: headersAutenticados(),
      );
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        final d = jsonDecode(resposta.body);
        setState(() {
          media = double.tryParse(d['media']?.toString() ?? '') ?? 0;
          total = int.tryParse(d['total']?.toString() ?? '') ?? 0;
          avaliacoes = d['avaliacoes'] is List ? d['avaliacoes'] : [];
        });
      } else {
        mostrarMensagem(
          context,
          'Não foi possível carregar as avaliações.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted)
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliações'),
        actions: [
          IconButton(onPressed: carregar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        color: corAzul,
        onRefresh: carregar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: corCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF303030)),
              ),
              child: Column(
                children: [
                  Text(
                    widget.nomeBarbeiro,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: corAzul, size: 34),
                      const SizedBox(width: 8),
                      Text(
                        media.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$total avaliação${total == 1 ? '' : 'ões'}',
                    style: const TextStyle(color: corTextoSecundario),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (carregando)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: corAzul)),
              )
            else if (avaliacoes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Column(
                  children: [
                    Icon(
                      Icons.star_border,
                      size: 55,
                      color: corTextoSecundario,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Ainda não existem avaliações.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'As avaliações dos clientes aparecerão aqui após os atendimentos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: corTextoSecundario),
                    ),
                  ],
                ),
              )
            else
              ...avaliacoes.map((item) {
                final estrelas =
                    int.tryParse(item['estrelas']?.toString() ?? '') ?? 0;
                final comentario = (item['comentario'] ?? '').toString().trim();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: corCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF303030)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (item['cliente_nome'] ?? 'Cliente').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < estrelas ? Icons.star : Icons.star_border,
                                color: corAzul,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${item['servico'] ?? ''} • ${item['dia'] ?? ''} às ${item['horario'] ?? ''}',
                        style: const TextStyle(
                          color: corTextoSecundario,
                          fontSize: 12,
                        ),
                      ),
                      if (comentario.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '“$comentario”',
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class RelatoriosPage extends StatefulWidget {
  final String barbeiro;
  final String nomeBarbeiro;

  const RelatoriosPage({
    super.key,
    required this.barbeiro,
    required this.nomeBarbeiro,
  });

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  bool carregando = true;
  bool exportandoPdf = false;
  Map<String, dynamic> dados = {};
  late DateTime mesSelecionado;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    mesSelecionado = DateTime(agora.year, agora.month);
    carregarRelatorio();
  }

  String get mesApi =>
      '${mesSelecionado.year.toString().padLeft(4, '0')}-${mesSelecionado.month.toString().padLeft(2, '0')}';

  String get nomeMes {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${meses[mesSelecionado.month - 1]} ${mesSelecionado.year}';
  }

  Future<void> carregarRelatorio() async {
    if (mounted) setState(() => carregando = true);
    try {
      final resposta = await http.get(
        Uri.parse('$api/app/relatorios/${widget.barbeiro}?mes=$mesApi'),
        headers: headersAutenticados(),
      );
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        dados = Map<String, dynamic>.from(jsonDecode(resposta.body));
      } else {
        mostrarMensagem(
          context,
          'Não foi possível carregar o relatório.',
          erro: true,
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
          context,
          'Não foi possível conectar ao servidor.',
          erro: true,
        );
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> exportarRelatorioPdf() async {
    if (exportandoPdf) return;

    setState(() => exportandoPdf = true);

    try {
      final servicos = (dados['servicos'] as List?) ?? [];
      final clientes = (dados['top_clientes'] as List?) ?? [];

      final documento = pw.Document();

      pw.MemoryImage? logo;

      try {
        final logoBytes = await rootBundle.load('assets/images/Logo.png');
        logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {}

      final faturamento = dinheiro(numeroDouble(dados['faturamento_periodo']));
      final ticketMedio = dinheiro(numeroDouble(dados['ticket_medio']));
      final atendimentos = numeroInt(dados['atendimentos']).toString();
      final cancelamentos = numeroInt(dados['cancelamentos']).toString();

      pw.Widget cardPdf(String titulo, String valor) {
        return pw.Container(
          width: 120,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                titulo,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                valor,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }

      documento.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.7),
                ),
              ),
              child: pw.Row(
                children: [
                  if (logo != null)
                    pw.Container(
                      width: 48,
                      height: 48,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'G BARBER CLUB',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Relatório mensal - $nomeMes',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            );
          },
          build: (context) => [
            pw.SizedBox(height: 16),

            pw.Text(
              'Barbeiro: ${widget.nomeBarbeiro}',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),

            pw.Text(
              'Usuário: ${widget.barbeiro}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),

            pw.SizedBox(height: 18),

            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                cardPdf('Faturamento', faturamento),
                cardPdf('Ticket médio', ticketMedio),
                cardPdf('Atendimentos', atendimentos),
                cardPdf('Cancelamentos', cancelamentos),
              ],
            ),

            pw.SizedBox(height: 24),

            pw.Text(
              'Serviços realizados',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 8),

            if (servicos.isEmpty)
              pw.Text(
                'Nenhum atendimento finalizado neste mês.',
                style: const pw.TextStyle(color: PdfColors.grey700),
              )
            else
              pw.Table.fromTextArray(
                headers: const ['Serviço', 'Quantidade'],
                data: servicos
                    .map(
                      (item) => [
                        (item['servico'] ?? 'Não informado').toString(),
                        numeroInt(item['quantidade']).toString(),
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellPadding: const pw.EdgeInsets.all(7),
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
              ),

            pw.SizedBox(height: 24),

            pw.Text(
              'Clientes que mais voltaram',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 8),

            if (clientes.isEmpty)
              pw.Text(
                'Nenhum cliente para este período.',
                style: const pw.TextStyle(color: PdfColors.grey700),
              )
            else
              pw.Table.fromTextArray(
                headers: const ['#', 'Cliente', 'Atendimentos', 'Total gasto'],
                data: clientes.asMap().entries.map((entrada) {
                  final item = entrada.value;

                  return [
                    (entrada.key + 1).toString(),
                    (item['nome'] ?? 'Cliente').toString(),
                    numeroInt(item['atendimentos']).toString(),
                    dinheiro(numeroDouble(item['total_gasto'])),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellPadding: const pw.EdgeInsets.all(7),
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
              ),

            pw.SizedBox(height: 24),

            pw.Text(
              'Resumo adicional',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 8),

            pw.Bullet(
              text:
                  'Faturamento de hoje: ${dinheiro(numeroDouble(dados['faturamento_hoje']))}',
            ),
            pw.Bullet(
              text:
                  'Faturamento da semana: ${dinheiro(numeroDouble(dados['faturamento_semana']))}',
            ),
            pw.Bullet(
              text:
                  'Faturamento do mês atual: ${dinheiro(numeroDouble(dados['faturamento_mes_atual']))}',
            ),
          ],
        ),
      );

      final bytes = await documento.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'relatorio_${widget.barbeiro}_${mesApi.replaceAll('-', '_')}.pdf',
      );

      if (mounted) {
        mostrarMensagem(context, 'Relatório PDF gerado com sucesso!');
      }
    } catch (e) {
      debugPrint('Erro ao exportar relatório: $e');

      if (mounted) {
        mostrarMensagem(context, 'Não foi possível gerar o PDF.', erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => exportandoPdf = false);
      }
    }
  }

  void mudarMes(int diferenca) {
    setState(() {
      mesSelecionado = DateTime(
        mesSelecionado.year,
        mesSelecionado.month + diferenca,
      );
    });
    carregarRelatorio();
  }

  Widget mensagemVaziaRelatorio(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(color: corTextoSecundario),
      ),
    );
  }

  Widget cardNumero(String titulo, String valor, IconData icone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: corCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: corAzul),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(color: corTextoSecundario, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicos = (dados['servicos'] as List?) ?? [];
    final clientes = (dados['top_clientes'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: corAzul))
          : RefreshIndicator(
              color: corAzul,
              onRefresh: carregarRelatorio,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Visão financeira',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Resultados de ${widget.nomeBarbeiro}',
                    style: const TextStyle(color: corTextoSecundario),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width >= 650
                        ? 3
                        : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: MediaQuery.of(context).size.width >= 650
                        ? 2.2
                        : 1.45,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      cardNumero(
                        'Hoje',
                        dinheiro(numeroDouble(dados['faturamento_hoje'])),
                        Icons.today_outlined,
                      ),
                      cardNumero(
                        'Semana',
                        dinheiro(numeroDouble(dados['faturamento_semana'])),
                        Icons.date_range_outlined,
                      ),
                      cardNumero(
                        'Mês atual',
                        dinheiro(numeroDouble(dados['faturamento_mes_atual'])),
                        Icons.calendar_month_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => mudarMes(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          nomeMes,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: corAzul,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => mudarMes(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: exportandoPdf ? null : exportarRelatorioPdf,
                      style: botaoPrincipal(),
                      icon: exportandoPdf
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        exportandoPdf
                            ? 'GERANDO PDF...'
                            : 'EXPORTAR RELATÓRIO EM PDF',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: MediaQuery.of(context).size.width >= 650
                        ? 2.5
                        : 1.45,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      cardNumero(
                        'Faturamento',
                        dinheiro(numeroDouble(dados['faturamento_periodo'])),
                        Icons.attach_money,
                      ),
                      cardNumero(
                        'Ticket médio',
                        dinheiro(numeroDouble(dados['ticket_medio'])),
                        Icons.receipt_long_outlined,
                      ),
                      cardNumero(
                        'Atendimentos',
                        numeroInt(dados['atendimentos']).toString(),
                        Icons.content_cut,
                      ),
                      cardNumero(
                        'Cancelamentos',
                        numeroInt(dados['cancelamentos']).toString(),
                        Icons.cancel_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Serviços realizados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (servicos.isEmpty)
                    mensagemVaziaRelatorio(
                      'Nenhum atendimento finalizado neste mês.',
                    ),
                  ...servicos.map(
                    (item) => Card(
                      color: corCard,
                      child: ListTile(
                        leading: const Icon(Icons.content_cut, color: corAzul),
                        title: Text(
                          (item['servico'] ?? 'Não informado').toString(),
                        ),
                        trailing: Text(
                          '${numeroInt(item['quantidade'])}x',
                          style: const TextStyle(
                            color: corAzul,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Clientes que mais voltaram',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (clientes.isEmpty)
                    mensagemVaziaRelatorio('Nenhum cliente para este período.'),
                  ...clientes.asMap().entries.map((entrada) {
                    final item = entrada.value;
                    return Card(
                      color: corCard,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF263B45),
                          child: Text(
                            '${entrada.key + 1}',
                            style: const TextStyle(
                              color: corAzul,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text((item['nome'] ?? 'Cliente').toString()),
                        subtitle: Text(
                          '${numeroInt(item['atendimentos'])} atendimento(s)',
                        ),
                        trailing: Text(
                          dinheiro(numeroDouble(item['total_gasto'])),
                          style: const TextStyle(
                            color: corAzul,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

String formatarData(String data) {
  if (data.isEmpty) {
    return '';
  }

  final partes = data.split('-');

  if (partes.length != 3) {
    return data;
  }

  return '${partes[2]}/${partes[1]}/${partes[0]}';
}

String dinheiro(double valor) {
  return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
}

int numeroInt(dynamic valor) {
  if (valor is int) {
    return valor;
  }

  if (valor is num) {
    return valor.toInt();
  }

  return int.tryParse(valor?.toString() ?? '') ?? 0;
}

double numeroDouble(dynamic valor) {
  if (valor is num) {
    return valor.toDouble();
  }

  return double.tryParse(valor?.toString() ?? '') ?? 0;
}
