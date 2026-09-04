require("dotenv").config();

const express = require("express");
const cors = require("cors");
const sqlite3 = require("sqlite3").verbose();
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const { initializeApp, cert } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

const app = express();
const PORT = 3000;

// ======================================================
// FIREBASE ADMIN - NOTIFICAÇÕES PUSH
// ======================================================

let firebasePushAtivo = false;

try {
  const serviceAccount = require("./firebase-service-account.json");

  initializeApp({
    credential: cert(serviceAccount),
  });

  firebasePushAtivo = true;
  console.log("Firebase Admin conectado!");
} catch (erro) {
  console.log("AVISO: Firebase Admin não foi iniciado:", erro.message);
}

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
// TABELA DE BLOQUEIOS
// ======================================================

db.run(`
  CREATE TABLE IF NOT EXISTS bloqueios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    barbeiro TEXT NOT NULL,
    dia TEXT NOT NULL,
    horario TEXT,
    dia_inteiro INTEGER DEFAULT 0,
    motivo TEXT DEFAULT ''
  )
`);

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
// TABELA DE DISPOSITIVOS PUSH
// ======================================================

db.run(`
  CREATE TABLE IF NOT EXISTS dispositivos_push (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    barbeiro TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL,
    atualizado_em INTEGER NOT NULL
  )
`);

// ======================================================
// TABELA DE CLIENTES
// ======================================================

db.serialize(() => {
  db.run(`
    CREATE TABLE IF NOT EXISTS clientes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nome TEXT NOT NULL,
      numero TEXT DEFAULT '',
      numero_busca TEXT DEFAULT '',
      barbeiro TEXT NOT NULL,
      criado_em INTEGER NOT NULL,
      atualizado_em INTEGER NOT NULL
    )
  `);

  db.run(`
    CREATE INDEX IF NOT EXISTS idx_clientes_barbeiro
    ON clientes(barbeiro)
  `);

  db.run(`
    CREATE INDEX IF NOT EXISTS idx_clientes_numero_busca
    ON clientes(barbeiro, numero_busca)
  `);
});

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

function normalizarNumero(numero) {
  return String(numero || "").replace(/\D/g, "");
}

function mesmoCliente(cliente, agendamento) {
  const numeroCliente = normalizarNumero(cliente.numero);
  const numeroAgendamento = normalizarNumero(agendamento.numero);

  if (numeroCliente && numeroAgendamento) {
    return numeroCliente === numeroAgendamento;
  }

  return (
    String(cliente.nome || "").trim().toLowerCase() ===
    String(agendamento.nome || "").trim().toLowerCase()
  );
}

