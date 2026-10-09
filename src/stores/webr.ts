import { defineStore, acceptHMRUpdate } from 'pinia';
import { ref } from 'vue';
import { WebR } from 'webr';

export interface ConsoleLine {
  id: number;
  type: 'stdout' | 'stderr' | 'input';
  text: string;
}

// ponytail: oldest lines dropped beyond this, virtual scroll if full scrollback matters
const MAX_LINES = 5000;
let lineId = 0;

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
  // lines waiting for R to ask for input, sent one per prompt so each echo gets the right prompt
  const pending: string[] = [];

  async function init() {
    if (status.value !== 'idle') return;
    status.value = 'loading';
    try {
      webR = new WebR();
      await webR.init();
      await webR.evalRVoid('options(device = webr::canvas)');
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
          append({ type: msg.type, text: msg.data as string });
          break;
        case 'prompt':
          prompt.value = msg.data as string;
          busy.value = false;
          sendNext();
          break;
        case 'closed':
          status.value = 'idle';
          return;
        default:
          // canvas, pager, view...: handled in later phases
          console.debug('webR message ignored', msg);
      }
    }
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
