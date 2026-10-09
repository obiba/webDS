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
        <FileBrowser class="fit" @open="editor?.open($event)" />
      </template>
    </q-splitter>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, useTemplateRef } from 'vue';
import ConsolePanel from '@/components/ConsolePanel.vue';
import EditorPanel from '@/components/EditorPanel.vue';
import FileBrowser from '@/components/FileBrowser.vue';
import { useWebRStore } from '@/stores/webr';

const webr = useWebRStore();
const editor = useTemplateRef('editor');
const split = ref(70);
const editorSplit = ref(55);

onMounted(() => void webr.init());

function fullHeight(offset: number) {
  return { height: `calc(100vh - ${offset}px)` };
}
</script>
