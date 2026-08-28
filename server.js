require("dotenv").config();

const express = require("express");
const cors = require("cors");
const sqlite3 = require("sqlite3").verbose();
const crypto = require("crypto");
const nodemailer = require("nodemailer");

const app = express();
const PORT = 3000;

// ======================================================
// MIDDLEWARES
// ======================================================

app.use(cors());
app.use(express.json());
app.use(express.static(__dirname));

// ======================================================
// BANCO DE DADOS
// ======================================================

const db = new sqlite3.Database("./barbearia.db", (erro) => {
  if (erro) {
    console.error("Erro ao conectar ao banco:", erro.message);
  } else {
    console.log("Banco de dados conectado!");
  }
});

// ======================================================
// TABELA DE AGENDAMENTOS
// ======================================================

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

db.all(`PRAGMA table_info(agendamentos)`, (erro, colunas) => {
  if (erro) return;

  const temValor = colunas.some((coluna) => coluna.name === "valor");

  if (!temValor) {
    db.run(`
      ALTER TABLE agendamentos
      ADD COLUMN valor REAL DEFAULT 0
    `);
  }
});

// ======================================================
// TABELA DE BARBEIROS
// ======================================================

db.run(`
  CREATE TABLE IF NOT EXISTS barbeiros (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    usuario TEXT UNIQUE NOT NULL,
    email TEXT,
    senha_hash TEXT NOT NULL,
    senha_salt TEXT NOT NULL
  )
`);

db.all(`PRAGMA table_info(barbeiros)`, (erro, colunas) => {
  if (erro) {
    console.error("Erro ao verificar tabela barbeiros:", erro);
    return;
  }

  const temEmail = colunas.some((coluna) => coluna.name === "email");

  if (!temEmail) {
    db.run(`ALTER TABLE barbeiros ADD COLUMN email TEXT`, (erroAlteracao) => {
      if (erroAlteracao) {
        console.error("Erro ao adicionar coluna email:", erroAlteracao.message);
      } else {
        console.log("Coluna email adicionada aos barbeiros!");
      }
    });
  }
});

// ======================================================
// RECUPERAÇÃO DE SENHA
// ======================================================

db.run(`
  CREATE TABLE IF NOT EXISTS recuperacao_senha (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    barbeiro_id INTEGER NOT NULL,
    codigo_hash TEXT NOT NULL,
    expira_em INTEGER NOT NULL,
    usado INTEGER DEFAULT 0,
    FOREIGN KEY (barbeiro_id) REFERENCES barbeiros(id)
  )
`);

// ======================================================
// EMAIL - GMAIL
// ======================================================

