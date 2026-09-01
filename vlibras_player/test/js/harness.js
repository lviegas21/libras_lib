/**
 * Harness do contrato entre a nossa página e o player Unity do VLibras.
 *
 * Roda o JavaScript que `buildVLibrasHtml()` gera, com o `<iframe>` do player e
 * o canal do Dart mockados, e verifica o protocolo inteiro: montagem do iframe,
 * enquadramento, sequência de boot, eventos, ponte chamada pelo Dart.
 *
 * O `flutter test` só consegue afirmar que certas strings estão no HTML; aqui a
 * lógica é de fato executada. Se o VLibras mudar o protocolo (foi o que a
 * migração 6.x → 7.x fez com a camada do widget), é aqui que aparece.
 *
 * Uso:  dart run tool/js_contract.dart     (gera a página e chama este arquivo)
 *       node test/js/harness.js <pagina.html>
 */
const fs = require('fs');
const vm = require('vm');

const pagePath = process.argv[2];
if (!pagePath) {
  console.error('uso: node harness.js <pagina.html>');
  process.exit(2);
}

// A página tem dois <script>: o primeiro é a rede de captura de erros, o
// segundo é o player. É o segundo que queremos exercitar.
const html = fs.readFileSync(pagePath, 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
if (scripts.length < 2) {
  console.error('página inesperada: ' + scripts.length + ' bloco(s) de script');
  process.exit(2);
}

const posted = [];   // eventos que subiriam pro Dart
const sent = [];     // postMessage enviados ao iframe
let iframe = null;

const listeners = {};
const addListener = (type, fn) => (listeners[type] = listeners[type] || []).push(fn);
const fire = (type, ev) => (listeners[type] || []).forEach((f) => f(ev));

// Instância Unity de mentira, para exercitar a pausa do render loop.
const unityCalls = [];
const fakeIframe = () => ({
  id: '', title: '', style: {}, attrs: {},
  setAttribute(k, v) { this.attrs[k] = v; },
  remove() { this.removed = true; },
  contentWindow: {
    postMessage: (msg) => sent.push(msg),
    getUnityInstance: () => ({
      Module: {
        pauseMainLoop: () => unityCalls.push('pause'),
        resumeMainLoop: () => unityCalls.push('resume'),
      },
    }),
  },
});

const sandbox = {
  console,
  setTimeout, clearTimeout, setInterval, clearInterval,
  Date, Math, JSON, Number, String, Array, Object, Error, isFinite, AbortController,
  navigator: { onLine: true },
  VLibrasChannel: { postMessage: (s) => posted.push(JSON.parse(s)) },
  // A página NÃO pode fazer rede: a tradução vive no Dart. Qualquer chamada
  // aqui é falha de contrato.
  fetch: () => { sandbox.usouRede = true; return Promise.reject(new Error('a página não deve usar rede')); },
  document: {
    getElementById: (id) => (id === 'vlibras-stage' ? { appendChild: (el) => (iframe = el) } : null),
    createElement: () => fakeIframe(),
  },
};
sandbox.window = sandbox;
sandbox.window.innerWidth = 144;
sandbox.window.innerHeight = 200;
sandbox.window.addEventListener = addListener;
sandbox.window.removeEventListener = () => {};

vm.createContext(sandbox);
vm.runInContext(scripts[1], sandbox);

const fails = [];
function check(nome, cond, extra) {
  if (cond) console.log('  ok   ' + nome);
  else {
    console.log('  FALHA ' + nome + (extra !== undefined ? ' -> ' + JSON.stringify(extra) : ''));
    fails.push(nome);
  }
}
const phases = () => posted.filter((p) => p.type === 'loading').map((p) => p.data.phase);
const unity = (event, data) =>
  fire('message', { source: iframe.contentWindow, data: { type: 'unity_event', event, data } });

(async () => {
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));

  console.log('1) montagem do iframe do player');
  check('fase loading-player', phases().includes('loading-player'), phases());
  check('src do player Unity',
    iframe && /\/unity\/index\.html\?v=/.test(iframe.src), iframe && iframe.src);
  check('sandbox do iframe',
    iframe.attrs.sandbox === 'allow-scripts allow-same-origin allow-pointer-lock', iframe.attrs);
  check('altura = tela virtual', iframe.style.height === '444.44px', iframe.style);
  // cover = max(144/320, 200/444.44) = 0.45 ; s = 0.45 * 2.2222 = 1.0
  // tx = (144-320)/2 = -88 ; ty = (200-444.44)/2 = -122.22
  check('transform de cover + âncora',
    iframe.style.transform === 'translate(-88.00px,-122.22px) scale(1.0000)', iframe.style.transform);

  console.log('2) glosa pedida antes de o player estar pronto fica na fila');
  sandbox.window.__vlibrasPlay('OL BOM_DIA [PONTO]');
  check('não vai pro iframe ainda', sent.length === 0, sent);

  console.log('3) html do player carregou');
  iframe.onload();
  check('fase booting-avatar', phases().includes('booting-avatar'), phases());

  console.log('4) progresso real de download');
  unity('update_progress', 0.5);
  const prog = posted.find((p) => p.type === 'loading' && p.data.phase === 'downloading-avatar');
  check('progresso 50% reportado', prog && prog.data.progress === 50, prog);

  console.log('5) mensagem de outra janela é ignorada');
  const antes = posted.length;
  fire('message', { source: {}, data: { type: 'unity_event', event: 'on_load_player' } });
  check('origem estranha ignorada', posted.length === antes);

  console.log('6) on_load_player dispara a sequência de boot');
  unity('on_load_player');
  check('setBaseUrl com o dicionário',
    sent.some((m) => m.method === 'setBaseUrl' && /WEBGL/.test(String(m.params))), sent);
  check('setSlider com a velocidade', sent.some((m) => m.method === 'setSlider' && m.params === 1), sent);
  check('legendas desligadas', sent.some((m) => m.method === 'setSubtitlesState' && m.params === 0), sent);
  check('tudo via PlayerManager', sent.every((m) => m.type === 'unity' && m.object === 'PlayerManager'), sent);
  check('ready ainda não saiu', !posted.some((p) => p.type === 'ready'));

  await wait(700);
  check('Change do avatar depois do settle', sent.some((m) => m.method === 'Change' && m.params === 'icaro'), sent);
  check('sem playWellcome por padrão', !sent.some((m) => m.method === 'playWellcome'), sent);
  check('ready emitido', posted.some((p) => p.type === 'ready'));

  console.log('7) a fila é despejada quando o player fica pronto');
  await wait(50);
  check('página não usou rede', !sandbox.usouRede);
  check('playNow com a glosa',
    sent.some((m) => m.method === 'playNow' && m.params === 'OL BOM_DIA [PONTO]'), sent);

  console.log('8) fim da sinalização vira translateComplete');
  unity('on_playing_state_change', ['True', 'False', 'False', 'False', 'False']);
  check('ainda sinalizando', !posted.some((p) => p.type === 'translateComplete'));
  unity('on_playing_state_change', ['False', 'False', 'False', 'False', 'False']);
  check('translateComplete emitido', posted.some((p) => p.type === 'translateComplete'));

  console.log('9) segunda glosa toca de novo');
  sandbox.window.__vlibrasPlay('OI');
  await wait(20);
  check('dois playNow', sent.filter((m) => m.method === 'playNow').length === 2,
    sent.filter((m) => m.method === 'playNow'));

  console.log('10) skip interrompe');
  sandbox.window.__vlibrasSkip();
  check('stopAll enviado', sent.some((m) => m.method === 'stopAll'), sent);

  console.log('11) velocidade / avatar / legendas ao vivo');
  sandbox.window.__vlibrasSetSpeed(1.5);
  sandbox.window.__vlibrasSetAvatar('hosana');
  sandbox.window.__vlibrasSetAvatar('inexistente');
  sandbox.window.__vlibrasSetSubtitles(true);
  check('setSlider 1.5', sent.some((m) => m.method === 'setSlider' && m.params === 1.5), sent);
  check('Change hosana', sent.some((m) => m.method === 'Change' && m.params === 'hosana'), sent);
  check('avatar inválido ignorado', !sent.some((m) => m.params === 'inexistente'), sent);
  check('legendas ligadas', sent.some((m) => m.method === 'setSubtitlesState' && m.params === 1), sent);

  console.log('12) reenquadramento ao vivo (sem rebootar o Unity)');
  sandbox.window.__vlibrasSetStage(200, 1, 0.5, 0);
  // cover = max(144/320, 200/200) = 1 ; tx = (144-320)/2 = -88 ; ty = (200-200)*0 = 0
  check('nova transform', iframe.style.transform === 'translate(-88.00px,0.00px) scale(1.0000)', iframe.style.transform);
  check('nova altura da tela virtual', iframe.style.height === '200px', iframe.style.height);
  check('player não remontou', !iframe.removed);

  console.log('13) pausa do render loop com o avatar parado');
  await wait(1700);   // deixa o timer de repouso disparar
  check('congela quando ninguém sinaliza',
    unityCalls[unityCalls.length - 1] === 'pause', unityCalls);
  sandbox.window.__vlibrasPlay('OI');
  check('tocar acorda o desenho antes da glosa',
    unityCalls[unityCalls.length - 1] === 'resume', unityCalls);
  sandbox.window.__vlibrasSetActive(false);
  check('setActive(false) pausa', unityCalls[unityCalls.length - 1] === 'pause', unityCalls);
  sandbox.window.__vlibrasSetActive(true);
  check('setActive(true) retoma', unityCalls[unityCalls.length - 1] === 'resume', unityCalls);

  console.log('14) erro do Unity vira erro fatal no Dart');
  unity('on_error', 'unsupported');
  const err = posted.find((p) => p.type === 'error');
  check('erro com kind unity-error', err && err.data.kind === 'unity-error', err);
  check('erro de boot é fatal', err && err.data.fatal === undefined, err);

  console.log('');
  if (fails.length) {
    console.log(fails.length + ' FALHA(S): ' + fails.join(', '));
    console.log('O contrato com o player do VLibras mudou — ver test/js/harness.js');
    process.exit(1);
  }
  console.log('contrato ok — todas as checagens passaram');
})();
