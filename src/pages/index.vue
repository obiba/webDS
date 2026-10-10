<template>
  <q-layout view="lHh lpR fFf">
    <q-header elevated class="bg-dark text-white">
      <q-toolbar>
        <q-btn flat dense round icon="menu" aria-label="Menu" @click="drawer = !drawer" />
        <q-toolbar-title>Web R/DataSHIELD</q-toolbar-title>
        <q-btn
          v-if="$q.screen.lt.md"
          flat
          dense
          round
          icon="menu"
          aria-label="Files, plots and help"
          @click="sideDrawer = !sideDrawer"
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

    <q-drawer v-model="drawer" show-if-above bordered>
      <q-list>
        <q-item-label header>Links</q-item-label>
        <q-item
          v-for="link in links"
          :key="link.link"
          clickable
          tag="a"
          target="_blank"
          :href="link.link"
        >
          <q-item-section avatar>
            <q-icon :name="link.icon" />
          </q-item-section>
          <q-item-section>
            <q-item-label>{{ link.title }}</q-item-label>
            <q-item-label caption>{{ link.caption }}</q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
    </q-drawer>

    <q-page-container>
      <router-view />
    </q-page-container>
    <welcome-dialog />
  </q-layout>
</template>

<script setup lang="ts">
import { provide, ref } from 'vue';
import { useQuasar } from 'quasar';
import WelcomeDialog from '@/components/WelcomeDialog.vue';

const $q = useQuasar();
// shown at each visit: it is a warning
const banner = ref(true);
const drawer = ref(true);
// right drawer of the index page, on small screens
const sideDrawer = ref(false);
provide('sideDrawer', sideDrawer);

const links = [
  {
    title: 'DataSHIELD',
    caption: 'Documentation and tutorials',
    icon: 'school',
    link: 'https://wiki.datashield.org',
  },
  {
    title: 'DSI',
    caption: 'DataSHIELD Interface R package',
    icon: 'hub',
    link: 'https://datashield.github.io/DSI',
  },
  {
    title: 'dsBaseClient',
    caption: 'DataSHIELD analysis functions R package',
    icon: 'functions',
    link: 'https://datashield.github.io/dsBaseClient/',
  },
  {
    title: 'dsTidyverseClient',
    caption: 'DataSHIELD tidyverse R package',
    icon: 'table_view',
    link: 'https://molgenis.github.io/ds-tidyverse-client/',
  },
  {
    title: 'OBiBa/Opal',
    caption: 'DataSHIELD server documentation',
    icon: 'storage',
    link: 'https://opaldoc.obiba.org',
  },
  {
    title: 'webR',
    caption: 'R in the browser',
    icon: 'menu_book',
    link: 'https://docs.r-wasm.org/webr/latest/',
  },
  {
    title: 'Source code',
    caption: 'github.com/obiba/webDS',
    icon: 'code',
    link: 'https://github.com/obiba/webDS',
  },
];
</script>
