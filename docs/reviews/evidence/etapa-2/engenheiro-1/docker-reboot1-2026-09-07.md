---
title: Docker — recuperação nominal reboot1
source: Reserva do Coordenador; processos e logs locais; verificações do root
status: recuperado e smoke validado
generated: 2026-09-07
---

O início normal do Docker Desktop Hidden (PID 10400, 2026-09-07T23:52:50Z) falhou em dockerInference. O log das 23:52:51Z registrou socket inacessível e listener com sintaxe inválida. A interface registrou uma ação Reset to factory defaults às 23:53:14Z, fora das operações executadas por esta tarefa. Não foi inferida perda ou preservação total do estado anterior.

Com Docker/backend ausentes, foram validados os caminhos absolutos, ancestrais sem reparse e destinos inexistentes. O diretório run continha somente três sockets zero-byte; docker-secrets-engine continha somente engine.sock zero-byte. A recuperação autorizada preservou esses diretórios nos backups exatos:

- C:/Users/adrie/AppData/Local/Docker/run-coelo-backup-20260907-reboot1
- C:/Users/adrie/AppData/Local/docker-secrets-engine-coelo-backup-20260907-reboot1

Os diretórios originais foram recriados vazios. Desktop iniciado Hidden uma vez, PID 20472, em 2026-09-07T23:56:19.7962873Z. Nenhum factory reset, prune, delete, alteração de ACL ou WSL global foi executado por esta tarefa.

Em 2026-09-07T23:57:58Z, daemon Linux 29.7.2 saudável. Inventário observado: zero containers, zero volumes e 28 imagens disponíveis. A imagem pg_prove 3.36 continuava com ID sha256:eda7c5e68719e9c8287e78c017118407b48df904a51c935f5ab6098b8c0bc6bc, sem volumes declarados.

Smoke coelo_engine_smoke_e1_20260907_reboot1: /bin/true, imagem por ID, --pull never, --network none, --read-only e --rm; exit 0. Consulta posterior confirmou container nominal ausente e daemon respondendo. Os cinco backups nominais — três anteriores e dois reboot1 — permaneciam presentes com seus arquivos. Nenhum replay N01 foi iniciado nesta recuperação.

Próximo gate: concluir testes de fixture, parse e revisão independente do seletor N01PrerequisitesRed; depois executar somente o diagnóstico autorizado 50+2, sem pontes.