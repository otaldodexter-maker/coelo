---
source: "R02 duplicate82f08af50; user night scope; form confirmation pattern; base b285a6804"
status: "local-24-pass; no-production-or-E2E-certification"
generated_at: "2026-09-09"
---

# Conclusão após duplicação confirmada

`apps/superadmin -> Acessos -> Modelos -> duplicar -> access-models.duplicate`.
Após receber a cópia, a página apagava a intenção e chamava a navegação dentro
do tratamento do comando. Callback falho permitia uma segunda duplicação com
novo requestId; um StateError também escapava para o framework.

A conclusão confirmada agora fica vinculada à revisão de contexto. Repetir
Continuar chama somente a navegação; nome/motivo deixam de ser editáveis e a
troca de repository/duplicator/domínio/origem invalida a conclusão. Erro de
navegação não é tratado como negativa de autorização do RPC. A negativa real
continua descartando dados, campos e botão, conforme a R02.

Prova RED:2F (`duplicate-receipt-red.txt`) reproduziram duas escritas e o erro
inesperado de callback. GREEN único: **24P/0F/0B/0S/0U**: contexto6, consumo de
comandos9 e rotas9. A execução inicial (`duplicate-receipt-attempt01.txt`)
teve13P e duas falhas distintas: nome de arquivo de rota incorreto (erro do
comando, sem caso executado) e fixture de duplicação devolvendo o ID da origem.
Essa fixture contradizia o contrato SQL e foi corrigida para devolver ID novo,
preservando a validação estrita do cliente. Reexecutados somente esse caso1P,
as rotas pelo caminho correto9P e a nova negativa de contexto1P. Os13 verdes
não foram repetidos. O total24 contém cada caso uma única vez.

As nove provas da rota normal cobrem permitido, capability ausente, escopo
institucional, domínio inválido, revogação durante leitura/comando, negativa
RPC, erro RPC e repository ausente/demo. Nenhum hunk de router foi alterado.

Analyzer dos três arquivos alterados: sem problemas. A captura375 usa fontes
reais do teste, painel de estado e rodapé existentes; pai inspecionou
`duplicate-confirmed-375.png`, sem campos editáveis, overflow ou botão fora da
tela. `prepare_duplicate_capture.py` materializa um teste temporário, removido
após captura; o rerun de um caso para imagem não aumenta a contagem. Nenhuma
golden foi atualizada. Isso não certifica navegação/HTTP reais ou autorização.

Próximo: integração coordenada; pacote SQL de Modelos e concorrência de
receipts permanecem gates separados. Memória no-op: mesma regra existente de
não repetir persistência confirmada, sem nova decisão de produto.
