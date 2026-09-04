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

const String api = 'http://10.133.126.27:3000';

String authToken = '';

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
      home: const LoginPage(),
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

                  const SizedBox(height: 15),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CadastroPage()),
                      );
                    },
                    child: const Text(
                      'Primeiro acesso? Cadastre-se',
                      style: TextStyle(color: Colors.white),
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
// CADASTRO
// ======================================================

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
  List<dynamic> hoje = [];
  List<dynamic> semana = [];
  List<dynamic> fixos = [];
  List<dynamic> bloqueios = [];
  List<dynamic> historico = [];
  List<dynamic> clientes = [];

  final TextEditingController pesquisaHistoricoController =
      TextEditingController();
  final TextEditingController pesquisaClientesController =
      TextEditingController();
  String? dataFiltroHistorico;

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
        final resumo = jsonDecode(respostas[2].body);

        total = numeroInt(resumo['total']);
        previsto = numeroDouble(resumo['previsto']);
        recebido = numeroDouble(resumo['recebido']);
        pendente = numeroDouble(resumo['pendente']);
      }

      if (respostas[3].statusCode == 200) {
        fixos = jsonDecode(respostas[3].body);
      }

      if (respostas[4].statusCode == 200) {
        bloqueios = jsonDecode(respostas[4].body);
      }

      if (respostas[5].statusCode == 200) {
        historico = jsonDecode(respostas[5].body);
      }

      if (respostas[6].statusCode == 200) {
        clientes = jsonDecode(respostas[6].body);
      }

      if (respostas[7].statusCode == 200) {
        final perfil = jsonDecode(respostas[7].body);

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

      return minutosDoHorario(horarioA).compareTo(
        minutosDoHorario(horarioB),
      );
    });

    return lista;
  }

  dynamic proximoAgendamentoHoje() {
    final lista = agendamentosHojeOrdenados()
        .where(
          (item) =>
              !agendamentoFinalizado(item) &&
              !agendamentoCancelado(item),
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
        border: Border.all(
          color: corAzul.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
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
              const Icon(
                Icons.schedule_outlined,
                color: corAzul,
                size: 19,
              ),
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
            style: const TextStyle(
              color: corTextoSecundario,
              fontSize: 14,
            ),
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
                  icon: const Icon(
                    Icons.edit_calendar_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'REMARCAR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: corAzul,
                    ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
              const Icon(
                Icons.content_cut,
                color: corAzul,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Agenda de hoje',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${listaHoje.length} horário${listaHoje.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: corTextoSecundario,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (listaHoje.isEmpty)
            mensagemVazia('Nenhum agendamento para hoje.'),

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
    return RefreshIndicator(
      color: corAzul,
      onRefresh: carregarTudo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Agenda da semana',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 7),

          const Text(
            'Todos os seus horários desta semana',
            style: TextStyle(color: corTextoSecundario),
          ),

          const SizedBox(height: 18),

          if (semana.isEmpty) mensagemVazia('Nenhum agendamento nesta semana.'),

          ...semana.map((item) => cardAgendamento(item, mostrarData: true)),
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
