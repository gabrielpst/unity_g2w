# SITUAÇÃO desta branch (`locked-server-build`) — 2026-09-02

Esta branch é a variante Flutter do G2W Monitor com **servidor fixo** pro condomínio
Silvestre4 (`camerassilvestre4.g2wtecnologia.net:7001`), pacote
`br.com.g2wseguranca.monitor.silvestre4`, assinada com a keystore da G2W via CI.

⚠️ **Ela NÃO é mais o app oficial do Silvestre4.** Decisão do Gabriel em 2026-09-02:
o oficial é o app **Expo/React Native** — repositório
`github.com/gabrielpst/G2WMonitor_APP` — que usa o **mesmo pacote e a mesma
keystore**. Por isso:

- **Não subir `.aab`/`.apk` desta branch no Play Console** com este pacote. Um
  rascunho (versionCode 19, 2026-08-17) ficou parado em Produção e deve ser
  descartado.
- Os versionCodes 16, 17, 18 e 19 já foram consumidos no Play Console por esta
  branch; o app Expo segue em 2018+.
- A branch fica como **reserva** (tem push/Firebase, PTZ e tela de eventos, que
  o Expo não tem). Se a decisão mudar, tudo aqui continua funcionando.

Documentação completa (tabela comparativa, linha do tempo, regras de assinatura
e pendências) fica no Nextcloud da G2W:
`01 - Redes/20 - Clientes/10 - Silvestre4/contexto/2026-09-02-app-cameras-decisao-expo-oficial.md`.
