# Assinatura de release (Android)

Este app usa uma keystore própria da G2W pra assinar builds de release — sem
ela, o `build.gradle` cai de volta pra chave de debug (só serve pra teste
local, a Play Store não aceita).

## Onde está a keystore

**Não fica neste repositório** (nunca deve ser commitada — ver `android/.gitignore`).
Guardada em:

```
G2W Tecnologia/01 - Redes/20 - Clientes/09 - G2W Gabriel/chaves-assinatura/g2w-monitor-release.keystore
```

Senha, alias e detalhes técnicos no `.credenciais` da mesma pasta.

## Como configurar uma máquina de build

1. Copie `g2w-monitor-release.keystore` pra dentro de `android/` neste repositório (mesmo diretório deste README).
2. Crie `android/key.properties` (também gitignored) com:
   ```properties
   storePassword=<senha do .credenciais>
   keyPassword=<mesma senha — PKCS12 usa uma senha só>
   keyAlias=g2wmonitor
   storeFile=g2w-monitor-release.keystore
   ```
3. Rode `flutter build appbundle --release` (ou `apk`) normalmente — o `build.gradle` detecta o `key.properties` e assina com a chave real automaticamente.

Sem esses dois arquivos, o build continua funcionando (chave de debug), só não serve pra publicar.

## CI (GitHub Actions)

Ainda não configurado — o workflow (`build.yml`) tem um `TODO` comentado pra
decodificar a keystore/`key.properties` de secrets do repositório
(`KEY_STORE`, `KEY_PROPERTIES`, base64). Fazer isso quando for automatizar
releases assinadas via CI; até lá, builds de release assinados são manuais.

⚠️ **Nunca perder a keystore ou a senha** — é o que permite publicar
atualizações do app já instalado por usuários. Perder = precisa publicar um
app novo do zero (novo pacote, perde todos os usuários/avaliações).
