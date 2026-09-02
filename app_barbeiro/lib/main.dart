import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String api = 'http://192.168.0.131:3000';

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
  final messaging = FirebaseMessaging.instance;

  final permissao = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  debugPrint('Permissão de notificação: ${permissao.authorizationStatus}');

  final token = await messaging.getToken();

  debugPrint('==============================');
  debugPrint('TOKEN FIREBASE DO APARELHO:');
  debugPrint(token);
  debugPrint('==============================');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Notificação recebida com app aberto');
    debugPrint('Título: ${message.notification?.title}');
    debugPrint('Mensagem: ${message.notification?.body}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Usuário abriu a notificação.');
  });
}

Future<void> registrarTokenPush(String barbeiro) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();

    if (token == null || token.trim().isEmpty) {
      return;
    }

    await http.post(
      Uri.parse('$api/app/push-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'barbeiro': barbeiro, 'token': token}),
    );
  } catch (e) {
    debugPrint('Erro ao registrar token push: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await configurarNotificacoes();

  runApp(const GBarberClubApp());
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

  final TextEditingController pesquisaHistoricoController =
      TextEditingController();
  String? dataFiltroHistorico;

  int total = 0;

  double previsto = 0;
  double recebido = 0;
  double pendente = 0;

  int pagina = 0;

  bool carregando = true;

  Timer? timer;
  StreamSubscription<String>? tokenRefreshSubscription;

  @override
  void initState() {
    super.initState();

    carregarTudo();

    registrarTokenPush(widget.barbeiro);

    tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        try {
          await http.post(
            Uri.parse('$api/app/push-token'),
            headers: {'Content-Type': 'application/json'},
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
        http.get(Uri.parse('$api/app/agendamentos-hoje/${widget.barbeiro}')),
        http.get(Uri.parse('$api/app/agendamentos-semana/${widget.barbeiro}')),
        http.get(Uri.parse('$api/app/resumo-hoje/${widget.barbeiro}')),
        http.get(Uri.parse('$api/app/fixos/${widget.barbeiro}')),
        http.get(Uri.parse('$api/app/bloqueios/${widget.barbeiro}')),
        http.get(Uri.parse('$api/app/historico/${widget.barbeiro}')),
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
      final resposta = await http.put(Uri.parse('$api/finalizar/$id'));

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
      final resposta = await http.delete(Uri.parse('$api/cancelar/$id'));

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
      final resposta = await http.delete(Uri.parse('$api/app/fixos/$id'));

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
      final resposta = await http.delete(Uri.parse('$api/app/bloqueios/$id'));

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
    final titulos = [
      'Hoje',
      'Semana',
      'Horários fixos',
      'Bloqueios',
      'Histórico',
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        titleSpacing: 15,
        title: Row(
          children: [
            Image.asset(
              'assets/images/Logo.png',
              width: 45,
              height: 45,
              fit: BoxFit.contain,
            ),

            const SizedBox(width: 10),

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
                    widget.nome,
                    style: const TextStyle(fontSize: 12, color: corAzul),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: carregarTudo, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
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
          ? telaFixos()
          : pagina == 3
          ? telaBloqueios()
          : telaHistorico(),

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
            icon: Icon(Icons.event_repeat_outlined),
            selectedIcon: Icon(Icons.event_repeat, color: corAzul),
            label: 'Fixos',
          ),
          NavigationDestination(
            icon: Icon(Icons.block_outlined),
            selectedIcon: Icon(Icons.block, color: corAzul),
            label: 'Bloqueios',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: corAzul),
            label: 'Histórico',
          ),
        ],
      ),
    );
  }

  // ====================================================
  // TELA HOJE
  // ====================================================

  Widget telaHoje() {
    return RefreshIndicator(
      color: corAzul,
      onRefresh: carregarTudo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Resumo do dia',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final largura = constraints.maxWidth;

              int colunas;
              double proporcao;

              if (largura >= 900) {
                colunas = 4;
                proporcao = 3.0;
              } else if (largura >= 600) {
                colunas = 4;
                proporcao = 2.2;
              } else {
                colunas = 2;
                proporcao = 1.8;
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
                    titulo: 'Agendamentos',
                    valor: '$total',
                    icone: Icons.calendar_month_outlined,
                    cor: corAzul,
                  ),
                  cardResumo(
                    titulo: 'Previsto',
                    valor: dinheiro(previsto),
                    icone: Icons.trending_up,
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
                ],
              );
            },
          ),

          const SizedBox(height: 27),

          const Row(
            children: [
              Icon(Icons.content_cut, color: corAzul),
              SizedBox(width: 9),
              Text(
                'Agendamentos de hoje',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (hoje.isEmpty) mensagemVazia('Nenhum agendamento para hoje.'),

          ...hoje.map((item) => cardAgendamento(item)),
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

  Widget cardAgendamento(dynamic item, {bool mostrarData = false}) {
    final finalizado =
        (item['status'] ?? '').toString().toLowerCase() == 'finalizado';

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
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            if (finalizado)
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