const transporter = nodemailer.createTransport({
  service: "gmail",

  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
  transporter.verify((erro) => {
    if (erro) {
      console.log("Erro na configuração do e-mail:", erro.message);
    } else {
      console.log("Servidor de e-mail pronto!");
    }
  });
} else {
  console.log("AVISO: EMAIL_USER ou EMAIL_PASS não configurado no .env");
}

// ======================================================
// HORÁRIOS
// ======================================================

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

// ======================================================
// FUNÇÕES
// ======================================================

function normalizarBarbeiro(nome) {
  return String(nome || "")
    .trim()
    .toLowerCase();
}

function barbeiroTrabalhaNoDia(barbeiro, diaSemana) {
  barbeiro = normalizarBarbeiro(barbeiro);

  // Domingo = 0
  // Segunda = 1
  // Terça = 2
  // Quarta = 3
  // Quinta = 4
  // Sexta = 5
  // Sábado = 6

  if (barbeiro === "gustavo") {
    return diaSemana === 6;
  }

  if (barbeiro === "guel") {
    return [3, 4, 5, 6].includes(diaSemana);
  }

  return false;
}

function criarHashSenha(senha, salt) {
  return crypto.scryptSync(senha, salt, 64).toString("hex");
}

function gerarSenhaSegura(senha) {
  const salt = crypto.randomBytes(16).toString("hex");

  const hash = criarHashSenha(senha, salt);

  return {
    salt,
    hash,
  };
}

function verificarSenha(senha, salt, hashSalvo) {
  const hashInformado = criarHashSenha(senha, salt);

  const bufferInformado = Buffer.from(hashInformado, "hex");

  const bufferSalvo = Buffer.from(hashSalvo, "hex");

  if (bufferInformado.length !== bufferSalvo.length) {
    return false;
  }

  return crypto.timingSafeEqual(bufferInformado, bufferSalvo);
}

function dataHoje() {
  const agora = new Date();

  const ano = agora.getFullYear();

  const mes = String(agora.getMonth() + 1).padStart(2, "0");

  const dia = String(agora.getDate()).padStart(2, "0");

  return `${ano}-${mes}-${dia}`;
}

function dataParaString(data) {
  const ano = data.getFullYear();

  const mes = String(data.getMonth() + 1).padStart(2, "0");

  const dia = String(data.getDate()).padStart(2, "0");

  return `${ano}-${mes}-${dia}`;
}

function criarDataLocal(dataString) {
  return new Date(`${dataString}T12:00:00`);
}

function gerarCodigo() {
  return crypto.randomInt(100000, 1000000).toString();
}

function hashCodigo(codigo) {
  return crypto.createHash("sha256").update(codigo).digest("hex");
}

// ======================================================
// TESTE DA API
// ======================================================

app.get("/api", (req, res) => {
  res.json({
    online: true,
    mensagem: "API da G Barber Club funcionando!",
  });
});

// ======================================================
// CADASTRAR BARBEIRO
// ======================================================

app.post("/app/cadastrar-barbeiro", (req, res) => {
  let { nome, usuario, email, senha, confirmarSenha } = req.body;

  nome = String(nome || "").trim();

  usuario = normalizarBarbeiro(usuario);

  email = String(email || "")
    .trim()
    .toLowerCase();

  if (!nome || !usuario || !email || !senha || !confirmarSenha) {
    return res.status(400).json({
      erro: "Preencha todos os campos.",
    });
  }

  const emailValido = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!emailValido.test(email)) {
    return res.status(400).json({
      erro: "Digite um e-mail válido.",
    });
  }

  if (senha.length < 4) {
    return res.status(400).json({
      erro: "A senha precisa ter pelo menos 4 caracteres.",
    });
  }

  if (senha !== confirmarSenha) {
    return res.status(400).json({
      erro: "As senhas não coincidem.",
    });
  }

  db.get(
    `
        SELECT *
        FROM barbeiros
        WHERE usuario = ?
           OR LOWER(email) = LOWER(?)
      `,
    [usuario, email],
    (erro, barbeiroExistente) => {
      if (erro) {
        console.error(erro);

        return res.status(500).json({
          erro: "Erro ao verificar cadastro.",
        });
      }

      if (barbeiroExistente) {
        return res.status(400).json({
          erro: "Usuário ou e-mail já cadastrado.",
        });
      }

      const { salt, hash } = gerarSenhaSegura(senha);

      db.run(
        `
            INSERT INTO barbeiros
            (
              nome,
              usuario,
              email,
              senha_hash,
              senha_salt
            )
            VALUES (?, ?, ?, ?, ?)
          `,
        [nome, usuario, email, hash, salt],
        function (erroInsert) {
          if (erroInsert) {
            console.error(erroInsert);

            return res.status(500).json({
              erro: "Não foi possível realizar o cadastro.",
            });
          }

          res.json({
            sucesso: true,
            mensagem: "Cadastro realizado com sucesso!",
          });
        },
      );
    },
  );
});

// ======================================================
// LOGIN
// ======================================================

