<template>
  <q-page :style-fn="fullHeight">
    <q-splitter v-model="split" class="fit">
      <template #before>
        <q-splitter v-model="editorSplit" horizontal class="fit">
          <template #before>
            <EditorPanel ref="editor" class="fit" />
          </template>
          <template #after>
            <ConsolePanel class="fit" />
          </template>
        </q-splitter>
      </template>
      <template #after>
        <div class="fit column no-wrap">
          <q-tabs v-model="tab" dense no-caps align="left">
            <q-tab name="files" label="Files" />
            <q-tab name="plots" label="Plots" />
            <q-tab name="help" label="Help" />
          </q-tabs>
          <q-separator />
          <q-tab-panels v-model="tab" class="col" keep-alive>
            <q-tab-panel name="files" class="q-pa-none">
              <FileBrowser class="fit" @open="editor?.open($event)" />
            </q-tab-panel>
            <q-tab-panel name="plots" class="q-pa-none">
              <PlotViewer class="fit" />
            </q-tab-panel>
            <q-tab-panel name="help" class="q-pa-none">
              <HelpViewer class="fit" />
            </q-tab-panel>
          </q-tab-panels>
        </div>
      </template>
    </q-splitter>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, type Ref, useTemplateRef, watch } from 'vue';
import ConsolePanel from '@/components/ConsolePanel.vue';
import EditorPanel from '@/components/EditorPanel.vue';
import FileBrowser from '@/components/FileBrowser.vue';
import HelpViewer from '@/components/HelpViewer.vue';
import PlotViewer from '@/components/PlotViewer.vue';
import { useWebRStore } from '@/stores/webr';

const webr = useWebRStore();
const editor = useTemplateRef('editor');
const split = stored('webds.split', 70);
const editorSplit = stored('webds.editorSplit', 55);
const tab = stored('webds.tab', 'files');

// bring plots forward when R starts a new one
watch(
  () => webr.plots.length,
  () => (tab.value = 'plots'),
);
watch(
  () => webr.helpPage,
  () => (tab.value = 'help'),
);

onMounted(() => void webr.init());

/** Ref remembered in this browser; storage may be unavailable (private mode...). */
function stored<T>(key: string, initial: T): Ref<T> {
  let value = initial;
  try {
    const saved = localStorage.getItem(key);
    if (saved !== null) value = JSON.parse(saved) as T;
  } catch {
    // keep initial
  }
  const r = ref(value) as Ref<T>;
  watch(r, (v) => {
    try {
      localStorage.setItem(key, JSON.stringify(v));
    } catch {
      // not remembered
    }
  });
  return r;
}

function fullHeight(offset: number) {
  return { height: `calc(100vh - ${offset}px)` };
}
</script>
