import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const BarberApp());
}

class BarberApp extends StatelessWidget {
  const BarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'G Barber Club',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PainelBarbeiro(),
    );
  }
}

class PainelBarbeiro extends StatefulWidget {
  const PainelBarbeiro({super.key});

  @override
  State<PainelBarbeiro> createState() => _PainelBarbeiroState();
}

class _PainelBarbeiroState extends State<PainelBarbeiro> {
  // ============================================================
  // IMPORTANTE:
  // Android Emulator -> 10.0.2.2
  //
  // Se estiver usando celular físico, depois vamos trocar
  // pelo IP do seu computador.
  // ============================================================

  final String api = 'http://10.133.126.16:3000';

  final String barbeiro = 'gustavo';

  List<dynamic> agendamentos = [];

  int totalAgendamentos = 0;
  double previsto = 0;
  double recebido = 0;
  double pendente = 0;

  bool carregando = true;
  String? erro;

  Timer? atualizador;

  @override
  void initState() {
    super.initState();

    carregarTudo();

    // Atualiza automaticamente a cada 5 segundos.
    atualizador = Timer.periodic(
      const Duration(seconds: 5),
      (_) => carregarTudo(silencioso: true),
    );
  }

  @override
  void dispose() {
    atualizador?.cancel();
    super.dispose();
  }

  // ============================================================
  // CARREGAR DADOS
  // ============================================================

  Future<void> carregarTudo({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() {
        carregando = true;
        erro = null;
      });
    }

    try {
      await Future.wait([
        carregarAgendamentos(),
        carregarResumo(),
      ]);

      if (mounted) {
        setState(() {
          carregando = false;
          erro = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          carregando = false;
          erro = 'Não foi possível conectar ao servidor.';
        });
      }
    }
  }

  // ============================================================
  // AGENDAMENTOS DE HOJE
  // ============================================================

  Future<void> carregarAgendamentos() async {
    final resposta = await http.get(
      Uri.parse('$api/app/agendamentos-hoje/$barbeiro'),
    );

    if (resposta.statusCode != 200) {
      throw Exception('Erro ao buscar agendamentos');
    }

    final dados = jsonDecode(resposta.body);

    if (mounted) {
      setState(() {
        agendamentos = dados;
      });
    }
  }

  // ============================================================
  // RESUMO FINANCEIRO
  // ============================================================

  Future<void> carregarResumo() async {
    final resposta = await http.get(
      Uri.parse('$api/app/resumo-hoje/$barbeiro'),
    );

    if (resposta.statusCode != 200) {
      throw Exception('Erro ao buscar resumo');
    }

    final dados = jsonDecode(resposta.body);

    if (mounted) {
      setState(() {
        totalAgendamentos = dados['agendamentos'] ?? 0;

        previsto = (dados['previsto'] ?? 0).toDouble();
        recebido = (dados['recebido'] ?? 0).toDouble();
        pendente = (dados['pendente'] ?? 0).toDouble();
      });
    }
  }

  // ============================================================
  // FINALIZAR
  // ============================================================

  Future<void> finalizar(int id) async {
    final resposta = await http.put(
      Uri.parse('$api/finalizar/$id'),
    );

    if (resposta.statusCode == 200) {
      await carregarTudo();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Atendimento finalizado!'),
        ),
      );
    }
  }

  // ============================================================
  // CANCELAR
  // ============================================================

  Future<void> cancelar(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar agendamento'),
          content: const Text(
            'Tem certeza que deseja cancelar este agendamento?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Não'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Cancelar agendamento'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    final resposta = await http.delete(
      Uri.parse('$api/cancelar/$id'),
    );

    if (resposta.statusCode == 200) {
      await carregarTudo();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendamento cancelado.'),
        ),
      );
    }
  }

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'G BARBER CLUB',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Painel do barbeiro',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: carregarTudo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: carregarTudo,
        child: carregando
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : erro != null
                ? telaErro()
                : painel(),
      ),
    );
  }

  // ============================================================
  // ERRO
  // ============================================================

  Widget telaErro() {
    return ListView(
      children: [
        const SizedBox(height: 180),
        const Icon(
          Icons.wifi_off,
          size: 70,
          color: Colors.white38,
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            erro!,
            style: const TextStyle(
              fontSize: 17,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: carregarTudo,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAINEL
  // ============================================================

  Widget painel() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Hoje',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Olá, ${primeiraMaiuscula(barbeiro)} 👋',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 25),

        Row(
          children: [
            Expanded(
              child: cardResumo(
                titulo: 'Agendamentos',
                valor: '$totalAgendamentos',
                icone: Icons.calendar_month,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: cardResumo(
                titulo: 'Previsto',
                valor: dinheiro(previsto),
                icone: Icons.trending_up,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: cardResumo(
                titulo: 'Recebido',
                valor: dinheiro(recebido),
                icone: Icons.payments,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: cardResumo(
                titulo: 'Pendente',
                valor: dinheiro(pendente),
                icone: Icons.schedule,
              ),
            ),
          ],
        ),

        const SizedBox(height: 35),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Agenda de hoje',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${agendamentos.length} clientes',
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        if (agendamentos.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.event_available,
                  size: 45,
                  color: Colors.white38,
                ),
                SizedBox(height: 12),
                Text(
                  'Nenhum agendamento para hoje.',
                  style: TextStyle(
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),

        ...agendamentos.map(
          (agendamento) => cardAgendamento(agendamento),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ============================================================
  // CARD RESUMO
  // ============================================================

  Widget cardResumo({
    required String titulo,
    required String valor,
    required IconData icone,
  }) {
    return Container(
      height: 125,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icone,
            color: const Color(0xFFD4AF37),
          ),
          const Spacer(),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD AGENDAMENTO
  // ============================================================

  Widget cardAgendamento(dynamic agendamento) {
    final finalizado = agendamento['status'] == 'Finalizado';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 65,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  agendamento['horario'] ?? '--:--',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFD4AF37),
                  ),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agendamento['nome'] ?? 'Cliente',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      agendamento['servico'] ?? 'Serviço',
                      style: const TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                dinheiro(
                  (agendamento['valor'] ?? 0).toDouble(),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: finalizado
                    ? const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 7),
                          Text('Finalizado'),
                        ],
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          finalizar(agendamento['id']);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Finalizar'),
                      ),
              ),

              if (!finalizado) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () {
                    cancelar(agendamento['id']);
                  },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Cancelar',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UTILIDADES
  // ============================================================

  String dinheiro(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String primeiraMaiuscula(String texto) {
    if (texto.isEmpty) return texto;

    return texto[0].toUpperCase() + texto.substring(1);
  }
}