function salvarClienteAutomaticamente({ nome, numero, barbeiro }) {
  return new Promise((resolve, reject) => {
    nome = String(nome || "").trim();
    numero = String(numero || "").trim();
    barbeiro = normalizarBarbeiro(barbeiro);

    const numeroBusca = normalizarNumero(numero);
    const agora = Date.now();

    if (!nome || !barbeiro) {
      resolve(null);
      return;
    }

    const sqlBusca = numeroBusca
      ? `
          SELECT *
          FROM clientes
          WHERE barbeiro = ?
            AND numero_busca = ?
          LIMIT 1
        `
      : `
          SELECT *
          FROM clientes
          WHERE barbeiro = ?
            AND numero_busca = ''
            AND LOWER(nome) = LOWER(?)
          LIMIT 1
        `;

    const parametrosBusca = numeroBusca
      ? [barbeiro, numeroBusca]
      : [barbeiro, nome];

    db.get(sqlBusca, parametrosBusca, (erroBusca, cliente) => {
      if (erroBusca) {
        reject(erroBusca);
        return;
      }

      if (cliente) {
        db.run(
          `
            UPDATE clientes
            SET nome = ?,
                numero = ?,
                numero_busca = ?,
                atualizado_em = ?
            WHERE id = ?
          `,
          [nome, numero, numeroBusca, agora, cliente.id],
          (erroUpdate) => {
            if (erroUpdate) {
              reject(erroUpdate);
              return;
            }

            resolve(cliente.id);
          },
        );

        return;
      }

      db.run(
        `
          INSERT INTO clientes
          (nome, numero, numero_busca, barbeiro, criado_em, atualizado_em)
          VALUES (?, ?, ?, ?, ?, ?)
        `,
        [nome, numero, numeroBusca, barbeiro, agora, agora],
        function (erroInsert) {
          if (erroInsert) {
            reject(erroInsert);
            return;
          }

          resolve(this.lastID);
        },
      );
    });
  });
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
// ENVIAR NOTIFICAÇÃO DE NOVO AGENDAMENTO
// ======================================================

async function enviarNotificacaoNovoAgendamento({
  id,
  barbeiro,
  nome,
  dia,
  horario,
  servico,
}) {
  if (!firebasePushAtivo) {
    return;
  }

  const tokens = await new Promise((resolve, reject) => {
    db.all(
      `
        SELECT token
        FROM dispositivos_push
        WHERE barbeiro = ?
      `,
      [normalizarBarbeiro(barbeiro)],
      (erro, registros) => {
        if (erro) {
          reject(erro);
          return;
        }

        resolve(
          registros
            .map((item) => String(item.token || "").trim())
            .filter((item) => item),
        );
      },
    );
  });

  if (tokens.length === 0) {
    console.log(`Nenhum dispositivo push cadastrado para ${barbeiro}.`);
    return;
  }

  const mensagem = {
    tokens,
    notification: {
      title: "Novo agendamento",
      body: `${nome} - ${horario}${servico ? ` - ${servico}` : ""}`,
    },
    data: {
      tipo: "novo_agendamento",
      agendamentoId: String(id),
      barbeiro: String(barbeiro),
      dia: String(dia || ""),
      horario: String(horario || ""),
    },
    android: {
      priority: "high",
      notification: {
        sound: "default",
      },
    },
  };

  const resposta = await getMessaging().sendEachForMulticast(mensagem);

  console.log(
    `Push enviado para ${barbeiro}: ${resposta.successCount} sucesso(s), ${resposta.failureCount} falha(s).`,
  );

  const tokensInvalidos = [];

  resposta.responses.forEach((resultado, indice) => {
    if (resultado.success) {
      return;
    }

    const codigo = resultado.error?.code || "";

    if (
      codigo === "messaging/registration-token-not-registered" ||
      codigo === "messaging/invalid-registration-token"
    ) {
      tokensInvalidos.push(tokens[indice]);
    }
  });

  for (const token of tokensInvalidos) {
    db.run(
      `
        DELETE FROM dispositivos_push
        WHERE token = ?
      `,
      [token],
    );
  }
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
// REGISTRAR TOKEN DE NOTIFICAÇÃO DO BARBEIRO
// ======================================================

app.post("/app/push-token", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.body.barbeiro);
  const token = String(req.body.token || "").trim();

  if (!barbeiro || !token) {
    return res.status(400).json({
      erro: "Barbeiro e token são obrigatórios.",
    });
  }

  db.run(
    `
      INSERT INTO dispositivos_push
      (
        barbeiro,
        token,
        atualizado_em
      )
      VALUES (?, ?, ?)
      ON CONFLICT(token)
      DO UPDATE SET
        barbeiro = excluded.barbeiro,
        atualizado_em = excluded.atualizado_em
    `,
    [barbeiro, token, Date.now()],
    function (erro) {
      if (erro) {
        console.error("Erro ao salvar token push:", erro);

        return res.status(500).json({
          erro: "Não foi possível registrar o dispositivo.",
        });
      }

      res.json({
        sucesso: true,
        mensagem: "Dispositivo registrado para notificações.",
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
    Olá, <strong>${barbeiro.nome}</strong>!
  </p>

  <p>
    Você solicitou a redefinição da sua senha.
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
    Este código expira em <strong>10 minutos</strong>.
  </p>

  <p style="color:#aaa;">
    Caso você não tenha solicitado a troca da senha,
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
  const data = String(req.params.data || "").trim();
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  if (!data || !barbeiro) {
    return res.status(400).json({
      erro: "Data e barbeiro são obrigatórios.",
    });
  }

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
        AND status != 'Cancelado'
        AND (
          (fixo = 0 AND dia = ?)
          OR
          (fixo = 1 AND dia_semana = ?)
        )
    `,
    [barbeiro, data, diaSemana],
    (erroAgendamentos, agendamentos) => {
      if (erroAgendamentos) {
        console.error(erroAgendamentos);

        return res.status(500).json({
          erro: "Erro ao consultar horários.",
        });
      }

      db.all(
        `
          SELECT *
          FROM bloqueios
          WHERE barbeiro = ?
            AND dia = ?
        `,
        [barbeiro, data],
        (erroBloqueios, bloqueios) => {
          if (erroBloqueios) {
            console.error(erroBloqueios);

            return res.status(500).json({
              erro: "Erro ao consultar bloqueios.",
            });
          }

          const diaInteiroBloqueado = bloqueios.some(
            (item) => Number(item.dia_inteiro) === 1,
          );

          if (diaInteiroBloqueado) {
            return res.json([]);
          }

          const ocupados = agendamentos.map((item) => item.horario);

          const horariosBloqueados = bloqueios
            .filter((item) => Number(item.dia_inteiro) === 0)
            .map((item) => item.horario);

          const horariosLivres = horariosBase.filter(
            (horario) =>
              !ocupados.includes(horario) &&
              !horariosBloqueados.includes(horario),
          );

          res.json(horariosLivres);
        },
      );
    },
  );
});

// ======================================================
// CRIAR AGENDAMENTO NORMAL
// ======================================================

app.post("/agendar", (req, res) => {
  let { nome, numero, dia, horario, barbeiro, servico, valor } = req.body;

  nome = String(nome || "").trim();
  numero = String(numero || "").trim();
  dia = String(dia || "").trim();
  horario = String(horario || "").trim();
  barbeiro = normalizarBarbeiro(barbeiro);
  servico = String(servico || "").trim();
  valor = Number(valor) || 0;

  if (!nome || !dia || !horario || !barbeiro) {
    return res.status(400).json({
      erro: "Preencha os dados obrigatórios.",
    });
  }

  if (!horariosBase.includes(horario)) {
    return res.status(400).json({
      erro: "Horário inválido.",
    });
  }

  const dataObjeto = criarDataLocal(dia);
  const diaSemana = dataObjeto.getDay();

  if (!barbeiroTrabalhaNoDia(barbeiro, diaSemana)) {
    return res.status(400).json({
      erro: "Esse barbeiro não trabalha neste dia.",
    });
  }

  db.get(
    `
      SELECT *
      FROM bloqueios
      WHERE barbeiro = ?
        AND dia = ?
        AND (
          dia_inteiro = 1
          OR horario = ?
        )
      LIMIT 1
    `,
    [barbeiro, dia, horario],
    (erroBloqueio, bloqueio) => {
      if (erroBloqueio) {
        console.error(erroBloqueio);

        return res.status(500).json({
          erro: "Erro ao verificar bloqueio.",
        });
      }

      if (bloqueio) {
        return res.status(400).json({
          erro: "Esse horário está bloqueado pelo barbeiro.",
        });
      }

      db.get(
        `
          SELECT *
          FROM agendamentos
          WHERE barbeiro = ?
            AND horario = ?
            AND status != 'Cancelado'
            AND (
              (fixo = 0 AND dia = ?)
              OR
              (fixo = 1 AND dia_semana = ?)
            )
          LIMIT 1
        `,
        [barbeiro, horario, dia, diaSemana],
        (erroVerificacao, ocupado) => {
          if (erroVerificacao) {
            console.error(erroVerificacao);

            return res.status(500).json({
              erro: "Erro ao verificar horário.",
            });
          }

          if (ocupado) {
            return res.status(400).json({
              erro: "Esse horário já está ocupado.",
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
            [nome, numero, dia, horario, barbeiro, servico, valor, diaSemana],
            function (erroInsert) {
              if (erroInsert) {
                console.error(erroInsert);

                return res.status(500).json({
                  erro: "Erro ao criar agendamento.",
                });
              }

              const agendamentoId = this.lastID;

              res.json({
                sucesso: true,
                id: agendamentoId,
                mensagem: "Agendamento realizado com sucesso!",
              });

              salvarClienteAutomaticamente({
                nome,
                numero,
                barbeiro,
              }).catch((erroCliente) => {
                console.error("Erro ao salvar cliente automaticamente:", erroCliente);
              });

              enviarNotificacaoNovoAgendamento({
                id: agendamentoId,
                barbeiro,
                nome,
                dia,
                horario,
                servico,
              }).catch((erroPush) => {
                console.error("Erro ao enviar notificação push:", erroPush);
              });
            },
          );
        },
      );
    },
  );
});

// ======================================================
// CRIAR AGENDAMENTO FIXO
// ======================================================

app.post("/agendar-fixo", (req, res) => {
  let { nome, numero, dia_semana, horario, barbeiro, servico, valor } =
    req.body;

  nome = String(nome || "").trim();
  numero = String(numero || "").trim();
  barbeiro = normalizarBarbeiro(barbeiro);
  horario = String(horario || "").trim();
  servico = String(servico || "").trim();

  dia_semana = Number(dia_semana);
  valor = Number(valor) || 0;

  if (!nome || !barbeiro || !horario || !Number.isInteger(dia_semana)) {
    return res.status(400).json({
      erro: "Preencha todos os campos obrigatórios.",
    });
  }

  if (dia_semana < 0 || dia_semana > 6) {
    return res.status(400).json({
      erro: "Dia da semana inválido.",
    });
  }

  if (!horariosBase.includes(horario)) {
    return res.status(400).json({
      erro: "Horário inválido.",
    });
  }

  if (!barbeiroTrabalhaNoDia(barbeiro, dia_semana)) {
    return res.status(400).json({
      erro: "Esse barbeiro não trabalha neste dia.",
    });
  }

  db.get(
    `
      SELECT *
      FROM agendamentos
      WHERE barbeiro = ?
        AND fixo = 1
        AND status != 'Cancelado'
        AND dia_semana = ?
        AND horario = ?
      LIMIT 1
    `,
    [barbeiro, dia_semana, horario],
    (erro, ocupado) => {
      if (erro) {
        console.error(erro);

        return res.status(500).json({
          erro: "Erro ao verificar horário fixo.",
        });
      }

      if (ocupado) {
        return res.status(400).json({
          erro: "Já existe um cliente fixo nesse horário.",
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
          VALUES (?, ?, NULL, ?, ?, ?, ?, 'Confirmado', 1, ?)
        `,
        [nome, numero, horario, barbeiro, servico, valor, dia_semana],
        function (erroInsert) {
          if (erroInsert) {
            console.error(erroInsert);

            return res.status(500).json({
              erro: "Erro ao cadastrar horário fixo.",
            });
          }

          const agendamentoId = this.lastID;

          res.json({
            sucesso: true,
            id: agendamentoId,
            mensagem: "Horário fixo cadastrado com sucesso!",
          });

          salvarClienteAutomaticamente({
            nome,
            numero,
            barbeiro,
          }).catch((erroCliente) => {
            console.error("Erro ao salvar cliente automaticamente:", erroCliente);
          });
        },
      );
    },
  );
});

// ======================================================
// CRIAR BLOQUEIO
// ======================================================

app.post("/app/bloqueios", (req, res) => {
  let { barbeiro, dia, horario, horarios, dia_inteiro, motivo } = req.body;

  barbeiro = normalizarBarbeiro(barbeiro);
  dia = String(dia || "").trim();
  horario = String(horario || "").trim();
  motivo = String(motivo || "").trim();

  const bloquearDiaInteiro = dia_inteiro === true || Number(dia_inteiro) === 1;

  if (!barbeiro || !dia) {
    return res.status(400).json({
      erro: "Barbeiro e data são obrigatórios.",
    });
  }

  const dataObjeto = criarDataLocal(dia);

  if (Number.isNaN(dataObjeto.getTime())) {
    return res.status(400).json({
      erro: "Data inválida.",
    });
  }

  const diaSemana = dataObjeto.getDay();

  if (!barbeiroTrabalhaNoDia(barbeiro, diaSemana)) {
    return res.status(400).json({
      erro: "Esse barbeiro não trabalha neste dia.",
    });
  }

  // ====================================================
  // BLOQUEAR DIA INTEIRO
  // ====================================================

  if (bloquearDiaInteiro) {
    db.get(
      `
        SELECT COUNT(*) AS total
        FROM agendamentos
        WHERE barbeiro = ?
          AND status != 'Cancelado'
          AND (
            (fixo = 0 AND dia = ?)
            OR
            (fixo = 1 AND dia_semana = ?)
          )
      `,
      [barbeiro, dia, diaSemana],
      (erroAgendamento, resultado) => {
        if (erroAgendamento) {
          return res.status(500).json({
            erro: "Erro ao verificar agendamentos.",
          });
        }

        if (Number(resultado.total) > 0) {
          return res.status(400).json({
            erro: "Existem clientes agendados neste dia. Cancele ou remarque os agendamentos antes de bloquear o dia inteiro.",
          });
        }

        db.run(
          `
            DELETE FROM bloqueios
            WHERE barbeiro = ?
              AND dia = ?
          `,
          [barbeiro, dia],
          (erroDelete) => {
            if (erroDelete) {
              return res.status(500).json({
                erro: "Erro ao preparar bloqueio.",
              });
            }

            db.run(
              `
                INSERT INTO bloqueios
                (
                  barbeiro,
                  dia,
                  horario,
                  dia_inteiro,
                  motivo
                )
                VALUES (?, ?, NULL, 1, ?)
              `,
              [barbeiro, dia, motivo],
              function (erroInsert) {
                if (erroInsert) {
                  return res.status(500).json({
                    erro: "Erro ao bloquear o dia.",
                  });
                }

                res.json({
                  sucesso: true,
                  id: this.lastID,
                  mensagem: "Dia inteiro bloqueado com sucesso!",
                });
              },
            );
          },
        );
      },
    );

    return;
  }

  // ====================================================
  // BLOQUEAR UM OU VÁRIOS HORÁRIOS
  // ====================================================

  let listaHorarios = [];

  if (Array.isArray(horarios)) {
    listaHorarios = horarios
      .map((item) => String(item || "").trim())
      .filter((item) => item);
  }

  if (horario) {
    listaHorarios.push(horario);
  }

  listaHorarios = [...new Set(listaHorarios)];

  if (listaHorarios.length === 0) {
    return res.status(400).json({
      erro: "Selecione pelo menos um horário.",
    });
  }

  const horarioInvalido = listaHorarios.find(
    (item) => !horariosBase.includes(item),
  );

  if (horarioInvalido) {
    return res.status(400).json({
      erro: `Horário inválido: ${horarioInvalido}`,
    });
  }

  const placeholders = listaHorarios.map(() => "?").join(",");

  db.all(
    `
      SELECT horario
      FROM agendamentos
      WHERE barbeiro = ?
        AND status != 'Cancelado'
        AND horario IN (${placeholders})
        AND (
          (fixo = 0 AND dia = ?)
          OR
          (fixo = 1 AND dia_semana = ?)
        )
    `,
    [barbeiro, ...listaHorarios, dia, diaSemana],
    (erroAgendamentos, ocupados) => {
      if (erroAgendamentos) {
        console.error(erroAgendamentos);

        return res.status(500).json({
          erro: "Erro ao verificar agendamentos.",
        });
      }

      if (ocupados.length > 0) {
        const listaOcupados = ocupados.map((item) => item.horario).join(", ");

        return res.status(400).json({
          erro: `Não é possível bloquear. Existem clientes nos horários: ${listaOcupados}.`,
        });
      }

      db.get(
        `
          SELECT *
          FROM bloqueios
          WHERE barbeiro = ?
            AND dia = ?
            AND dia_inteiro = 1
          LIMIT 1
        `,
        [barbeiro, dia],
        (erroDia, bloqueioDia) => {
          if (erroDia) {
            return res.status(500).json({
              erro: "Erro ao verificar bloqueios.",
            });
          }

          if (bloqueioDia) {
            return res.status(400).json({
              erro: "Este dia já está completamente bloqueado.",
            });
          }

          let inseridos = 0;
          let processados = 0;
          let houveErro = false;

          listaHorarios.forEach((horarioItem) => {
            db.get(
              `
                SELECT *
                FROM bloqueios
                WHERE barbeiro = ?
                  AND dia = ?
                  AND horario = ?
                  AND dia_inteiro = 0
                LIMIT 1
              `,
              [barbeiro, dia, horarioItem],
              (erroExistente, existente) => {
                if (houveErro) {
                  return;
                }

                if (erroExistente) {
                  houveErro = true;

                  return res.status(500).json({
                    erro: "Erro ao verificar bloqueio.",
                  });
                }

                if (existente) {
                  processados++;
                  finalizarBloqueios();
                  return;
                }

                db.run(
                  `
                    INSERT INTO bloqueios
                    (
                      barbeiro,
                      dia,
                      horario,
                      dia_inteiro,
                      motivo
                    )
                    VALUES (?, ?, ?, 0, ?)
                  `,
                  [barbeiro, dia, horarioItem, motivo],
                  (erroInsert) => {
                    if (houveErro) {
                      return;
                    }

                    if (erroInsert) {
                      houveErro = true;

                      return res.status(500).json({
                        erro: "Erro ao criar bloqueio.",
                      });
                    }

                    inseridos++;
                    processados++;

                    finalizarBloqueios();
                  },
                );
              },
            );
          });

          function finalizarBloqueios() {
            if (processados === listaHorarios.length && !houveErro) {
              res.json({
                sucesso: true,
                quantidade: inseridos,
                mensagem:
                  inseridos === 1
                    ? "Horário bloqueado com sucesso!"
                    : `${inseridos} horários bloqueados com sucesso!`,
              });
            }
          }
        },
      );
    },
  );
});
// ======================================================
// LISTAR BLOQUEIOS DO BARBEIRO
// ======================================================

app.get("/app/bloqueios/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  db.all(
    `
      SELECT *
      FROM bloqueios
      WHERE barbeiro = ?
      ORDER BY dia, dia_inteiro DESC, horario
    `,
    [barbeiro],
    (erro, registros) => {
      if (erro) {
        console.error(erro);

        return res.status(500).json({
          erro: "Erro ao carregar bloqueios.",
        });
      }

      res.json(registros);
    },
  );
});

