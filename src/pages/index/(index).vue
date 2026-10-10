<template>
  <q-page :style-fn="fullHeight">
    <!-- small screens: the side panel moves to a drawer, toggled from the header -->
    <q-splitter
      :model-value="small ? 100 : split"
      class="fit"
      :disable="small"
      :separator-class="small ? 'hidden' : 'bg-grey-4'"
      separator-style="width: 3px"
      @update:model-value="split = $event"
    >
      <template #before>
        <q-splitter
          v-model="editorSplit"
          horizontal
          class="fit"
          separator-class="bg-grey-4"
          separator-style="height: 3px"
        >
          <template #before>
            <EditorPanel ref="editor" class="fit" />
          </template>
          <template #separator>
            <q-avatar
              rounded
              color="primary"
              text-color="white"
              size="20px"
              icon="drag_handle"
              style="width: 32px; height: 14px"
            />
          </template>

          <template #after>
            <ConsolePanel class="fit" />
          </template>
        </q-splitter>
      </template>
      <template #separator>
        <q-avatar
          rounded
          color="primary"
          text-color="white"
          size="20px"
          icon="drag_handle"
          style="width: 32px; height: 14px; transform: translate(-50%, -50%) rotate(90deg)"
        />
      </template>
      <template #after>
        <Teleport defer to="#side-drawer" :disabled="!small">
          <div class="fit column no-wrap">
            <q-tabs v-model="tab" dense no-caps align="left">
              <q-tab name="files" label="Files" />
              <q-tab name="plots" label="Plots" />
              <q-tab name="packages" label="Packages" />
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
              <q-tab-panel name="packages" class="q-pa-none">
                <PackageList class="fit" />
              </q-tab-panel>
              <q-tab-panel name="help" class="q-pa-none">
                <HelpViewer class="fit" />
              </q-tab-panel>
            </q-tab-panels>
          </div>
        </Teleport>
      </template>
    </q-splitter>
    <q-drawer v-model="drawer" side="right" behavior="mobile" bordered :width="360">
      <div id="side-drawer" class="fit" />
    </q-drawer>
  </q-page>
</template>

<script setup lang="ts">
import { computed, inject, onMounted, ref, type Ref, useTemplateRef, watch } from 'vue';
import { useQuasar } from 'quasar';
import ConsolePanel from '@/components/ConsolePanel.vue';
import EditorPanel from '@/components/EditorPanel.vue';
import FileBrowser from '@/components/FileBrowser.vue';
import HelpViewer from '@/components/HelpViewer.vue';
import PackageList from '@/components/PackageList.vue';
import PlotViewer from '@/components/PlotViewer.vue';
import { EXAMPLE_FILE, useWebRStore } from '@/stores/webr';

const $q = useQuasar();
const webr = useWebRStore();
const small = computed(() => $q.screen.lt.md);
// toggled from the layout header
const drawer = inject('sideDrawer', ref(false));
const editor = useTemplateRef('editor');
const split = stored('webds.split', 70);
const editorSplit = stored('webds.editorSplit', 55);
const tab = stored('webds.tab', 'files');

// bring plots forward when R starts a new one
watch(
  () => webr.plots.length,
  () => show('plots'),
);
watch(
  () => webr.helpPage,
  () => show('help'),
);

// empty once the panel is back in the splitter
watch(small, (s) => !s && (drawer.value = false));

function show(name: string) {
  tab.value = name;
  drawer.value = small.value;
}

onMounted(async () => {
  await webr.init();
  if (webr.status === 'ready') void editor.value?.open(EXAMPLE_FILE);
});

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
