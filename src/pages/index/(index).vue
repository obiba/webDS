<template>
  <q-page :style-fn="fullHeight">
    <q-splitter v-model="split" class="fit">
      <template #before>
        <ConsolePanel class="fit" />
      </template>
      <template #after>
        <FileBrowser class="fit" />
      </template>
    </q-splitter>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import ConsolePanel from '@/components/ConsolePanel.vue';
import FileBrowser from '@/components/FileBrowser.vue';
import { useWebRStore } from '@/stores/webr';

const webr = useWebRStore();
const split = ref(65);

onMounted(() => void webr.init());

function fullHeight(offset: number) {
  return { height: `calc(100vh - ${offset}px)` };
}
</script>
