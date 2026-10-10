<template>
  <div class="column no-wrap">
    <div class="row no-wrap items-center">
      <q-tabs
        v-model="active"
        class="col"
        dense
        no-caps
        inline-label
        align="left"
        outside-arrows
        mobile-arrows
      >
        <q-tab v-for="tab in tabs" :key="tab.path" :name="tab.path" :title="tab.path">
          <span>{{ tab.name }}{{ tab.dirty ? ' *' : '' }}</span>
          <q-btn flat dense round size="xs" icon="close" class="q-ml-xs" @click.stop="close(tab)" />
        </q-tab>
      </q-tabs>
      <template v-if="current">
        <q-btn flat dense size="sm" icon="save" title="Save (Ctrl+S)" @click="save()" />
        <q-btn
          flat
          dense
          size="sm"
          icon="play_arrow"
          title="Run line or selection (Ctrl+Enter)"
          @click="run()"
        />
        <q-btn
          flat
          dense
          size="sm"
          icon="double_arrow"
          title="Source file (Ctrl+Shift+S)"
          @click="source()"
        />
      </template>
    </div>
    <q-separator />
    <div v-show="current" ref="container" class="col" />
    <div v-if="!current" class="col flex flex-center text-help">
      Open a file from the Files panel
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  computed,
  markRaw,
  onBeforeUnmount,
  onMounted,
  reactive,
  ref,
  useTemplateRef,
  watch,
} from 'vue';
import { useQuasar } from 'quasar';
import ace, { type Ace } from 'ace-builds';
import 'ace-builds/src-noconflict/mode-r';
import 'ace-builds/src-noconflict/theme-monokai';
import { useWebRStore } from '@/stores/webr';

interface Tab {
  path: string;
  name: string;
  session: Ace.EditSession;
  saved: string;
  dirty: boolean;
}

const $q = useQuasar();
const webr = useWebRStore();
const container = useTemplateRef<HTMLDivElement>('container');
const tabs = reactive<Tab[]>([]);
const active = ref<string>();
const current = computed(() => tabs.find((tab) => tab.path === active.value));
// one editor, one session per tab: each file keeps its own undo history and cursor
let editor: Ace.Editor | undefined;

onMounted(() => {
  editor = ace.edit(container.value, {
    theme: 'ace/theme/monokai',
    showPrintMargin: false,
    fontSize: 14,
  });
  editor.commands.addCommands([
    { name: 'run', bindKey: { win: 'Ctrl-Enter', mac: 'Cmd-Enter' }, exec: () => run() },
    { name: 'save', bindKey: { win: 'Ctrl-S', mac: 'Cmd-S' }, exec: () => void save() },
    {
      name: 'source',
      bindKey: { win: 'Ctrl-Shift-S', mac: 'Cmd-Shift-S' },
      exec: () => void source(),
    },
  ]);
});

onBeforeUnmount(() => editor?.destroy());

watch(current, (tab) => {
  if (!tab || !editor) return;
  editor.setSession(tab.session);
  editor.focus();
});

async function open(path: string) {
  if (!tabs.some((tab) => tab.path === path)) {
    try {
      const text = new TextDecoder().decode(await webr.fs().readFile(path));
      const session = markRaw(ace.createEditSession(text));
      session.setMode('ace/mode/r');
      const tab: Tab = { path, name: path.split('/').pop()!, session, saved: text, dirty: false };
      tabs.push(tab);
      // the reactive proxy, so dirty updates the tab label
      const reactiveTab = tabs[tabs.length - 1]!;
      session.on('change', () => (reactiveTab.dirty = session.getValue() !== reactiveTab.saved));
    } catch (e) {
      $q.notify({ type: 'negative', message: e instanceof Error ? e.message : String(e) });
      return;
    }
  }
  active.value = path;
}

async function save(tab = current.value) {
  if (!tab) return;
  const text = tab.session.getValue();
  await webr.fs().writeFile(tab.path, new TextEncoder().encode(text));
  tab.saved = text;
  tab.dirty = false;
}

function run() {
  if (!editor || !current.value) return;
  const selected = editor.getSelectedText();
  if (selected) {
    // a selection ending a line would otherwise send an extra empty line
    webr.write(selected.replace(/\r?\n$/, ''));
  } else {
    // run current line and move to the next one
    const row = editor.getCursorPosition().row;
    webr.write(current.value.session.getLine(row));
    editor.gotoLine(row + 2, 0, false);
  }
}

async function source() {
  const tab = current.value;
  if (!tab) return;
  await save(tab);
  webr.write(`source(${JSON.stringify(tab.path)}, echo = TRUE)`);
}

function close(tab: Tab) {
  const remove = () => {
    const i = tabs.indexOf(tab);
    tabs.splice(i, 1);
    tab.session.destroy();
    if (active.value === tab.path) active.value = (tabs[i] ?? tabs[i - 1])?.path;
  };
  if (!tab.dirty) return remove();
  $q.dialog({
    title: 'Unsaved changes',
    message: `Close ${tab.name} without saving?`,
    cancel: true,
  }).onOk(remove);
}

defineExpose({ open });
</script>
