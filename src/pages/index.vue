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
    </q-header>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { useQuasar } from 'quasar';
import { useWebRStore } from '@/stores/webr';

const $q = useQuasar();
const webr = useWebRStore();

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
