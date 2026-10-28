"use strict";

const crypto = require("crypto");

const API_MP = "https://api.mercadopago.com";
const VALOR = 96;
const PROMO = "Clube VIP GBarberClub - 4 cortes por mês";

module.exports = function registrarAssinaturas({
  app,
  db,
  autenticarClienteToken,
  autenticarBarbeiro,
}) {
  // ==========================================
  // BANCO DE DADOS
  // ==========================================

  const run = (sql, params = []) =>
    new Promise((resolve, reject) => {
      db.run(sql, params, function (erro) {
        if (erro) reject(erro);
        else resolve(this);
      });
    });

  const get = (sql, params = []) =>
    new Promise((resolve, reject) => {
      db.get(sql, params, (erro, row) => {
        if (erro) reject(erro);
        else resolve(row);
      });
    });

  const all = (sql, params = []) =>
    new Promise((resolve, reject) => {
      db.all(sql, params, (erro, rows) => {
        if (erro) reject(erro);
        else resolve(rows);
      });
    });

  db.serialize(() => {
    db.run(`
      CREATE TABLE IF NOT EXISTS assinaturas_vip (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL UNIQUE,
        mp_id TEXT UNIQUE,
        status TEXT NOT NULL DEFAULT 'pendente',
        checkout_url TEXT,
        criado_em INTEGER NOT NULL,
        atualizado_em INTEGER NOT NULL,
        FOREIGN KEY(cliente_id) REFERENCES clientes_app(id)
      )
    `);

    db.run(`
      CREATE TABLE IF NOT EXISTS mp_webhook_auditoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        recurso_id TEXT NOT NULL,
        acao TEXT NOT NULL DEFAULT '',
        mp_assinatura_id TEXT,
        cliente_id INTEGER,
        status_recurso TEXT,
        recebido_em INTEGER NOT NULL,
        UNIQUE(tipo, recurso_id, acao)
      )
    `);
  });

  // ==========================================
  // API MERCADO PAGO
  // ==========================================

  async function mp(path, method = "GET", body) {
    const token = process.env.MERCADO_PAGO_ACCESS_TOKEN;

    if (!token) {
      throw Object.assign(
        new Error("MERCADO_PAGO_ACCESS_TOKEN não configurado"),
        { status: 503 },
      );
    }

    const response = await fetch(`${API_MP}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        ...(method === "POST"
          ? { "X-Idempotency-Key": crypto.randomUUID() }
          : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(15000),
    });

    const result = await response.json().catch(() => ({}));

    if (!response.ok) {
      console.error("");
      console.error("========== ERRO MERCADO PAGO ==========");
      console.error("HTTP:", response.status);
      console.error("Código:", result.error || result.code || "Não informado");
      console.error("Mensagem:", result.message || "Não informada");

      console.error(
        "Causas:",
        Array.isArray(result.cause)
          ? result.cause.map((causa) => ({
              code: causa.code,
              description: causa.description,
            }))
          : "Não informadas",
      );

      console.error("=======================================");
      console.error("");

      throw Object.assign(new Error("Falha ao consultar Mercado Pago"), {
        status: 502,
      });
    }

    return result;
  }

  function handler(fn) {
    return (req, res) => {
      Promise.resolve()
        .then(() => fn(req, res))
        .catch((erro) => {
          console.error("Assinaturas:", erro.message);

          if (!res.headersSent) {
            res.status(erro.status || 500).json({
              erro:
                erro.status === 503
                  ? erro.message
                  : "Não foi possível concluir a operação.",
            });
          }
        });
    };
  }

  // ==========================================
  // VALIDAÇÃO SEGURA DO WEBHOOK
  // ==========================================

  function assinaturaValida(req) {
    const secret = process.env.MERCADO_PAGO_WEBHOOK_SECRET;

    if (!secret) return false;

    const signature = String(req.headers["x-signature"] || "");

    const requestId = String(req.headers["x-request-id"] || "");

    const matchTs = signature.match(/(?:^|,)\s*ts=([^,]+)/);

    const matchV1 = signature.match(/(?:^|,)\s*v1=([a-fA-F0-9]{64})(?:,|$)/);

    const idUrl = String(
      req.query["data.id"] ?? req.query.data_id ?? "",
    ).trim();

    const idBody = String(req.body?.data?.id ?? "").trim();

    console.log("Diagnóstico webhook:", {
      temTimestamp: Boolean(matchTs),
      temAssinatura: Boolean(matchV1),
      temRequestId: Boolean(requestId),
      temIdNaUrl: Boolean(idUrl),
      temIdNoBody: Boolean(idBody),
    });

    if (!matchTs || !matchV1 || !requestId || !idUrl) {
      return false;
    }

    const ts = matchTs[1].trim();

    if (!/^\d{10,13}$/.test(ts)) {
      return false;
    }

    const timestamp = Number(ts);

    const timestampMs = ts.length === 10 ? timestamp * 1000 : timestamp;

    if (!Number.isFinite(timestampMs)) {
      return false;
    }

    const diferenca = Math.abs(Date.now() - timestampMs);

    if (diferenca > 10 * 60 * 1000) {
      console.log("Webhook: timestamp fora da janela.");
      return false;
    }

    const manifest =
      `id:${idUrl.toLowerCase()};` + `request-id:${requestId};` + `ts:${ts};`;

    const esperado = crypto
      .createHmac("sha256", secret)
      .update(manifest)
      .digest();

    const recebido = Buffer.from(matchV1[1], "hex");

    return (
      esperado.length === recebido.length &&
      crypto.timingSafeEqual(esperado, recebido)
    );
  }

  // ==========================================
  // WEBHOOK MERCADO PAGO
  // ==========================================

  app.post(
    "/mercadopago/webhook",
    handler(async (req, res) => {
      if (
        !process.env.MERCADO_PAGO_WEBHOOK_SECRET ||
        !process.env.MERCADO_PAGO_ACCESS_TOKEN
      ) {
        return res.status(503).json({
          erro: "Webhook não configurado",
        });
      }

      if (!assinaturaValida(req)) {
        return res.status(401).json({
          erro: "Assinatura da notificação inválida",
        });
      }

      const tipo = String(
        req.body?.type || req.query.type || req.body?.topic || "",
      ).trim();

      const recursoId = String(
        req.query["data.id"] ?? req.query.data_id ?? "",
      ).trim();

      const bodyId = req.body?.data?.id;

      if (
        bodyId != null &&
        String(bodyId).toLowerCase() !== recursoId.toLowerCase()
      ) {
        return res.status(400).json({
          erro: "ID da notificação inconsistente",
        });
      }

      const permitido = {
        subscription_preapproval: (id) =>
          `/preapproval/${encodeURIComponent(id)}`,

        subscription_authorized_payment: (id) =>
          `/authorized_payments/${encodeURIComponent(id)}`,
      };

      if (!Object.hasOwn(permitido, tipo)) {
        return res.status(200).json({
          recebido: true,
          ignorado: true,
        });
      }

      if (!/^[a-zA-Z0-9_-]{1,120}$/.test(recursoId)) {
        return res.status(400).json({
          erro: "ID inválido",
        });
      }

      // Confirma o recurso diretamente na API.
      const recurso = await mp(permitido[tipo](recursoId));

      if (String(recurso.id || "").toLowerCase() !== recursoId.toLowerCase()) {
        return res.status(502).json({
          erro: "Recurso divergente do Mercado Pago",
        });
      }

      const mpId =
        tipo === "subscription_preapproval"
          ? recursoId
          : String(recurso.preapproval_id || recurso.subscription_id || "");

      if (!mpId) {
        return res.status(200).json({
          recebido: true,
          ignorado: true,
        });
      }

      const local = await get(
        `SELECT id, cliente_id
         FROM assinaturas_vip
         WHERE mp_id = ?`,
        [mpId],
      );

      if (!local) {
        return res.status(200).json({
          recebido: true,
          ignorado: true,
        });
      }

      const acao = String(req.body?.action || "").slice(0, 100);

      await run(
        `INSERT INTO mp_webhook_auditoria
         (
           tipo,
           recurso_id,
           acao,
           mp_assinatura_id,
           cliente_id,
           status_recurso,
           recebido_em
         )
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(tipo, recurso_id, acao)
         DO UPDATE SET
           status_recurso = excluded.status_recurso,
           recebido_em = excluded.recebido_em`,
        [
          tipo,
          recursoId,
          acao,
          mpId,
          local.cliente_id,
          String(recurso.status || ""),
          Date.now(),
        ],
      );

      console.log("Webhook validado e registrado:", tipo);

      // Não libera cortes sem conciliação financeira.
      return res.status(200).json({
        recebido: true,
      });
    }),
  );

  // ==========================================
  // CLIENTE - CONSULTAR ASSINATURA
  // ==========================================

  app.get(
    "/cliente/assinatura",
    autenticarClienteToken,
    handler(async (req, res) => {
      const row = await get(
        `SELECT *
         FROM assinaturas_vip
         WHERE cliente_id = ?`,
        [req.clienteAutenticadoId],
      );

      res.json({
        plano: "vip_4_cortes",
        valor: VALOR,
        limite_cortes: 4,
        status: row?.status || "inativa",
        cortes_usados: 0,
        proxima_renovacao: null,
      });
    }),
  );

  // ==========================================
  // CLIENTE - CRIAR ASSINATURA
  // ==========================================

  app.post(
    "/cliente/assinatura/checkout",
    autenticarClienteToken,
    handler(async (req, res) => {
      const cliente = await get(
        `SELECT id, email
         FROM clientes_app
         WHERE id = ?`,
        [req.clienteAutenticadoId],
      );

      if (!cliente) {
        return res.status(404).json({
          erro: "Cliente não encontrado",
        });
      }

      if (req.body?.plano !== "vip_4_cortes") {
        return res.status(400).json({
          erro: "Plano inválido",
        });
      }

      const back = process.env.MERCADO_PAGO_BACK_URL;

      if (!back || !/^https:\/\//.test(back)) {
        return res.status(503).json({
          erro: "Configure MERCADO_PAGO_BACK_URL com uma URL HTTPS válida",
        });
      }

      const existente = await get(
        `SELECT *
         FROM assinaturas_vip
         WHERE cliente_id = ?`,
        [cliente.id],
      );

      if (existente?.mp_id) {
        const atual = await mp(
          `/preapproval/${encodeURIComponent(existente.mp_id)}`,
        );

        if (["authorized", "paused", "pending"].includes(atual.status)) {
          const url = existente.checkout_url || atual.init_point;

          if (url) {
            return res.json({
              checkout_url: url,
              status: atual.status,
            });
          }

          return res.status(409).json({
            erro: "Já existe uma assinatura para este cliente.",
          });
        }
      }

      const novo = await mp("/preapproval", "POST", {
        reason: PROMO,
        external_reference: `gbarber_cliente_${cliente.id}`,
        payer_email: cliente.email,
        back_url: back,
        auto_recurring: {
          frequency: 1,
          frequency_type: "months",
          transaction_amount: VALOR,
          currency_id: "BRL",
        },
        status: "pending",
      });

      if (!novo.id || !novo.init_point) {
        throw Object.assign(
          new Error("Checkout não retornado pelo Mercado Pago"),
          { status: 502 },
        );
      }

      await run(
        `INSERT INTO assinaturas_vip
         (
           cliente_id,
           mp_id,
           status,
           checkout_url,
           criado_em,
           atualizado_em
         )
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(cliente_id)
         DO UPDATE SET
           mp_id = excluded.mp_id,
           status = excluded.status,
           checkout_url = excluded.checkout_url,
           atualizado_em = excluded.atualizado_em`,
        [
          cliente.id,
          String(novo.id),
          "pendente",
          novo.init_point,
          Date.now(),
          Date.now(),
        ],
      );

      res.status(201).json({
        checkout_url: novo.init_point,
        status: "pendente",
      });
    }),
  );

  // ==========================================
  // CLIENTE - CANCELAR ASSINATURA
  // ==========================================

  app.post(
    "/cliente/assinatura/cancelar",
    autenticarClienteToken,
    handler(async (req, res) => {
      const row = await get(
        `SELECT *
         FROM assinaturas_vip
         WHERE cliente_id = ?`,
        [req.clienteAutenticadoId],
      );

      if (!row?.mp_id) {
        return res.status(404).json({
          erro: "Assinatura não encontrada",
        });
      }

      await mp(`/preapproval/${encodeURIComponent(row.mp_id)}`, "PUT", {
        status: "cancelled",
      });

      await run(
        `UPDATE assinaturas_vip
         SET status = ?, atualizado_em = ?
         WHERE id = ?`,
        ["cancelada", Date.now(), row.id],
      );

      res.json({
        sucesso: true,
        mensagem: "Cancelamento solicitado no Mercado Pago.",
      });
    }),
  );

  // ==========================================
  // BARBEIRO - PAINEL DE ASSINANTES
  // ==========================================

  app.get(
    "/app/assinaturas",
    autenticarBarbeiro,
    handler(async (req, res) => {
      const registros = await all(`
        SELECT a.status, c.nome
        FROM assinaturas_vip a
        JOIN clientes_app c
          ON c.id = a.cliente_id
        ORDER BY a.criado_em DESC
        LIMIT 200
      `);

      res.json({
        ativos: 0,
        receita_recebida_mes: 0,
        receita_recorrente_prevista: 0,
        assinantes: registros.map((r) => ({
          nome: r.nome,
          status: r.status,
          cortes_usados: 0,
          proxima_renovacao: null,
        })),
      });
    }),
  );
};
