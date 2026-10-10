<template>
  <div class="column no-wrap relative-position">
    <q-toolbar class="q-px-xs q-py-sm" style="min-height: 0">
      <q-btn
        flat
        dense
        size="sm"
        icon="chevron_left"
        title="Previous plot"
        :disable="index <= 0"
        @click="index--"
      />
      <span class="text-caption"
        >{{ webr.plots.length ? index + 1 : 0 }} / {{ webr.plots.length }}</span
      >
      <q-btn
        flat
        dense
        size="sm"
        icon="chevron_right"
        title="Next plot"
        :disable="index >= webr.plots.length - 1"
        @click="index++"
      />
      <q-space />
      <q-btn
        flat
        dense
        size="sm"
        icon="download"
        title="Export as PNG"
        :disable="!webr.plots.length"
        @click="exportPng"
      />
    </q-toolbar>
    <q-separator />
    <div ref="container" class="col plot-container flex flex-center q-pa-xs" />
    <div v-if="!webr.plots.length" class="absolute-center text-help">No plots yet</div>
  </div>
</template>

<script setup lang="ts">
import { ref, useTemplateRef, watch } from 'vue';
import { useWebRStore } from '@/stores/webr';

const webr = useWebRStore();
const container = useTemplateRef<HTMLDivElement>('container');
const index = ref(webr.plots.length - 1);

// show the newest plot as soon as R starts it
watch(
  () => webr.plots.length,
  (n) => (index.value = n - 1),
);

// the store's canvases are shown as is: R drawing updates them live
watch(
  [index, container],
  ([i, el]) => {
    const canvas = webr.plots[i];
    el?.replaceChildren(...(canvas ? [canvas] : []));
  },
  { immediate: true },
);

function exportPng() {
  webr.plots[index.value]?.toBlob((blob) => {
    if (!blob) return;
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `plot-${index.value + 1}.png`;
    a.click();
    URL.revokeObjectURL(a.href);
  });
}
</script>

<style scoped>
.plot-container {
  overflow: hidden;
}
/* canvases are appended outside the template: scoped styles need :deep */
.plot-container :deep(canvas) {
  max-width: 100%;
  max-height: 100%;
  background: white;
}
</style>
