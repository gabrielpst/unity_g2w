<div align="center">
  <img src="assets/g2w_monitor_256.png" width="128" alt="G2W Monitor">

  # G2W Monitor

  **Cliente de monitoramento de câmeras para desktop e celular.**

  [Site](https://monitor.g2wseguranca.com.br) • [Suporte](mailto:contato@g2wseguranca.com.br) • [WhatsApp](https://wa.me/5567996086281)
</div>

---

## O que é

G2W Monitor é o cliente de vídeo da **G2W Tecnologia** para acompanhar câmeras de segurança ao vivo e rever gravações, em computador ou celular.

É uma **versão modificada do [Bluecherry Client](https://github.com/bluecherrydvr/unity)** — um excelente projeto livre, que serve de base para este trabalho. A G2W mantém aqui um conjunto de ajustes voltados ao cenário em que atendemos: servidores com autenticação obrigatória, estações sem GPU dedicada e gravações em H.265.

## Ajustes desta versão

| Ajuste | O que muda na prática |
|---|---|
| Motor de vídeo **media_kit (libmpv)** no desktop | Reprodução de gravações com autenticação por credencial |
| Bibliotecas nativas do media_kit habilitadas no Linux | Permite usar o motor acima em Linux |
| Decodificação por software (`hwdec=no`) | Imagem estável em estações sem GPU dedicada ou sem suporte a decodificação HEVC por hardware |
| Cache do mpv configurado | Permite avançar e retroceder dentro da gravação |
| Busca (*seek*) serializada na linha do tempo | Evita concorrência entre eventos sobrepostos ao mudar a posição do vídeo |

Cada ajuste está isolado em um commit próprio, com a descrição técnica na mensagem. Sempre que forem úteis ao projeto original, enviamos as correções de volta como *pull request*.

## Recursos

- Vários servidores DVR na mesma interface
- Visualização ao vivo em mosaico, com layouts configuráveis
- Linha do tempo de gravações com busca por data e câmera
- Reprodução de gravações **H.265 e H.264**
- Download e exportação de trechos
- Controle PTZ nas câmeras compatíveis
- Permissões por usuário e por câmera (herdadas do servidor)
- Disponível para **Linux, Windows e Android**

## Instalação

### Linux (Debian/Ubuntu)

```bash
sudo apt install -y libmpv2
sudo apt install -y ./g2w-monitor_amd64.deb
```

> `libmpv2` é a biblioteca de vídeo usada pelo aplicativo. Sem ela a reprodução não funciona.

### Windows

Baixe e execute o instalador `g2w-monitor-setup.exe`.

### Android

Instale o `.apk` correspondente à arquitetura do aparelho (`arm64-v8a` na maioria dos celulares atuais).

Os pacotes de cada versão ficam na aba **[Releases](https://github.com/gabrielpst/unity_g2w/releases)**.

## Primeiro acesso

1. Abra o aplicativo e escolha **adicionar servidor**
2. Informe o endereço do servidor, a porta (padrão `7001`), o usuário e a senha
3. As câmeras aparecem automaticamente após a conexão

Precisa de ajuda para configurar? Fale com a gente pelos canais no topo.

## Compilando do código-fonte

Requer [Flutter](https://docs.flutter.dev/get-started/install) 3.44 ou superior.

```bash
git clone https://github.com/gabrielpst/unity_g2w.git
cd unity_g2w
flutter pub get
```

**Linux** — instale as dependências e compile:

```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libmpv-dev libsecret-1-dev libjsoncpp-dev
flutter build linux --release
```

**Windows** (precisa ser executado no Windows, com Visual Studio Build Tools):

```bash
flutter build windows --release
```

**Android:**

```bash
flutter build apk --release --split-per-abi
```

## Suporte

**G2W Tecnologia**
📧 contato@g2wseguranca.com.br
📱 (67) 99608-6281
🌐 [monitor.g2wseguranca.com.br](https://monitor.g2wseguranca.com.br)

Problemas técnicos e sugestões também podem ser registrados em [Issues](https://github.com/gabrielpst/unity_g2w/issues).

## Licença e créditos

Este programa é software livre, distribuído sob a **[GNU General Public License v3](LICENSE)**.

G2W Monitor é uma **versão modificada** do Bluecherry Client:

- Bluecherry Client — © 2022 Bluecherry LLC — https://github.com/bluecherrydvr/unity
- Modificações — © 2026 G2W Tecnologia

Você pode usar, estudar, modificar e redistribuir este programa nos termos da GPL v3. O código-fonte completo, incluindo as modificações da G2W, está neste repositório.

*"Bluecherry" é marca da Bluecherry LLC. Este projeto não é afiliado à Bluecherry LLC nem endossado por ela.*
