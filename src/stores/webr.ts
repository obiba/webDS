import { defineStore, acceptHMRUpdate } from 'pinia';
import { markRaw, ref } from 'vue';
import { WebR, type CanvasMessage, type PagerMessage } from 'webr';
import initR from './init.R?raw';
import exampleR from './datashield_analysis.R?raw';
import exampleDSLiteR from './datashield_analysis_dslite.R?raw';
import exampleTidyverseR from './datashield_tidyverse.R?raw';
import exampleTidyverseDSLiteR from './datashield_tidyverse_dslite.R?raw';

/** Example script written in the home folder at startup. */
export const EXAMPLE_FILE = '/home/web_user/datashield_analysis.R';

export interface HelpPage {
  title: string;
  html: string;
}

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
function escapeHtml(text: string) {
  return text.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' })[c]!);
}

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
  // last page sent by the R pager (help topics, package index, search results)
  const helpPage = ref<HelpPage>();
  // lines waiting for R to ask for input, sent one per prompt so each echo gets the right prompt
  const pending = ref<string[]>([]);

  async function init() {
    if (status.value !== 'idle') return;
    status.value = 'loading';
    try {
      webR = new WebR();
      await webR.init();
      await webR.evalRVoid(initR);
      await webR.FS.writeFile(EXAMPLE_FILE, new TextEncoder().encode(exampleR));
      await webR.FS.writeFile('/home/web_user/datashield_analysis_dslite.R', new TextEncoder().encode(exampleDSLiteR));
      await webR.FS.writeFile('/home/web_user/datashield_tidyverse.R', new TextEncoder().encode(exampleTidyverseR));
      await webR.FS.writeFile('/home/web_user/datashield_tidyverse_dslite.R', new TextEncoder().encode(exampleTidyverseDSLiteR));
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
        case 'pager':
          void page((msg as PagerMessage).data);
          break;
        case 'closed':
          status.value = 'idle';
          return;
        default:
          // view, browse...: not handled
          console.debug('webR message ignored', msg);
      }
    }
  }

  async function page(data: PagerMessage['data']) {
    try {
      const fs = webR!.FS;
      const text = new TextDecoder().decode(await fs.readFile(data.path));
      if (data.deleteFile) await fs.unlink(data.path);
      const html = data.path.endsWith('.html')
        ? text
            // stylesheets/scripts point to R's doc server, which does not exist: inline R.css instead
            .replace(/<script[\s\S]*?<\/script>|<link[^>]*>/g, '')
            .replace('</head>', `<style>${await rCss()}</style></head>`)
        : `<pre>${escapeHtml(text)}</pre>`;
      helpPage.value = { title: data.title, html };
    } catch (e) {
      console.error(e);
    }
  }

  let css: string | undefined;
  async function rCss() {
    css ??= new TextDecoder().decode(await webR!.FS.readFile('/usr/lib/R/doc/html/R.css'));
    return css;
  }

  /** Show help of a topic (or of a package with no topic) in the help viewer. */
  function help(topic?: string, pkg?: string) {
    const t = JSON.stringify(topic);
    const p = JSON.stringify(pkg);
    const code =
      topic === undefined
        ? `print(help(package = ${p}))`
        : pkg === undefined
          ? `print(help(${t}))`
          : // links name the page's package even for topics found elsewhere: fall back to all packages
            `local({ h <- help(${t}, package = ${p}); print(if (length(h)) h else help(${t})) })`;
    // not captured: "No documentation for ..." goes to the console
    void webR?.evalRVoid(code, { captureStreams: false });
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
    pending.value.push(...code.split(/\r?\n/));
    if (!busy.value) sendNext();
  }

  function sendNext() {
    const code = pending.value.shift();
    if (!webR || code === undefined) return;
    append({ type: 'input', text: prompt.value + code });
    if (code.trim() && history.value[history.value.length - 1] !== code) history.value.push(code);
    busy.value = true;
    webR.writeConsole(code);
  }

  function interrupt() {
    pending.value = [];
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
    pending,
    plots,
    helpPage,
    help,
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
