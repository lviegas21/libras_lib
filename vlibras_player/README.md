# vlibras_player

Flutter plugin for [VLibras](https://vlibras.gov.br/) — the official Brazilian Sign Language (Libras) text-to-avatar translation service.

## Features

- **Inline player** — embed the VLibras avatar inside any widget tree
- **Floating overlay button** — accessibility button that follows the system VLibras widget convention
- Text-to-Libras translation via `VLibrasPlayer.translate(text)`
- Event stream for ready / complete / error states
- Configurable avatar (Ícaro, Hosana, Guga), speed, and server URL
- Android (WebView + JavascriptInterface) and iOS (WKWebView)

## Getting started

```yaml
dependencies:
  vlibras_player:
    path: ../libs/vlibras_player
```

### Android

Add internet permission to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS

Add to `Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

## Usage

### Inline player

```dart
VLibrasPlayerWidget(
  config: VLibrasConfig(
    avatar: VLibrasAvatar.icaro,
    autoPlay: true,
  ),
  onReady: () => VLibrasPlayer.translate('Olá, bem-vindo!'),
)
```

### Floating overlay button

```dart
Stack(
  children: [
    YourPageContent(),
    VLibrasOverlayButton(
      config: VLibrasConfig(),
    ),
  ],
)
```

### Programmatic API

> ⚠️ Este caminho (MethodChannel + WebView nativo) é um esqueleto: nunca
> renderizou o avatar e continua no contrato do VLibras 6.x. Para exibir o
> avatar use os widgets acima. Ver o dartdoc de `VLibrasPlayer`.

```dart
await VLibrasPlayer.initialize(VLibrasConfig());
await VLibrasPlayer.translate('Texto para traduzir em Libras');

VLibrasPlayer.eventStream.listen((event) {
  switch (event.type) {
    case VLibrasEventType.ready:
      // SDK pronto
    case VLibrasEventType.translateComplete:
      // tradução concluída
    case VLibrasEventType.error:
      debugPrint(event.message);
  }
});

await VLibrasPlayer.dispose();
```


## Contrato com o VLibras (manutenção)

Este plugin não usa mais o widget oficial (`vlibras-plugin.js`): ele monta
direto o `<iframe>` do player Unity e conversa por `postMessage`. A tradução
texto → glosa é feita no Dart. Os detalhes e o porquê estão no cabeçalho de
[`lib/src/vlibras_html.dart`](lib/src/vlibras_html.dart).

### De onde vem o player

`VLibrasConfig.baseUrl` aponta por padrão para `kVLibrasPortalBaseUrl`
(`https://vlibras.gov.br/app`), que serve **sempre a versão mais recente** do
VLibras. Ou seja: uma migração publicada lá entra no app sem aviso — foi uma
migração silenciosa (6.x → 7.x) que derrubou a integração anterior. O canário
abaixo existe para avisar antes do usuário sentir.

**Congelar a versão exige hospedar dois arquivos.** Apontar o `baseUrl` direto
para o jsDelivr (onde as tags do `spbgovbr-vlibras/vlibras-portal` ficam
guardadas) **não funciona**: o CDN entrega `.html` como
`Content-Type: text/plain` + `nosniff`, então o navegador mostra a página do
player como texto, nenhum script roda e o Unity nunca inicializa — testado num
device. Só os arquivos não-HTML vêm com o tipo certo.

A receita, se quiser o congelamento:

1. Copie da tag fixada (`kVLibrasPinnedPlayerAssetsUrl`) os dois arquivos
   pequenos: `unity/index.html` (686 B) e `unity/index.js` (1,2 kB).
2. Sirva-os no seu domínio como `<sua-base>/unity/index.html` e
   `<sua-base>/unity/index.js`, com `Content-Type: text/html` e
   `text/javascript`.
3. No `index.html`, aponte `unity-loader.js` e, no `index.js`, o
   `playerweb.json` para `kVLibrasPinnedPlayerAssetsUrl` (ou copie esses
   arquivos também — são ~20 MB no total).
4. `VLibrasConfig(baseUrl: '<sua-base>')` e rode
   `dart run tool/check_vlibras_contract.dart --base=<sua-base>`.

Não são congeláveis (infraestrutura viva do VLibras): o serviço de tradução
(`kVLibrasTranslateUrl`) e os bundles do dicionário (`kVLibrasDictionaryUrl`).

### Desempenho

Medido num Galaxy A22 (Helio G80), build **release**, wifi:

| cenário | CPU do processo |
|---|---|
| app sem o player | 0–5% |
| avatar parado, sem a pausa | ~200% |
| **avatar parado, com `pauseWhenIdle`** | **~30%** |
| sinalizando | ~200% |

O Unity desenha a 60 fps para sempre, mesmo com a figura em repouso — daí o
`pauseWhenIdle` (ligado por padrão): o `mainLoop` é congelado 1,5 s depois que a
sinalização acaba e retomado antes de qualquer glosa. Visualmente não muda nada,
e o pico de CPU passa a acontecer só enquanto o avatar realmente sinaliza. Para
um player que fica montado mas fora de vista, use
`VLibrasPlayerController.setActive(false)`.

Memória (PSS, somando o processo da app e o da WebView, que é separado):
**~373 MB sem nunca abrir o player** contra **~980 MB com ele vivo** — ou seja,
o player custa cerca de **600 MB**. A maior parte é do build do Unity, que
reserva 256 MB fixos (`TOTAL_MEMORY` no manifesto deles) mais os buffers
gráficos. Isso é o que pesa na decisão de manter o player vivo entre telas.

#### Tempo de inicialização

Medido no A22 com as fases instrumentadas (`[VLibras] <fase> +Xms` no logcat em
debug; o evento `ready` traz `boot_ms` em qualquer build):

| fase | 1ª vez | próximas |
|---|---|---|
| nossa página + html do player | 1,0 s | 0,6 s |
| assets do Unity (20 MB) | 9,1 s | 8,2 s |
| instanciar Unity (WASM + cena) | 2,8 s | 2,5 s |
| troca de avatar + margem | 0,6 s | 0,5 s |
| **total** | **~13,6 s** | **~11,8 s** |

O cache funciona: a primeira abertura baixa **21,1 MB**, as seguintes baixam
**0 byte** (medido no contador da wlan0). Mas ler e descomprimir esses 20 MB do
IndexedDB custa ~8 s no CPU deste aparelho — quase o mesmo que baixar. Ou seja,
**não há o que otimizar do nosso lado**: o tempo é do player do VLibras, e a
única forma de o usuário não esperar é **não rebootar o player**.

Duas estratégias, agora viáveis por causa da pausa do render loop (um player
parado custa ~30% de CPU em vez de ~200%):

- **manter um player só, vivo no nível do app** (como o `VLibrasOverlayButton`
  faz), chamando `controller.setActive(false)` quando ele sai de vista — a
  segunda tela que precisar do avatar não paga nada;
- **pré-carregar fora da tela** durante o início do app, escondendo os ~12 s
  atrás de algo que o usuário já esteja fazendo.

Destruir e recriar o widget a cada navegação é o que custa caro: são ~12 s toda
vez.

Dois cuidados que os widgets já tomam sozinhos ao ficar vivos:

- **fora de foco não desenha**: com o app em segundo plano o avatar é congelado
  (0–6% de CPU no A22, contra os ~200% de antes);
- **se a página sumir, volta**: o renderer do WebView é outro processo e o
  Android o mata sob pressão de memória; um ping a cada 30 s detecta e recria a
  WebView (`VLibrasLivenessMonitor`).

### Verificações

```sh
flutter test                                  # 46 testes de unidade
dart run tool/js_contract.dart                # protocolo do player, executado num harness Node
dart run tool/check_vlibras_contract.dart     # contratos externos, contra os serviços reais
```

- **`tool/check_vlibras_contract.dart`** é o canário: confere a página do
  player (inclusive o `Content-Type`, que é o que reprova o jsDelivr), o glue,
  os assets do Unity, um bundle do dicionário e o `POST /translate`, e **avisa
  quando o portal publica uma versão diferente da testada**. Sai com código 1 se
  algum contrato quebrou — bom para rodar num agendamento de CI. Soluço de rede
  não vira alarme: cada requisição tem três tentativas com espera.
- **`tool/js_contract.dart`** roda o JavaScript que o plugin gera dentro de um
  harness com o iframe mockado ([`test/js/harness.js`](test/js/harness.js)):
  enquadramento, sequência de boot, eventos e a ponte chamada pelo Dart. Pula
  sozinho se o Node não estiver instalado (`--strict` para falhar no CI).

### Atualizar a versão do player

1. `dart run tool/check_vlibras_contract.dart` para ver se o contrato se mantém
   na versão nova publicada no portal.
2. Suba `kVLibrasPlayerVersion` (e portanto `kVLibrasPinnedPlayerAssetsUrl`).
3. `flutter test && dart run tool/js_contract.dart`.
4. Valide num device real: avatar carrega, sinaliza, e o enquadramento continua
   pegando da cabeça às mãos (a cena do Unity muda entre versões — foi o que
   aconteceu na 7.x, ver `kVLibrasAvatarZoom`).
