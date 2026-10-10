<template>
  <div class="column no-wrap relative-position">
    <q-toolbar class="q-px-xs q-gutter-x-xs" style="min-height: 0">
      <q-input
        v-model="filter"
        class="col"
        dense
        borderless
        clearable
        placeholder="Filter packages"
      >
        <template #prepend><q-icon name="search" size="xs" /></template>
      </q-input>
      <q-btn
        flat
        dense
        size="sm"
        icon="add"
        title="Install packages"
        :disable="webr.status !== 'ready'"
        @click="install"
      />
      <q-btn
        flat
        dense
        size="sm"
        icon="refresh"
        title="Refresh"
        :loading="loading"
        @click="refresh"
      />
    </q-toolbar>
    <q-separator />
    <q-list dense class="col scroll">
      <q-item v-for="p in shown" :key="p.name + p.version">
        <q-item-section side>
          <!-- run in the console, so the command and its messages show there; the list refreshes after -->
          <q-checkbox
            :model-value="p.loaded"
            dense
            size="xs"
            :title="p.loaded ? 'Detach' : 'Attach'"
            @update:model-value="
              webr.write(
                $event
                  ? `library(${JSON.stringify(p.name)})`
                  : `detach(${JSON.stringify('package:' + p.name)}, unload = TRUE)`,
              )
            "
          />
        </q-item-section>
        <q-item-section>
          <a href="#" title="Package help" @click.prevent="webr.help(undefined, p.name)">{{
            p.name
          }}</a>
        </q-item-section>
        <q-item-section side class="text-caption">{{ p.version }}</q-item-section>
      </q-item>
    </q-list>
    <div v-if="!loading && !shown.length" class="absolute-center text-help">No packages</div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { type Package, useWebRStore } from '@/stores/webr';

const $q = useQuasar();
const webr = useWebRStore();
const filter = ref<string | null>('');
const list = ref<Package[]>([]);
const loading = ref(false);
const shown = computed(() => {
  const f = filter.value?.toLowerCase() ?? '';
  return list.value.filter((p) => p.name.toLowerCase().includes(f));
});

async function refresh() {
  loading.value = true;
  try {
    list.value = await webr.packages();
  } finally {
    loading.value = false;
  }
}

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

onMounted(refresh);
// library(), install.packages()... run from the console: refresh once R is idle again
watch(
  () => webr.busy,
  (busy) => !busy && void refresh(),
);
watch(
  () => webr.status,
  (s) => s === 'ready' && void refresh(),
);
</script>