app.post("/app/login", (req, res) => {
  const usuario = normalizarBarbeiro(req.body.usuario);

  const senha = String(req.body.senha || "");

  if (!usuario || !senha) {
    return res.status(400).json({
      erro: "Informe usuário e senha.",
    });
  }

  db.get(
    `
      SELECT *
      FROM barbeiros
      WHERE usuario = ?
    `,
    [usuario],
    (erro, barbeiro) => {
      if (erro) {
        console.error(erro);

        return res.status(500).json({
          erro: "Erro no banco de dados.",
        });
      }

      if (!barbeiro) {
        return res.status(401).json({
          erro: "Usuário ou senha incorretos.",
        });
      }

      const senhaCorreta = verificarSenha(
        senha,
        barbeiro.senha_salt,
        barbeiro.senha_hash,
      );

      if (!senhaCorreta) {
        return res.status(401).json({
          erro: "Usuário ou senha incorretos.",
        });
      }

      res.json({
        sucesso: true,
        barbeiro: barbeiro.usuario,
        nome: barbeiro.nome,
        email: barbeiro.email,
      });
    },
  );
});

// ======================================================
// ESQUECI MINHA SENHA
// ======================================================

app.post("/app/esqueci-senha", (req, res) => {
  const email = String(req.body.email || "")
    .trim()
    .toLowerCase();

  if (!email) {
    return res.status(400).json({
      erro: "Informe seu e-mail.",
    });
  }

  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
    return res.status(500).json({
      erro: "Servidor de e-mail não configurado.",
    });
  }

  db.get(
    `
        SELECT *
        FROM barbeiros
        WHERE LOWER(email) = LOWER(?)
      `,
    [email],
    async (erro, barbeiro) => {
      if (erro) {
        console.error(erro);

        return res.status(500).json({
          erro: "Erro ao procurar e-mail.",
        });
      }

      if (!barbeiro) {
        return res.status(404).json({
          erro: "Nenhuma conta encontrada com esse e-mail.",
        });
      }

      const codigo = gerarCodigo();

      const codigoHash = hashCodigo(codigo);

      const expiraEm = Date.now() + 10 * 60 * 1000;

      db.run(
        `
            DELETE FROM recuperacao_senha
            WHERE barbeiro_id = ?
          `,
        [barbeiro.id],
        (erroDelete) => {
          if (erroDelete) {
            console.error("Erro ao remover códigos antigos:", erroDelete);
          }

          db.run(
            `
                INSERT INTO recuperacao_senha
                (
                  barbeiro_id,
                  codigo_hash,
                  expira_em,
                  usado
                )
                VALUES (?, ?, ?, 0)
              `,
            [barbeiro.id, codigoHash, expiraEm],
            async (erroInsert) => {
              if (erroInsert) {
                console.error(erroInsert);

                return res.status(500).json({
                  erro: "Erro ao gerar código.",
                });
              }

              try {
                await transporter.sendMail({
                  from: `"G Barber Club" <${process.env.EMAIL_USER}>`,

                  to: barbeiro.email,

                  subject: "Código para redefinir sua senha",

                  text: `
Olá, ${barbeiro.nome}!

Seu código de recuperação de senha é:

${codigo}

Este código é válido por 10 minutos.

Se você não solicitou a troca de senha, ignore este e-mail.

G Barber Club
                    `,

                  html: `
<div style="
  font-family: Arial, sans-serif;
  max-width: 500px;
  margin: auto;
  background: #111111;
  color: white;
  padding: 30px;
  border-radius: 15px;
">

  <h1 style="text-align:center;">
    G BARBER CLUB
  </h1>

  <p>
    Olá,
    <strong>${barbeiro.nome}</strong>!
  </p>

  <p>
    Você solicitou a redefinição
    da sua senha.
  </p>

  <p>
    Seu código de verificação é:
  </p>

  <div style="
    font-size: 32px;
    font-weight: bold;
    letter-spacing: 8px;
    text-align: center;
    padding: 20px;
    background: #222;
    border-radius: 10px;
    margin: 20px 0;
  ">
    ${codigo}
  </div>

  <p>
    Este código expira em
    <strong>10 minutos</strong>.
  </p>

  <p style="color:#aaa;">
    Caso você não tenha solicitado
    a troca da senha,
    ignore este e-mail.
  </p>

</div>
                    `,
                });

                console.log(
                  "Código de recuperação enviado para:",
                  barbeiro.email,
                );

                return res.json({
                  sucesso: true,
                  mensagem: "Código enviado para o seu e-mail!",
                });
              } catch (erroEmail) {
                console.error("Erro ao enviar e-mail:", erroEmail);

                return res.status(500).json({
                  erro: "Não foi possível enviar o e-mail.",
                });
              }
            },
          );
        },
      );
    },
  );
});

