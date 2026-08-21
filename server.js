const express = require("express");
const cors = require("cors");
const sqlite3 = require("sqlite3").verbose();

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static(__dirname));

// ===============================
// BANCO DE DADOS
// ===============================

const db = new sqlite3.Database("./barbearia.db", (erro) => {
  if (erro) {
    console.log("Erro ao conectar no banco:", erro.message);
  } else {
    console.log("Banco de dados conectado!");
  }
});

// cria a tabela caso ela ainda não exista
db.run(`
  CREATE TABLE IF NOT EXISTS agendamentos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    numero TEXT,
    dia TEXT,
    horario TEXT NOT NULL,
    barbeiro TEXT NOT NULL,
    servico TEXT,
    valor REAL DEFAULT 0,
    status TEXT DEFAULT 'Confirmado',
    fixo INTEGER DEFAULT 0,
    dia_semana INTEGER
  )
`);

// adiciona a coluna valor caso seu banco antigo ainda não tenha
db.run(`
  ALTER TABLE agendamentos
  ADD COLUMN valor REAL DEFAULT 0
`, (erro) => {
  if (erro && !erro.message.includes("duplicate column name")) {
    console.log("Erro ao verificar coluna valor:", erro.message);
  }
});

// ===============================
// HORÁRIOS
// ===============================

const horariosBase = [
  "08:00",
  "08:40",
  "09:20",
  "10:00",
  "10:40",
  "11:20",
  "12:00",
  "12:40",
  "13:20",
  "14:00",
  "14:40",
  "15:20",
  "16:00",
  "16:40",
  "17:20",
  "18:00",
  "18:40",
  "19:20",
  "20:00",
];

// ===============================
// HORÁRIOS LIVRES
// ===============================

app.get("/horarios-livres/:data/:barbeiro", (req, res) => {
  const data = req.params.data;
  const barbeiro = req.params.barbeiro;

  const dataSelecionada = new Date(data + "T12:00:00");
  const diaSemana = dataSelecionada.getDay();

  db.all(
    `
    SELECT horario
    FROM agendamentos
    WHERE barbeiro = ?
    AND (
      dia = ?
      OR
      (fixo = 1 AND dia_semana = ?)
    )
    `,
    [barbeiro, data, diaSemana],
    (erro, linhas) => {
      if (erro) {
        console.log(erro);

        return res.status(500).json({
          erro: "Erro ao buscar horários",
        });
      }

      const ocupados = linhas.map((a) => a.horario);

      const livres = horariosBase.filter(
        (horario) => !ocupados.includes(horario)
      );

      res.json(livres);
    }
  );
});

// ===============================
// CRIAR AGENDAMENTO NORMAL
// ===============================

app.post("/agendar", (req, res) => {
  const {
    nome,
    numero,
    dia,
    horario,
    barbeiro,
    servico,
    valor,
  } = req.body;

  const barbeiroFinal = barbeiro || "gustavo";
  const servicoFinal = servico || "Corte";
  const valorFinal = Number(valor || 0);

  const dataSelecionada = new Date(dia + "T12:00:00");
  const diaSemana = dataSelecionada.getDay();

  db.get(
    `
    SELECT *
    FROM agendamentos
    WHERE barbeiro = ?
    AND horario = ?
    AND (
      dia = ?
      OR
      (fixo = 1 AND dia_semana = ?)
    )
    `,
    [barbeiroFinal, horario, dia, diaSemana],
    (erro, ocupado) => {
      if (erro) {
        console.log(erro);

        return res.status(500).json({
          sucesso: false,
        });
      }

      if (ocupado) {
        return res.json({
          sucesso: false,
          mensagem: "Horário já ocupado",
        });
      }

      db.run(
        `
        INSERT INTO agendamentos
        (
          nome,
          numero,
          dia,
          horario,
          barbeiro,
          servico,
          valor,
          status,
          fixo
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `,
        [
          nome,
          numero,
          dia,
          horario,
          barbeiroFinal,
          servicoFinal,
          valorFinal,
          "Confirmado",
          0,
        ],
        function (erro) {
          if (erro) {
            console.log(erro);

            return res.status(500).json({
              sucesso: false,
            });
          }

          console.log(
            "Novo agendamento:",
            nome,
            dia,
            horario,
            "R$",
            valorFinal
          );

          res.json({
            sucesso: true,
            id: this.lastID,
          });
        }
      );
    }
  );
});

