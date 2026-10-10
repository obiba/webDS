<template>
  <q-layout view="hHh lpR fFf">
    <q-header elevated class="bg-dark text-white">
      <q-toolbar>
        <q-toolbar-title>Web R/DataSHIELD</q-toolbar-title>
        <q-btn
          flat
          dense
          no-caps
          icon="extension"
          label="Install packages"
          :disable="webr.status !== 'ready'"
          @click="install"
        />
      </q-toolbar>
      <!-- in the header: the page height accounts for it -->
      <q-banner v-if="banner" dense inline-actions class="bg-warning text-dark">
        <template #avatar><q-icon name="warning" /></template>
        This is a DataSHIELD playground: R runs in your browser (WebAssembly, with webR). Execution,
        package installation and requests to DataSHIELD servers are much slower than in a normal R
        runtime.
        <template #action>
          <q-btn flat dense no-caps label="Dismiss" @click="banner = false" />
        </template>
      </q-banner>
    </q-header>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useQuasar } from 'quasar';
import { useWebRStore } from '@/stores/webr';

const $q = useQuasar();
const webr = useWebRStore();
// shown at each visit: it is a warning
const banner = ref(true);

function install() {
  $q.dialog({
    title: 'Install packages',
    message: 'Package names, separated by spaces or commas (e.g. DSOpal dsBaseClient)',
    prompt: { model: '', type: 'text' },
    cancel: true,
  }).onOk((input: string) => {
    // names go into R code: keep valid package names only
    const names = input.split(/[\s,]+/).filter((n) => /^[A-Za-z][A-Za-z0-9.]*$/.test(n));
    // through the console: progress and errors show there
    if (names.length) webr.write(`install.packages(c(${names.map((n) => `"${n}"`).join(', ')}))`);
  });
}
</script>