// ======================================================
// REDEFINIR SENHA
// ======================================================

app.post("/app/redefinir-senha", (req, res) => {
  const email = String(req.body.email || "")
    .trim()
    .toLowerCase();

  const codigo = String(req.body.codigo || "").trim();

  const novaSenha = String(req.body.novaSenha || "");

  const confirmarSenha = String(req.body.confirmarSenha || "");

  if (!email || !codigo || !novaSenha || !confirmarSenha) {
    return res.status(400).json({
      erro: "Preencha todos os campos.",
    });
  }

  if (codigo.length !== 6) {
    return res.status(400).json({
      erro: "Código inválido.",
    });
  }

  if (novaSenha.length < 4) {
    return res.status(400).json({
      erro: "A nova senha precisa ter pelo menos 4 caracteres.",
    });
  }

  if (novaSenha !== confirmarSenha) {
    return res.status(400).json({
      erro: "As senhas não coincidem.",
    });
  }

  db.get(
    `
        SELECT *
        FROM barbeiros
        WHERE LOWER(email) = LOWER(?)
      `,
    [email],
    (erro, barbeiro) => {
      if (erro) {
        return res.status(500).json({
          erro: "Erro no banco de dados.",
        });
      }

      if (!barbeiro) {
        return res.status(404).json({
          erro: "E-mail não encontrado.",
        });
      }

      db.get(
        `
            SELECT *
            FROM recuperacao_senha
            WHERE barbeiro_id = ?
              AND usado = 0
            ORDER BY id DESC
            LIMIT 1
          `,
        [barbeiro.id],
        (erroCodigo, recuperacao) => {
          if (erroCodigo) {
            return res.status(500).json({
              erro: "Erro ao verificar código.",
            });
          }

          if (!recuperacao) {
            return res.status(400).json({
              erro: "Solicite um novo código.",
            });
          }

          if (Date.now() > recuperacao.expira_em) {
            return res.status(400).json({
              erro: "O código expirou. Solicite outro.",
            });
          }

          const codigoInformadoHash = hashCodigo(codigo);

          if (codigoInformadoHash !== recuperacao.codigo_hash) {
            return res.status(400).json({
              erro: "Código incorreto.",
            });
          }

          const { salt, hash } = gerarSenhaSegura(novaSenha);

          db.run(
            `
                UPDATE barbeiros
                SET senha_hash = ?,
                    senha_salt = ?
                WHERE id = ?
              `,
            [hash, salt, barbeiro.id],
            (erroUpdate) => {
              if (erroUpdate) {
                return res.status(500).json({
                  erro: "Erro ao alterar a senha.",
                });
              }

              db.run(
                `
                    UPDATE recuperacao_senha
                    SET usado = 1
                    WHERE id = ?
                  `,
                [recuperacao.id],
              );

              res.json({
                sucesso: true,
                mensagem: "Senha alterada com sucesso!",
              });
            },
          );
        },
      );
    },
  );
});

// ======================================================
// HORÁRIOS LIVRES
// ======================================================

