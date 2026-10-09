<template>
  <div class="console column no-wrap relative-position" @click="focus">
    <q-btn
      flat
      dense
      round
      size="sm"
      icon="block"
      class="absolute-top-right q-ma-xs"
      style="z-index: 1"
      title="Clear console (Ctrl+L)"
      @click.stop="webr.clear()"
    />
    <div ref="output" class="col scroll q-pa-sm">
      <div v-if="!webr.crossOriginIsolated" class="box-warning q-mb-sm">
        Not cross-origin isolated: interrupt and readline() are unavailable.
      </div>
      <div v-if="webr.status === 'loading'"><q-spinner /> Loading R...</div>
      <div v-else-if="webr.status === 'error'" class="box-negative">{{ webr.error }}</div>
      <div
        v-for="line in webr.lines"
        :key="line.id"
        :class="`console-${line.type}`"
        v-text="line.text"
      />
      <div v-if="webr.status === 'ready'" class="row no-wrap items-center">
        <span class="console-input">{{ webr.prompt }}</span>
        <input
          ref="input"
          v-model="code"
          class="col console-line"
          spellcheck="false"
          autocomplete="off"
          @keydown.enter="run"
          @keydown.up.prevent="browse(-1)"
          @keydown.down.prevent="browse(1)"
          @keydown.ctrl.c="interrupt"
          @keydown.ctrl.l.prevent="webr.clear()"
          @paste="paste"
        />
        <q-btn
          v-if="webr.busy"
          flat
          dense
          size="sm"
          icon="stop"
          color="negative"
          title="Interrupt (Ctrl+C)"
          @click="webr.interrupt()"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { nextTick, ref, useTemplateRef, watch } from 'vue';
import { useWebRStore } from '@/stores/webr';

const webr = useWebRStore();
const output = useTemplateRef<HTMLDivElement>('output');
const input = useTemplateRef<HTMLInputElement>('input');
const code = ref('');
// position in history while browsing; history.length means "new line"
const historyIndex = ref(0);

watch(
  () => webr.history.length,
  (n) => (historyIndex.value = n),
);

watch(
  () => webr.lines.length,
  async () => {
    await nextTick();
    output.value?.scrollTo({ top: output.value.scrollHeight });
  },
);

function focus() {
  // keep text selection in output usable
  if (!window.getSelection()?.toString()) input.value?.focus();
}

function run() {
  webr.write(code.value);
  code.value = '';
}

function browse(step: number) {
  const i = Math.min(Math.max(historyIndex.value + step, 0), webr.history.length);
  historyIndex.value = i;
  code.value = webr.history[i] ?? '';
}

function paste(e: ClipboardEvent) {
  const text = e.clipboardData?.getData('text') ?? '';
  if (!/\r?\n/.test(text)) return;
  e.preventDefault();
  const el = e.target as HTMLInputElement;
  const all =
    code.value.slice(0, el.selectionStart ?? 0) + text + code.value.slice(el.selectionEnd ?? 0);
  // run complete lines, keep the trailing fragment in the input as a terminal does
  const parts = all.split(/\r?\n/);
  code.value = parts.pop() ?? '';
  webr.write(parts.join('\n'));
}

function interrupt(e: KeyboardEvent) {
  const el = e.target as HTMLInputElement;
  // keep Ctrl+C as copy when text is selected
  if (el.selectionStart !== el.selectionEnd) return;
  e.preventDefault();
  webr.interrupt();
  code.value = '';
}
</script>

<style scoped>
.console {
  font-family: monospace;
  font-size: 14px;
}
.console > div > div {
  white-space: pre-wrap;
  word-break: break-all;
}
.console-line {
  border: none;
  outline: none;
  font: inherit;
  background: transparent;
  padding: 0;
}
.console-input {
  color: #1565c0;
  white-space: pre;
}
.console-stderr {
  color: #c62828;
}
</style>
