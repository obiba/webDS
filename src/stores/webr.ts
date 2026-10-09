import { defineStore, acceptHMRUpdate } from 'pinia';
import { markRaw, ref } from 'vue';
import { WebR, type CanvasMessage } from 'webr';

export interface ConsoleLine {
  id: number;
  type: 'stdout' | 'stderr' | 'input';
  text: string;
}

// ponytail: oldest lines dropped beyond this, virtual scroll if full scrollback matters
const MAX_LINES = 5000;
let lineId = 0;
// ANSI escape sequences (colors, cursor show/hide...)
// ponytail: stripped, render colors if needed
// eslint-disable-next-line no-control-regex -- matching ESC is the point
const ANSI = /\x1b\[[0-9;?]*[A-Za-z]/g;

/** Render one output line as a terminal would: carriage returns overwrite from line start. */
function toLine(text: string) {
  let line = '';
  for (const part of text.replace(ANSI, '').split('\r')) line = part + line.slice(part.length);
  return line;
}

export const useWebRStore = defineStore('webr', () => {
  // not reactive: the WebR instance must not be wrapped in a Vue proxy
  let webR: WebR | undefined;

  const status = ref<'idle' | 'loading' | 'ready' | 'error'>('idle');
  const error = ref<string>();
  const crossOriginIsolated = ref(window.crossOriginIsolated);
  const lines = ref<ConsoleLine[]>([]);
  const prompt = ref('> ');
  const busy = ref(false);
  const history = ref<string[]>([]);
  // one canvas per plot page, drawn as R sends images
  const plots = ref<HTMLCanvasElement[]>([]);
  // lines waiting for R to ask for input, sent one per prompt so each echo gets the right prompt
  const pending: string[] = [];

  async function init() {
    if (status.value !== 'idle') return;
    status.value = 'loading';
    try {
      webR = new WebR();
      await webR.init();
      // shim_install: install.packages() fetches wasm binaries instead of building sources
      await webR.evalRVoid('webr::shim_install(); options(device = webr::canvas)');
      // curl's 10s connect timeout is too short through the webR websocket relay;
      // httr (used by opalr/DSOpal) is set up whenever it gets loaded
      await webR.evalRVoid(
        'setHook(packageEvent("httr", "onLoad"), function(...) httr::set_config(httr::config(connecttimeout = 60)))',
      );
      status.value = 'ready';
      void readLoop(webR);
    } catch (e) {
      status.value = 'error';
      error.value = e instanceof Error ? e.message : String(e);
    }
  }

  async function readLoop(r: WebR) {
    for (;;) {
      const msg = await r.read();
      switch (msg.type) {
        case 'stdout':
        case 'stderr':
          append({ type: msg.type, text: toLine(msg.data as string) });
          break;
        case 'prompt':
          prompt.value = msg.data as string;
          busy.value = false;
          sendNext();
          break;
        case 'canvas':
          draw((msg as CanvasMessage).data);
          break;
        case 'closed':
          status.value = 'idle';
          return;
        default:
          // pager, view...: handled in later phases
          console.debug('webR message ignored', msg);
      }
    }
  }

  // ponytail: single device, message ids ignored; track them if dev.new() matters
  function draw(data: CanvasMessage['data']) {
    if (data.event === 'canvasNewPage') {
      plots.value.push(markRaw(document.createElement('canvas')));
      return;
    }
    let canvas = plots.value[plots.value.length - 1];
    if (!canvas) {
      canvas = markRaw(document.createElement('canvas'));
      plots.value.push(canvas);
    }
    if (canvas.width !== data.image.width || canvas.height !== data.image.height) {
      canvas.width = data.image.width;
      canvas.height = data.image.height;
    }
    canvas.getContext('2d')?.drawImage(data.image, 0, 0);
    data.image.close();
  }

  function append(line: Omit<ConsoleLine, 'id'>) {
    lines.value.push({ ...line, id: lineId++ });
    if (lines.value.length > MAX_LINES) lines.value.splice(0, lines.value.length - MAX_LINES);
  }

  /** Queue code for R, one or more lines. */
  function write(code: string) {
    pending.push(...code.split(/\r?\n/));
    if (!busy.value) sendNext();
  }

  function sendNext() {
    const code = pending.shift();
    if (!webR || code === undefined) return;
    append({ type: 'input', text: prompt.value + code });
    if (code.trim() && history.value[history.value.length - 1] !== code) history.value.push(code);
    busy.value = true;
    webR.writeConsole(code);
  }

  function interrupt() {
    pending.length = 0;
    webR?.interrupt();
  }

  /** Emscripten virtual file system of the R session. */
  function fs() {
    if (!webR) throw new Error('R is not started');
    return webR.FS;
  }

  function clear() {
    lines.value = [];
  }

  return {
    status,
    error,
    crossOriginIsolated,
    lines,
    prompt,
    busy,
    history,
    plots,
    init,
    write,
    interrupt,
    clear,
    fs,
  };
});

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useWebRStore, import.meta.hot));
}