app.get("/horarios-livres/:data/:barbeiro", (req, res) => {
  const data = req.params.data;

  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  const dataObjeto = criarDataLocal(data);

  const diaSemana = dataObjeto.getDay();

  if (!barbeiroTrabalhaNoDia(barbeiro, diaSemana)) {
    return res.json([]);
  }

  db.all(
    `
        SELECT horario
        FROM agendamentos
        WHERE barbeiro = ?
          AND (
            (fixo = 0 AND dia = ?)
            OR
            (fixo = 1 AND dia_semana = ?)
          )
      `,
    [barbeiro, data, diaSemana],
    (erro, agendamentos) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      const ocupados = agendamentos.map((item) => item.horario);

      const livres = horariosBase.filter(
        (horario) => !ocupados.includes(horario),
      );

      res.json(livres);
    },
  );
});

// ======================================================
// AGENDAR NORMAL
// ======================================================

app.post("/agendar", (req, res) => {
  let { nome, numero, dia, horario, barbeiro, servico, valor } = req.body;

  barbeiro = normalizarBarbeiro(barbeiro);

  if (!nome || !dia || !horario || !barbeiro) {
    return res.status(400).json({
      erro: "Dados incompletos.",
    });
  }

  const data = criarDataLocal(dia);

  const diaSemana = data.getDay();

  if (!barbeiroTrabalhaNoDia(barbeiro, diaSemana)) {
    return res.status(400).json({
      erro: "Este barbeiro não atende neste dia.",
    });
  }

  db.get(
    `
      SELECT id
      FROM agendamentos
      WHERE barbeiro = ?
        AND horario = ?
        AND (
          (fixo = 0 AND dia = ?)
          OR
          (fixo = 1 AND dia_semana = ?)
        )
    `,
    [barbeiro, horario, dia, diaSemana],
    (erro, ocupado) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      if (ocupado) {
        return res.status(400).json({
          erro: "Horário já ocupado.",
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
            fixo,
            dia_semana
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, 'Confirmado', 0, ?)
        `,
        [
          nome,
          numero || "",
          dia,
          horario,
          barbeiro,
          servico || "",
          Number(valor) || 0,
          diaSemana,
        ],
        function (erroInsert) {
          if (erroInsert) {
            return res.status(500).json({
              erro: erroInsert.message,
            });
          }

          res.json({
            sucesso: true,
            id: this.lastID,
            mensagem: "Agendamento realizado com sucesso!",
          });
        },
      );
    },
  );
});

// ======================================================
// AGENDAR FIXO
// ======================================================

app.post("/agendar-fixo", (req, res) => {
  let { nome, numero, dia, horario, barbeiro, servico, valor, dia_semana } =
    req.body;

  barbeiro = normalizarBarbeiro(barbeiro);

  nome = String(nome || "").trim();

  horario = String(horario || "").trim();

  if (!nome || !horario || !barbeiro) {
    return res.status(400).json({
      erro: "Nome, horário e barbeiro são obrigatórios.",
    });
  }

  let diaSemana = dia_semana;

  if (diaSemana === undefined || diaSemana === null) {
    if (!dia) {
      return res.status(400).json({
        erro: "Informe o dia.",
      });
    }

    diaSemana = criarDataLocal(dia).getDay();
  }

  diaSemana = Number(diaSemana);

  if (!Number.isInteger(diaSemana) || diaSemana < 0 || diaSemana > 6) {
    return res.status(400).json({
      erro: "Dia da semana inválido.",
    });
  }

  if (!barbeiroTrabalhaNoDia(barbeiro, diaSemana)) {
    return res.status(400).json({
      erro: "Este barbeiro não atende neste dia.",
    });
  }

  if (!horariosBase.includes(horario)) {
    return res.status(400).json({
      erro: "Horário inválido.",
    });
  }

  db.get(
    `
        SELECT id
        FROM agendamentos
        WHERE barbeiro = ?
          AND horario = ?
          AND fixo = 1
          AND dia_semana = ?
      `,
    [barbeiro, horario, diaSemana],
    (erro, ocupado) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      if (ocupado) {
        return res.status(400).json({
          erro: "Já existe um horário fixo neste dia e horário.",
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
              fixo,
              dia_semana
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 'Confirmado', 1, ?)
          `,
        [
          nome,
          numero || "",
          dia || null,
          horario,
          barbeiro,
          servico || "",
          Number(valor) || 0,
          diaSemana,
        ],
        function (erroInsert) {
          if (erroInsert) {
            return res.status(500).json({
              erro: erroInsert.message,
            });
          }

          res.json({
            sucesso: true,
            id: this.lastID,
            mensagem: "Horário fixo cadastrado com sucesso!",
          });
        },
      );
    },
  );
});

