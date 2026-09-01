## Não lançado

### Migração para o VLibras 7.x (quebra do 6.x em produção)

O `vlibras-plugin.js` do 6.x saiu do ar: hoje o endereço serve um stub de 2 KB
que carrega um app Preact dentro de shadow DOM e renderiza o avatar num
`<iframe>`. Todo o caminho antigo parou de funcionar — o botão de acesso ficou
inalcançável por `document.querySelector`, o CSS de esconder o chrome não
atravessa shadow DOM e `window.plugin.player.translate/loaded` deixaram de
existir. Não é possível fixar o 6.x (o bundle não está mais publicado).

- Os widgets passam a montar direto o `<iframe>` do player Unity
  (`<baseUrl>/unity/index.html`) e a falar com ele pelo protocolo `postMessage`
  do próprio player (`{type:'unity', object, method, params}` /
  `{type:'unity_event', event, data}`).
- A conversão texto → glosa passou a ser nossa e roda **no Dart**
  (`VLibrasTranslationService` → `VLibrasConfig.translateUrl`), com cache LRU
  das últimas 40 frases; para a página vai só a glosa pronta
  (`__vlibrasPlay`). Fazer esse POST com `fetch` de dentro da WebView **não
  funciona**: a página é carregada por `loadDataWithBaseURL`/`loadHTMLString`,
  cuja origem o WebView trata como caso especial, e a requisição cross-origin
  morre em CORS (verificado no device: avatar carregava, tradução falhava
  sempre). Pelo `HttpClient` não há CORS, o status HTTP chega inteiro no erro e
  dá para testar sem WebView.
- Falha de tradução virou erro **não fatal** (`data.fatal == false`): reporta ao
  app e à observabilidade sem esconder o avatar nem travar o player — antes
  qualquer erro deixava o widget no estado de erro para sempre.
- O polling de 250 ms do boot foi substituído por watchdog de inatividade
  rearmado pelos eventos reais do player (inclusive `update_progress`) — não há
  mais trabalho recorrente na thread JS competindo com o boot do Unity.
- `VLibrasEventType.loading` agora traz `progress` (% de download do avatar), e
  o overlay padrão de carregamento mostra a porcentagem.
- `translateComplete` passa a ser emitido quando o avatar **termina** de
  sinalizar (antes saía junto com o pedido de tradução).
- Girar a tela, redimensionar ou trocar avatar/velocidade/legendas não recarrega
  mais a página: são aplicados ao vivo (`__vlibrasSetStage`, `__vlibrasSetAvatar`,
  `__vlibrasSetSpeed`, `__vlibrasSetSubtitles`). Verificado no device: rotação
  com o avatar já carregado não mostra spinner nem rebaixa o player.
- **Enquadramento agora é um fator, não uma medida em px.**
  `avatarViewportHeight` virou opcional (`double?`) em `VLibrasPlayerWidget`,
  `.avatarOnly` e `VLibrasResponsivePlayer`; nulo (o padrão) deriva o zoom de
  `kVLibrasAvatarZoom` via a nova `vlibrasStageFraming()`. Como a tela virtual
  sempre tem a proporção do frame, o avatar aparece igual em **qualquer tamanho
  e qualquer proporção** de palco — card estreito, tablet, paisagem — sem o app
  hospedeiro ter que calibrar nada. Um valor fixo em CSS px continua aceito,
  mas prende o enquadramento à proporção em que o número foi escolhido.
  `VLibrasOverlayButton` passou a usar o mesmo cálculo (antes seu painel ficava
  sem zoom nenhum, com o avatar pequeno).
- `kVLibrasAvatarZoom = 1.39` calibrado no device (comparando 200/260/320/380/
  444 num palco 158 × 220, trocados ao vivo): com o antigo 200 o crop de 2,2×
  deixava as **mãos fora do quadro** — e é onde o sinal acontece. A geometria da
  transform continua idêntica à do 6.x; o que mudou foi a cena do Unity do 7.x,
  que enquadra o avatar mais perto. `kVLibrasAvatarOnlyViewport` (agora 320) só
  permanece como equivalente em px para quem quiser fixar.