// ======================================================
// EXCLUIR BLOQUEIO
// ======================================================

app.delete("/app/bloqueios/:id", (req, res) => {
  const id = Number(req.params.id);

  if (!id) {
    return res.status(400).json({
      erro: "Bloqueio inválido.",
    });
  }

  db.run(
    `
      DELETE FROM bloqueios
      WHERE id = ?
    `,
    [id],
    function (erro) {
      if (erro) {
        console.error(erro);

        return res.status(500).json({
          erro: "Erro ao excluir bloqueio.",
        });
      }

      if (this.changes === 0) {
        return res.status(404).json({
          erro: "Bloqueio não encontrado.",
        });
      }

      res.json({
        sucesso: true,
        mensagem: "Horário desbloqueado com sucesso!",
      });
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
        AND status != 'Cancelado'
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
// EDITAR / REMARCAR AGENDAMENTO
// ======================================================

app.put("/app/agendamentos/:id", (req, res) => {
  const id = Number(req.params.id);

  let { dia, horario, servico, valor } = req.body;

  dia = String(dia || "").trim();
  horario = String(horario || "").trim();
  servico = String(servico || "").trim();

  if (!id) {
    return res.status(400).json({
      erro: "Agendamento inválido.",
    });
  }

  if (!dia || !horario || !servico) {
    return res.status(400).json({
      erro: "Preencha data, horário e serviço.",
    });
  }

  if (!horariosBase.includes(horario)) {
    return res.status(400).json({
      erro: "Horário inválido.",
    });
  }

  // O preço é definido pelo servidor.
  // Assim ninguém consegue mandar um valor diferente pelo app.
  if (servico === "Corte") {
    valor = 30;
  } else if (servico === "Corte + Barba") {
    valor = 50;
  } else {
    return res.status(400).json({
      erro: "Serviço inválido.",
    });
  }

  const dataObjeto = criarDataLocal(dia);

  if (Number.isNaN(dataObjeto.getTime())) {
    return res.status(400).json({
      erro: "Data inválida.",
    });
  }

  const diaSemana = dataObjeto.getDay();

  // Primeiro encontra o agendamento que será editado.
  db.get(
    `
      SELECT *
      FROM agendamentos
      WHERE id = ?
        AND fixo = 0
        AND status = 'Confirmado'
    `,
    [id],
    (erroAgendamento, agendamento) => {
      if (erroAgendamento) {
        console.error(erroAgendamento);

        return res.status(500).json({
          erro: "Erro ao procurar agendamento.",
        });
      }

      if (!agendamento) {
        return res.status(404).json({
          erro: "Agendamento não encontrado ou não pode mais ser editado.",
        });
      }

      const barbeiro = normalizarBarbeiro(agendamento.barbeiro);

      // Verifica se o barbeiro trabalha na nova data.
      if (!barbeiroTrabalhaNoDia(barbeiro, diaSemana)) {
        return res.status(400).json({
          erro: "O barbeiro não trabalha nesta data.",
        });
      }

      // Verifica bloqueios.
      db.get(
        `
          SELECT *
          FROM bloqueios
          WHERE barbeiro = ?
            AND dia = ?
            AND (
              dia_inteiro = 1
              OR horario = ?
            )
          LIMIT 1
        `,
        [barbeiro, dia, horario],
        (erroBloqueio, bloqueio) => {
          if (erroBloqueio) {
            console.error(erroBloqueio);

            return res.status(500).json({
              erro: "Erro ao verificar bloqueios.",
            });
          }

          if (bloqueio) {
            return res.status(400).json({
              erro: "Esse horário está bloqueado na agenda.",
            });
          }

          // Verifica outro cliente normal ou horário fixo.
          // O id atual é ignorado para que seja possível
          // manter o mesmo horário ao alterar só o serviço.
          db.get(
            `
              SELECT *
              FROM agendamentos
              WHERE barbeiro = ?
                AND horario = ?
                AND status != 'Cancelado'
                AND id != ?
                AND (
                  (fixo = 0 AND dia = ?)
                  OR
                  (fixo = 1 AND dia_semana = ?)
                )
              LIMIT 1
            `,
            [barbeiro, horario, id, dia, diaSemana],
            (erroConflito, conflito) => {
              if (erroConflito) {
                console.error(erroConflito);

                return res.status(500).json({
                  erro: "Erro ao verificar disponibilidade.",
                });
              }

              if (conflito) {
                return res.status(400).json({
                  erro: "Esse horário já está ocupado.",
                });
              }

              // Tudo certo: atualiza o agendamento.
              db.run(
                `
                  UPDATE agendamentos
                  SET dia = ?,
                      horario = ?,
                      servico = ?,
                      valor = ?,
                      dia_semana = ?
                  WHERE id = ?
                    AND fixo = 0
                    AND status = 'Confirmado'
                `,
                [dia, horario, servico, valor, diaSemana, id],
                function (erroUpdate) {
                  if (erroUpdate) {
                    console.error(erroUpdate);

                    return res.status(500).json({
                      erro: "Erro ao atualizar agendamento.",
                    });
                  }

                  if (this.changes === 0) {
                    return res.status(404).json({
                      erro: "Agendamento não encontrado.",
                    });
                  }

                  res.json({
                    sucesso: true,
                    mensagem: "Agendamento atualizado com sucesso!",
                    agendamento: {
                      id,
                      nome: agendamento.nome,
                      numero: agendamento.numero,
                      barbeiro,
                      dia,
                      horario,
                      servico,
                      valor,
                      status: "Confirmado",
                    },
                  });
                },
              );
            },
          );
        },
      );
    },
  );
});

// ======================================================
// FINALIZAR
// ======================================================

app.put("/finalizar/:id", (req, res) => {
  const id = Number(req.params.id);

  if (!id) {
    return res.status(400).json({
      erro: "Agendamento inválido.",
    });
  }

  db.run(
    `
      UPDATE agendamentos
      SET status = 'Finalizado'
      WHERE id = ?
        AND fixo = 0
    `,
    [id],
    function (erro) {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      if (this.changes === 0) {
        return res.status(404).json({
          erro: "Agendamento não encontrado.",
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
  const id = Number(req.params.id);

  if (!id) {
    return res.status(400).json({
      erro: "Agendamento inválido.",
    });
  }

  db.run(
    `
      UPDATE agendamentos
      SET status = 'Cancelado'
      WHERE id = ?
        AND fixo = 0
    `,
    [id],
    function (erro) {
      if (erro) {
        return res.status(500).json({
          erro: erro.message,
        });
      }

      if (this.changes === 0) {
        return res.status(404).json({
          erro: "Agendamento não encontrado.",
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
// HISTÓRICO
// ======================================================

app.get("/app/historico/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);

  db.all(
    `
      SELECT *
      FROM agendamentos
      WHERE barbeiro = ?
        AND fixo = 0
        AND status IN ('Finalizado', 'Cancelado')
      ORDER BY dia DESC, horario DESC
    `,
    [barbeiro],
    (erro, registros) => {
      if (erro) {
        console.error(erro);

        return res.status(500).json({
          erro: "Erro ao carregar histórico.",
        });
      }

      res.json(registros);
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
        AND status != 'Cancelado'
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
        AND status != 'Cancelado'
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
        AND status != 'Cancelado'
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
        AND status != 'Cancelado'
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
// CLIENTES - LISTAR
// ======================================================

app.get("/app/clientes/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);
  const busca = String(req.query.busca || "").trim().toLowerCase();

  db.all(
    `
      SELECT *
      FROM clientes
      WHERE barbeiro = ?
      ORDER BY nome COLLATE NOCASE
    `,
    [barbeiro],
    (erroClientes, clientes) => {
      if (erroClientes) {
        console.error(erroClientes);
        return res.status(500).json({ erro: "Erro ao carregar clientes." });
      }

      db.all(
        `
          SELECT *
          FROM agendamentos
          WHERE barbeiro = ?
            AND fixo = 0
        `,
        [barbeiro],
        (erroAgendamentos, agendamentos) => {
          if (erroAgendamentos) {
            console.error(erroAgendamentos);
            return res.status(500).json({
              erro: "Erro ao calcular dados dos clientes.",
            });
          }

          let resultado = clientes.map((cliente) => {
            const historico = agendamentos.filter((item) =>
              mesmoCliente(cliente, item),
            );

            const finalizados = historico.filter(
              (item) => item.status === "Finalizado",
            );

            const totalGasto = finalizados.reduce(
              (soma, item) => soma + Number(item.valor || 0),
              0,
            );

            const datasFinalizadas = finalizados
              .map((item) => String(item.dia || ""))
              .filter(Boolean)
              .sort();

            const ultimoAtendimento =
              datasFinalizadas.length > 0
                ? datasFinalizadas[datasFinalizadas.length - 1]
                : null;

            return {
              ...cliente,
              total_atendimentos: finalizados.length,
              total_gasto: totalGasto,
              ultimo_atendimento: ultimoAtendimento,
            };
          });

          if (busca) {
            resultado = resultado.filter((cliente) => {
              const nome = String(cliente.nome || "").toLowerCase();
              const numero = String(cliente.numero || "").toLowerCase();

              return nome.includes(busca) || numero.includes(busca);
            });
          }

          res.json(resultado);
        },
      );
    },
  );
});

// ======================================================
// CLIENTES - CADASTRAR MANUALMENTE
// ======================================================

app.post("/app/clientes", async (req, res) => {
  try {
    let { nome, numero, barbeiro } = req.body;

    nome = String(nome || "").trim();
    numero = String(numero || "").trim();
    barbeiro = normalizarBarbeiro(barbeiro);

    if (!nome || !barbeiro) {
      return res.status(400).json({
        erro: "Nome e barbeiro são obrigatórios.",
      });
    }

    const id = await salvarClienteAutomaticamente({
      nome,
      numero,
      barbeiro,
    });

    db.get(
      `SELECT * FROM clientes WHERE id = ?`,
      [id],
      (erro, cliente) => {
        if (erro) {
          console.error(erro);
          return res.status(500).json({ erro: "Erro ao carregar cliente." });
        }

        res.json({
          sucesso: true,
          mensagem: "Cliente salvo com sucesso!",
          cliente,
        });
      },
    );
  } catch (erro) {
    console.error(erro);
    res.status(500).json({ erro: "Erro ao cadastrar cliente." });
  }
});

// ======================================================
// CLIENTES - EDITAR
// ======================================================

app.put("/app/clientes/:id", (req, res) => {
  const id = Number(req.params.id);
  let { nome, numero } = req.body;

  nome = String(nome || "").trim();
  numero = String(numero || "").trim();

  if (!id || !nome) {
    return res.status(400).json({
      erro: "Cliente ou nome inválido.",
    });
  }

  const numeroBusca = normalizarNumero(numero);

  db.run(
    `
      UPDATE clientes
      SET nome = ?,
          numero = ?,
          numero_busca = ?,
          atualizado_em = ?
      WHERE id = ?
    `,
    [nome, numero, numeroBusca, Date.now(), id],
    function (erro) {
      if (erro) {
        console.error(erro);
        return res.status(500).json({ erro: "Erro ao atualizar cliente." });
      }

      if (this.changes === 0) {
        return res.status(404).json({ erro: "Cliente não encontrado." });
      }

      res.json({
        sucesso: true,
        mensagem: "Cliente atualizado com sucesso!",
      });
    },
  );
});

// ======================================================
// CLIENTES - HISTÓRICO
// ======================================================

app.get("/app/clientes/:id/historico", (req, res) => {
  const id = Number(req.params.id);

  if (!id) {
    return res.status(400).json({ erro: "Cliente inválido." });
  }

  db.get(`SELECT * FROM clientes WHERE id = ?`, [id], (erroCliente, cliente) => {
    if (erroCliente) {
      console.error(erroCliente);
      return res.status(500).json({ erro: "Erro ao carregar cliente." });
    }

    if (!cliente) {
      return res.status(404).json({ erro: "Cliente não encontrado." });
    }

    db.all(
      `
        SELECT *
        FROM agendamentos
        WHERE barbeiro = ?
          AND fixo = 0
        ORDER BY dia DESC, horario DESC
      `,
      [cliente.barbeiro],
      (erroAgendamentos, agendamentos) => {
        if (erroAgendamentos) {
          console.error(erroAgendamentos);
          return res.status(500).json({ erro: "Erro ao carregar histórico." });
        }

        const historico = agendamentos.filter((item) =>
          mesmoCliente(cliente, item),
        );

        const finalizados = historico.filter(
          (item) => item.status === "Finalizado",
        );

        const totalGasto = finalizados.reduce(
          (soma, item) => soma + Number(item.valor || 0),
          0,
        );

        res.json({
          cliente,
          total_atendimentos: finalizados.length,
          total_gasto: totalGasto,
          historico,
        });
      },
    );
  });
});

// ======================================================
// CLIENTES - EXCLUIR CADASTRO
// ======================================================

app.delete("/app/clientes/:id", (req, res) => {
  const id = Number(req.params.id);

  if (!id) {
    return res.status(400).json({ erro: "Cliente inválido." });
  }

  db.run(`DELETE FROM clientes WHERE id = ?`, [id], function (erro) {
    if (erro) {
      console.error(erro);
      return res.status(500).json({ erro: "Erro ao excluir cliente." });
    }

    if (this.changes === 0) {
      return res.status(404).json({ erro: "Cliente não encontrado." });
    }

    res.json({
      sucesso: true,
      mensagem: "Cliente excluído do cadastro.",
    });
  });
});

// ======================================================
// RELATÓRIOS
// ======================================================

app.get("/app/relatorios/:barbeiro", (req, res) => {
  const barbeiro = normalizarBarbeiro(req.params.barbeiro);
  const mesInformado = String(req.query.mes || "").trim();
  const hoje = dataHoje();
  const agora = criarDataLocal(hoje);
  const inicioSemanaObj = new Date(agora);
  const diaSemana = inicioSemanaObj.getDay();
  const deslocamento = diaSemana === 0 ? -6 : 1 - diaSemana;
  inicioSemanaObj.setDate(inicioSemanaObj.getDate() + deslocamento);
  const fimSemanaObj = new Date(inicioSemanaObj);
  fimSemanaObj.setDate(fimSemanaObj.getDate() + 6);
  const inicioSemana = dataParaString(inicioSemanaObj);
  const fimSemana = dataParaString(fimSemanaObj);
  const mesAtual = hoje.substring(0, 7);
  const mes = /^\d{4}-\d{2}$/.test(mesInformado) ? mesInformado : mesAtual;
  const inicioMes = `${mes}-01`;
  const [anoMes, numeroMes] = mes.split("-").map(Number);
  const ultimoDia = new Date(anoMes, numeroMes, 0).getDate();
  const fimMes = `${mes}-${String(ultimoDia).padStart(2, "0")}`;

  if (!barbeiro) {
    return res.status(400).json({ erro: "Barbeiro é obrigatório." });
  }

  db.all(
    `SELECT nome, dia, servico, valor, status
     FROM agendamentos
     WHERE barbeiro = ? AND fixo = 0 AND dia IS NOT NULL`,
    [barbeiro],
    (erro, registros) => {
      if (erro) {
        console.error("Erro ao gerar relatório:", erro);
        return res.status(500).json({ erro: "Erro ao gerar relatório." });
      }

      const finalizados = registros.filter((a) => a.status === "Finalizado");
      const canceladosMes = registros.filter(
        (a) => a.status === "Cancelado" && a.dia >= inicioMes && a.dia <= fimMes,
      );
      const finalizadosMes = finalizados.filter(
        (a) => a.dia >= inicioMes && a.dia <= fimMes,
      );
      const soma = (lista) =>
        lista.reduce((total, a) => total + Number(a.valor || 0), 0);

      const faturamentoHoje = soma(finalizados.filter((a) => a.dia === hoje));
      const faturamentoSemana = soma(
        finalizados.filter((a) => a.dia >= inicioSemana && a.dia <= fimSemana),
      );
      const faturamentoMesAtual = soma(
        finalizados.filter((a) => a.dia.startsWith(mesAtual)),
      );
      const faturamentoPeriodo = soma(finalizadosMes);
      const ticketMedio = finalizadosMes.length
        ? faturamentoPeriodo / finalizadosMes.length
        : 0;

      const servicosMap = {};
      for (const a of finalizadosMes) {
        const nomeServico = String(a.servico || "Não informado").trim() || "Não informado";
        servicosMap[nomeServico] = (servicosMap[nomeServico] || 0) + 1;
      }
      const servicos = Object.entries(servicosMap)
        .map(([servico, quantidade]) => ({ servico, quantidade }))
        .sort((a, b) => b.quantidade - a.quantidade);

      const clientesMap = {};
      for (const a of finalizadosMes) {
        const nome = String(a.nome || "Cliente").trim() || "Cliente";
        if (!clientesMap[nome]) clientesMap[nome] = { nome, atendimentos: 0, total_gasto: 0 };
        clientesMap[nome].atendimentos += 1;
        clientesMap[nome].total_gasto += Number(a.valor || 0);
      }
      const topClientes = Object.values(clientesMap)
        .sort((a, b) => b.atendimentos - a.atendimentos || b.total_gasto - a.total_gasto)
        .slice(0, 5);

      res.json({
        mes,
        faturamento_hoje: faturamentoHoje,
        faturamento_semana: faturamentoSemana,
        faturamento_mes_atual: faturamentoMesAtual,
        faturamento_periodo: faturamentoPeriodo,
        atendimentos: finalizadosMes.length,
        cancelamentos: canceladosMes.length,
        ticket_medio: ticketMedio,
        servicos,
        top_clientes: topClientes,
      });
    },
  );
});

// ======================================================
// SERVIDOR
// ======================================================

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Servidor rodando em http://0.0.0.0:${PORT}`);
});