// ======================================================
// TODOS OS AGENDAMENTOS DO BARBEIRO
// ======================================================

app.get("/agendamentos/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  db.all(
    `
        SELECT *
        FROM agendamentos
        WHERE barbeiro = ?
        ORDER BY dia, horario
      `,
    [barbeiro],
    (erro, registros) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      res.json(registros);
    },
  );
});

// ======================================================
// AGENDAMENTOS FIXOS
// ======================================================

app.get("/agendamentos-fixos/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  db.all(
    `
        SELECT *
        FROM agendamentos
        WHERE barbeiro = ?
          AND fixo = 1
        ORDER BY dia_semana, horario
      `,
    [barbeiro],
    (erro, registros) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      res.json(registros);
    },
  );
});

// ======================================================
// FINALIZAR
// ======================================================

app.put("/finalizar/:id", (req, res) => {
  db.run(
    `
        UPDATE agendamentos
        SET status = 'Finalizado'
        WHERE id = ?
      `,
    [req.params.id],
    function (erro) {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      res.json({
        sucesso: true,
        mensagem: "Agendamento finalizado!",
      });
    },
  );
});

// ======================================================
// CANCELAR AGENDAMENTO
// ======================================================

app.delete("/cancelar/:id", (req, res) => {
  db.run(
    `
        DELETE FROM agendamentos
        WHERE id = ?
      `,
    [req.params.id],
    function (erro) {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      res.json({
        sucesso: true,
        mensagem: "Agendamento cancelado!",
      });
    },
  );
});

// ======================================================
// AGENDAMENTOS DE HOJE
// ======================================================

app.get("/app/agendamentos-hoje/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  const hoje = dataHoje();

  const hojeObjeto = criarDataLocal(hoje);

  const diaSemana = hojeObjeto.getDay();

  if (!barbeiroTrabalhaNoDia(barbeiro, diaSemana)) {
    return res.json([]);
  }

  db.all(
    `
        SELECT *
        FROM agendamentos
        WHERE barbeiro = ?
          AND (
            (fixo = 0 AND dia = ?)
            OR
            (fixo = 1 AND dia_semana = ?)
          )
        ORDER BY horario
      `,
    [barbeiro, hoje, diaSemana],
    (erro, registros) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      const resultado = registros.map((item) => ({
        ...item,

        dia: Number(item.fixo) === 1 ? hoje : item.dia,
      }));

      res.json(resultado);
    },
  );
});

// ======================================================
// RESUMO FINANCEIRO DE HOJE
// ======================================================

app.get("/app/resumo-hoje/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  const hoje = dataHoje();

  const diaSemana = criarDataLocal(hoje).getDay();

  db.all(
    `
        SELECT *
        FROM agendamentos
        WHERE barbeiro = ?
          AND (
            (fixo = 0 AND dia = ?)
            OR
            (fixo = 1 AND dia_semana = ?)
          )
      `,
    [barbeiro, hoje, diaSemana],
    (erro, registros) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      const total = registros.length;

      const previsto = registros.reduce(
        (soma, item) => soma + Number(item.valor || 0),
        0,
      );

      const recebido = registros
        .filter((item) => item.status === "Finalizado")
        .reduce((soma, item) => soma + Number(item.valor || 0), 0);

      const pendente = previsto - recebido;

      res.json({
        total,
        previsto,
        recebido,
        pendente,
      });
    },
  );
});