- `VLibrasConfig` ganhou `playerVersion`, `dictionaryUrl`, `translateUrl`,
  `showSubtitles` e `playWelcome`. O enquadramento (`height`, `visibleWidth`,
  `avatarViewportHeight`, `contentAlignment`) mantém a mesma semântica e a mesma
  geometria de antes.
- **Pausa do render loop com o avatar parado** (`VLibrasConfig.pauseWhenIdle`,
  ligado por padrão). O Unity desenha a 60 fps para sempre, mesmo com a figura em
  repouso: medido num Galaxy A22 em **release**, o app ia de 0–5% de CPU sem o
  player para **~200% só exibindo o avatar parado**. Agora o `mainLoop` é
  congelado 1,5 s depois que a sinalização termina e retomado antes de qualquer
  glosa — visualmente idêntico, **~200% → ~30%**, com o pico ficando restrito ao
  tempo em que o avatar realmente sinaliza. `VLibrasPlayerController.setActive()`
  congela também quando o player fica montado fora de vista. Se a instância do
  Unity não estiver acessível no aparelho, não pausa (e registra o motivo) em vez
  de arriscar travar um sinal.
- Boot instrumentado por fase (`[VLibras] <fase> +Xms` no logcat em debug;
  `boot_ms` no evento `ready` em qualquer build). Medido no A22: **~13,6 s na
  primeira abertura e ~11,8 s nas seguintes**, dos quais ~8 s são o Unity
  lendo/descomprimindo seus 20 MB — que **não são rebaixados** (primeira
  abertura: 21,1 MB; seguintes: 0 byte, medido no contador da interface). Não há
  o que otimizar na nossa camada: o caminho é não rebootar o player (manter um
  vivo e pausado, ou pré-carregar), o que a pausa do render loop tornou barato.
  Ver a seção de desempenho no README.
- **Pausa quando o app sai de foco.** Os widgets agora observam o ciclo de vida
  e congelam o desenho fora do `resumed`. Medido no A22: o app ia de 206% de CPU
  sinalizando para **0–6% ao ir para segundo plano**, em vez de continuar
  desenhando atrás de outro app.
- **Recuperação se a página sumir do WebView** (`VLibrasLivenessMonitor`). O
  renderer do WebView roda em outro processo e o Android o mata sob pressão de
  memória — cenário provável ao manter o player vivo (~600 MB). Antes o avatar
  voltaria em branco sem ninguém perceber, porque o boot já estava concluído e o
  watchdog desarmado. Agora um ping barato a cada 30 s (só com o app em foco e o
  player pronto) detecta a perda e recria a WebView; exige duas falhas seguidas
  para não rebootar por causa de um `runJavaScript` que falhou à toa. Validado
  no device: perda simulada → detecção → player de pé de novo em 9,7 s, sozinho.
- **Congelar a versão do player não é possível só trocando a URL.** Testado no
  device: apontar `baseUrl` para a tag no jsDelivr faz o player nunca
  inicializar, porque o CDN serve `.html` como `text/plain` + `nosniff` (de
  propósito) — o navegador trata a página do player como texto. O padrão
  continua sendo o portal (`kVLibrasPortalBaseUrl`); `kVLibrasPinnedPlayerAssetsUrl`
  fica documentado com a receita de congelamento (hospedar dois arquivos de
  ~2 kB) no README.
- Dois verificadores de contrato: `tool/check_vlibras_contract.dart` (canário
  contra os serviços reais — player, assets do Unity, dicionário, tradução — e
  aviso quando o portal publica versão diferente da fixada) e
  `tool/js_contract.dart` + `test/js/harness.js` (roda o JavaScript gerado num
  harness Node com o iframe mockado). Documentados no README.
- O caminho nativo (`VLibrasPlayer.initialize` + WebView headless de
  Android/iOS) **não** foi migrado: continua no contrato 6.x e segue sem
  renderizar nada, como já era antes. Use os widgets.

## 0.1.0

- Initial release
- Inline `VLibrasPlayerWidget` with text-to-Libras avatar
- `VLibrasOverlayButton` floating accessibility button
- Android: WebView + JavascriptInterface
- iOS: WKWebView + WKScriptMessageHandler
- `VLibrasPlayer` Dart API: initialize, translate, show, hide, dispose
- Event stream: onReady, onTranslateComplete, onError