// ===============================
// CRIAR HORÁRIO FIXO
// ===============================

app.post("/agendar-fixo", (req, res) => {
  const {
    nome,
    numero,
    diaSemana,
    horario,
    barbeiro,
    servico,
    valor,
  } = req.body;

  const barbeiroFinal = barbeiro || "gustavo";
  const servicoFinal = servico || "Corte";
  const valorFinal = Number(valor || 0);

  db.get(
    `
    SELECT *
    FROM agendamentos
    WHERE barbeiro = ?
    AND horario = ?
    AND fixo = 1
    AND dia_semana = ?
    `,
    [barbeiroFinal, horario, diaSemana],
    (erro, ocupado) => {
      if (erro) {
        return res.status(500).json({
          sucesso: false,
        });
      }

      if (ocupado) {
        return res.json({
          sucesso: false,
          mensagem: "Esse horário fixo já está ocupado",
        });
      }

      db.run(
        `
        INSERT INTO agendamentos
        (
          nome,
          numero,
          horario,
          barbeiro,
          servico,
          valor,
          status,
          fixo,
          dia_semana
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `,
        [
          nome,
          numero,
          horario,
          barbeiroFinal,
          servicoFinal,
          valorFinal,
          "Confirmado",
          1,
          diaSemana,
        ],
        function (erro) {
          if (erro) {
            return res.status(500).json({
              sucesso: false,
            });
          }

          res.json({
            sucesso: true,
            id: this.lastID,
          });
        }
      );
    }
  );
});

// ===============================
// BUSCAR TODOS DO BARBEIRO
// ===============================

app.get("/agendamentos/:barbeiro", (req, res) => {
  const barbeiro = req.params.barbeiro;

  db.all(
    `
    SELECT *
    FROM agendamentos
    WHERE barbeiro = ?
    ORDER BY dia, horario
    `,
    [barbeiro],
    (erro, linhas) => {
      if (erro) {
        return res.status(500).json({
          erro: "Erro ao buscar agendamentos",
        });
      }

      res.json(linhas);
    }
  );
});

// ===============================
// APP - AGENDAMENTOS DE HOJE
// ===============================

app.get("/app/agendamentos-hoje/:barbeiro", (req, res) => {
  const barbeiro = req.params.barbeiro;

  const hoje = new Date();

  const ano = hoje.getFullYear();
  const mes = String(hoje.getMonth() + 1).padStart(2, "0");
  const dia = String(hoje.getDate()).padStart(2, "0");

  const dataHoje = `${ano}-${mes}-${dia}`;
  const diaSemana = hoje.getDay();

  db.all(
    `
    SELECT *
    FROM agendamentos
    WHERE barbeiro = ?
    AND (
      dia = ?
      OR
      (fixo = 1 AND dia_semana = ?)
    )
    ORDER BY horario
    `,
    [barbeiro, dataHoje, diaSemana],
    (erro, linhas) => {
      if (erro) {
        console.log(erro);

        return res.status(500).json({
          erro: "Erro ao buscar agendamentos de hoje",
        });
      }

      res.json(linhas);
    }
  );
});

// ===============================
// APP - RESUMO FINANCEIRO DO DIA
// ===============================

