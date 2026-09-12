---
source: "Owner R09; qa_main.dart; CUA Chrome829822462; terminal37205"
status: "seletor-aberto-upload-bloqueado"
generated_at: "2026-09-12"
---

# Circular — seletor normal

Round E2-R09-20260912-1542. Recorte apps/superadmin -> Coelo (Principal)
-> Circulares -> Criar -> circulars.attach. C0 assumiu o Chrome apos
G0 liberar; a transferencia G6 nao foi adotada nem entregue por mensagem.

O entrypoint QA substituia incondicionalmente o seletor por bytes sinteticos.
Commit9eb24fbf1 tornou esse gancho opt-in por
`COELO_QA_SYNTHETIC_CIRCULAR_FILE`; defaultfalse usa o seletor produtivo.
`dart analyze test_driver/qa_main.dart`: PASS, sem issues. Build release QA
com emulacao de texto e gancho sintetico false: exit0,71s. Avisos de fonte e
Wasm registrados no terminal, sem falha de build. Primeiro git add falhou
por diretorio relativo incorreto, corrigido na raiz; conteudo do build
corresponde ao commit9eb24fbf1.

Servidor G0 PID39504 foi identificado e substituido pelo C0, como recurso
transferido: novo PID51168, mesma origem127.0.0.1:3014, build na worktree C0.
SHA256 de main.dart.js local e servido iguais:
`3a124742a0a8f45ddb8d80869c9b502c170b1b4dda6fcc40b746968e1bbf33d0`.
Chrome22592 e aba829822462 preservados; nenhum segundo Chrome.

Pela navegacao normal, abriu Circulares -> Nova circular -> contexto
QA R04 Cuidado (sintetico) -> Continuar. Digitou titulo
`QA R09 C0 circulars.attach 20260912-1542` e texto sintetico. O clique em
Adicionar midia aqui abriu o filechooser real (multipletrue), sem mock.
`fileChooser.setFiles` foi recusado pelo canal: code-32000, Not allowed.
A documentacao suportada chrome-file-upload-troubleshooting identifica
a permissao Allow access to file URLs da extensao como requisito.
Nao foi alterada permissao, usado canal alternativo ou injetada sessao.

Arquivo local retido `C:/Users/adrie/AppData/Local/Temp/coelo-r09-circular-picker.png`,
70bytes, SHA256 `497790947d4666760ce38f3c00e852c71fdb66cae849bae8e9ede352719e1581`.
O seletor nao recebeu o arquivo. Nenhum upload/PUT/finalize executado nessa
tentativa; nao clicar Publicar/Salvar. Cancelar retornou a lista. Captura:
[estado bloqueado](circular-picker-blocked.png).

FE local-green, BE done historico e E2E pendente permanecem distintos.
Primeiro gate: permissao do seletor no Chrome disponibilizada pelo Owner;
depois selecionar arquivo, concluir fluxo e provar persistencia/reload.
Nao contabilizar esta tentativa como E2E nem como teste automatizado PASS.
Nenhuma chave remota, SQL, deploy ou regra visual nova; novo nome de define
QA acima nao e segredo. C0 segue gates sem upload enquanto isso.
