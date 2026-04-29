const express = require("express")
const cors = require("cors")

const app = express()

app.use(cors())
app.use(express.json())

app.use(express.static(__dirname))

let agendamentos = []

const horariosBase = [
    "08:00", "08:40", "09:20", "10:00",
    "10:40", "11:20", "12:00", "12:40",
    "13:20", "14:00", "14:40", "15:20",
    "16:00", "16:40", "17:20", "18:00",
    "18:40", "19:20", "20:00"
]

// horários livres
app.get("/horarios-livres/:data/:barbeiro", (req, res) => {

const data = req.params.data
const barbeiro = req.params.barbeiro

const ocupados = agendamentos
.filter(a => a.dia === data && a.barbeiro === barbeiro)
.map(a => a.horario)

const livres = horariosBase.filter(h => !ocupados.includes(h))

res.json(livres)

})


// criar agendamento
app.post("/agendar", (req, res) => {

    const { nome, numero, dia, horario, barbeiro, servico } = req.body

    console.log("Dados recebidos:")
    console.log(req.body)

    const ocupado = agendamentos.find(a =>
        a.dia === dia &&
        a.horario === horario &&
        a.barbeiro === barbeiro
    )

    if (ocupado) {
        return res.json({ sucesso: false })
    }

    agendamentos.push({

        id: Date.now(),

        nome,
        numero,
        dia,
        horario,

        barbeiro: barbeiro || "gustavo",

        servico: servico || "Corte",

        status: "Confirmado"

    })

    console.log("Novo agendamento:", nome, horario)

    res.json({ sucesso: true })

})


// buscar agendamentos barbeiro
app.get("/agendamentos/:barbeiro", (req, res) => {

    const barbeiro = req.params.barbeiro

    const lista = agendamentos.filter(a => a.barbeiro === barbeiro)

    res.json(lista)

})


// finalizar corte
app.put("/finalizar/:id",(req,res)=>{

const id = req.params.id

const agendamento = agendamentos.find(a => a.id == id)

if(!agendamento){
return res.status(404).json({erro:"Agendamento não encontrado"})
}

agendamento.status = "Finalizado"

res.json({sucesso:true})

})

app.delete("/cancelar/:id",(req,res)=>{

const id = req.params.id

const index = agendamentos.findIndex(a => a.id == id)

if(index === -1){
return res.status(404).json({erro:"Agendamento não encontrado"})
}

const removido = agendamentos[index]

agendamentos.splice(index,1)

console.log("Agendamento cancelado:", removido.id)

res.json({sucesso:true})

})


const PORT = process.env.PORT || 3000

app.listen(PORT, () => {
    console.log("Servidor rodando na porta " + PORT)
})