app.get("/app/resumo-hoje/:barbeiro", (req, res) => {
  const barbeiro = req.params.barbeiro;

  const hoje = new Date();

  const ano = hoje.getFullYear();
  const mes = String(hoje.getMonth() + 1).padStart(2, "0");
  const dia = String(hoje.getDate()).padStart(2, "0");

  const dataHoje = `${ano}-${mes}-${dia}`;
  const diaSemana = hoje.getDay();

  db.all(
    `
    SELECT *
    FROM agendamentos
    WHERE barbeiro = ?
    AND (
      dia = ?
      OR
      (fixo = 1 AND dia_semana = ?)
    )
    `,
    [barbeiro, dataHoje, diaSemana],
    (erro, linhas) => {
      if (erro) {
        console.log(erro);

        return res.status(500).json({
          erro: "Erro ao calcular resumo",
        });
      }

      const totalAgendamentos = linhas.length;

      const previsto = linhas.reduce((total, agendamento) => {
        return total + Number(agendamento.valor || 0);
      }, 0);

      const recebido = linhas
        .filter((agendamento) => agendamento.status === "Finalizado")
        .reduce((total, agendamento) => {
          return total + Number(agendamento.valor || 0);
        }, 0);

      const pendente = previsto - recebido;

      res.json({
        agendamentos: totalAgendamentos,
        previsto,
        recebido,
        pendente,
      });
    }
  );
});

// ===============================
// APP - HORÁRIOS FIXOS
// ===============================

app.get("/app/fixos/:barbeiro", (req, res) => {
  const barbeiro = req.params.barbeiro;

  db.all(
    `
    SELECT *
    FROM agendamentos
    WHERE barbeiro = ?
    AND fixo = 1
    ORDER BY dia_semana, horario
    `,
    [barbeiro],
    (erro, linhas) => {
      if (erro) {
        return res.status(500).json({
          erro: "Erro ao buscar horários fixos",
        });
      }

      res.json(linhas);
    }
  );
});

// ===============================
// FINALIZAR CORTE
// ===============================

app.put("/finalizar/:id", (req, res) => {
  const id = req.params.id;

  db.run(
    `
    UPDATE agendamentos
    SET status = 'Finalizado'
    WHERE id = ?
    `,
    [id],
    function (erro) {
      if (erro) {
        return res.status(500).json({
          sucesso: false,
        });
      }

      if (this.changes === 0) {
        return res.status(404).json({
          erro: "Agendamento não encontrado",
        });
      }

      res.json({
        sucesso: true,
      });
    }
  );
});

// ===============================
// CANCELAR AGENDAMENTO
// ===============================

app.delete("/cancelar/:id", (req, res) => {
  const id = req.params.id;

  db.run(
    `
    DELETE FROM agendamentos
    WHERE id = ?
    `,
    [id],
    function (erro) {
      if (erro) {
        return res.status(500).json({
          sucesso: false,
        });
      }

      if (this.changes === 0) {
        return res.status(404).json({
          erro: "Agendamento não encontrado",
        });
      }

      res.json({
        sucesso: true,
      });
    }
  );
});

// ===============================
// LISTAR HORÁRIOS FIXOS
// ===============================

app.get("/agendamentos-fixos/:barbeiro", (req, res) => {
  const barbeiro = req.params.barbeiro;

  db.all(
    `
    SELECT *
    FROM agendamentos
    WHERE barbeiro = ?
    AND fixo = 1
    ORDER BY dia_semana, horario
    `,
    [barbeiro],
    (erro, linhas) => {
      if (erro) {
        return res.status(500).json({
          erro: "Erro ao buscar horários fixos",
        });
      }

      res.json(linhas);
    }
  );
});

// ===============================
// TESTE DA API
// ===============================

app.get("/api", (req, res) => {
  res.json({
    online: true,
    mensagem: "API da barbearia funcionando",
  });
});

// ===============================
// SERVIDOR
// ===============================

const PORT = process.env.PORT || 3000;

app.listen(PORT, "0.0.0.0", () => {
  console.log("Servidor rodando na porta " + PORT);
  console.log("No computador: http://localhost:" + PORT);
});