// ======================================================
// AGENDAMENTOS DA SEMANA
// ======================================================

app.get("/app/agendamentos-semana/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  const hoje = new Date();

  hoje.setHours(12, 0, 0, 0);

  const diaAtual = hoje.getDay();

  const diferencaSegunda = diaAtual === 0 ? -6 : 1 - diaAtual;

  const segunda = new Date(hoje);

  segunda.setDate(hoje.getDate() + diferencaSegunda);

  const domingo = new Date(segunda);

  domingo.setDate(segunda.getDate() + 6);

  const inicioSemana = dataParaString(segunda);

  const fimSemana = dataParaString(domingo);

  db.all(
    `
        SELECT *
        FROM agendamentos
        WHERE barbeiro = ?
          AND (
            (
              fixo = 0
              AND dia BETWEEN ? AND ?
            )
            OR
            fixo = 1
          )
      `,
    [barbeiro, inicioSemana, fimSemana],
    (erro, registros) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      const resultado = [];

      for (const item of registros) {
        if (Number(item.fixo) === 0) {
          const dataItem = criarDataLocal(item.dia);

          if (barbeiroTrabalhaNoDia(barbeiro, dataItem.getDay())) {
            resultado.push(item);
          }

          continue;
        }

        const diaSemana = Number(item.dia_semana);

        for (let i = 0; i < 7; i++) {
          const dataSemana = new Date(segunda);

          dataSemana.setDate(segunda.getDate() + i);

          if (
            dataSemana.getDay() === diaSemana &&
            barbeiroTrabalhaNoDia(barbeiro, diaSemana)
          ) {
            resultado.push({
              ...item,

              dia: dataParaString(dataSemana),
            });
          }
        }
      }

      resultado.sort((a, b) => {
        const compararData = String(a.dia).localeCompare(String(b.dia));

        if (compararData !== 0) {
          return compararData;
        }

        return String(a.horario).localeCompare(String(b.horario));
      });

      res.json(resultado);
    },
  );
});

// ======================================================
// FIXOS DO APP
// ======================================================

app.get("/app/fixos/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  db.all(
    `
        SELECT *
        FROM agendamentos
        WHERE barbeiro = ?
          AND fixo = 1
        ORDER BY dia_semana, horario
      `,
    [barbeiro],
    (erro, registros) => {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      res.json(registros);
    },
  );
});

// ======================================================
// EXCLUIR HORÁRIO FIXO PELO APP
// ======================================================

app.delete("/app/fixos/:id", (req, res) => {
  const id = Number(req.params.id);

  if (!id) {
    return res.status(400).json({
      erro: "Horário fixo inválido.",
    });
  }

  db.get(
    `
        SELECT *
        FROM agendamentos
        WHERE id = ?
          AND fixo = 1
      `,
    [id],
    (erro, fixo) => {
      if (erro) {
        console.error(erro);

        return res.status(500).json({
          erro: "Erro ao procurar horário fixo.",
        });
      }

      if (!fixo) {
        return res.status(404).json({
          erro: "Horário fixo não encontrado.",
        });
      }

      db.run(
        `
            DELETE FROM agendamentos
            WHERE id = ?
              AND fixo = 1
          `,
        [id],
        function (erroDelete) {
          if (erroDelete) {
            console.error(erroDelete);

            return res.status(500).json({
              erro: "Erro ao excluir horário fixo.",
            });
          }

          res.json({
            sucesso: true,
            mensagem: "Horário fixo excluído com sucesso!",
          });
        },
      );
    },
  );
});

// ======================================================
// SERVIDOR
// ======================================================

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Servidor rodando em http://0.0.0.0:${PORT}`);
});
