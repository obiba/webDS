<template>
  <div class="column no-wrap relative-position">
    <q-toolbar class="q-px-xs q-gutter-x-xs" style="min-height: 0">
      <q-btn
        flat
        dense
        size="sm"
        icon="arrow_back"
        title="Back"
        :disable="pages.length < 2"
        @click="pages.pop()"
      />
      <q-input
        v-model="topic"
        class="col"
        dense
        borderless
        placeholder="Help topic"
        @keyup.enter="search"
      >
        <template #prepend><q-icon name="search" size="xs" /></template>
      </q-input>
    </q-toolbar>
    <q-separator />
    <iframe
      v-if="current"
      class="col help-frame"
      sandbox="allow-same-origin"
      :srcdoc="current.html"
      :title="current.title"
      @load="onLoad"
    />
    <div v-else class="absolute-center text-help">Type ?topic in the console or search above</div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { type HelpPage, useWebRStore } from '@/stores/webr';

const webr = useWebRStore();
const topic = ref('');
// visited pages, for back navigation; the first one may have arrived before this tab was mounted
const pages = ref<HelpPage[]>(webr.helpPage ? [webr.helpPage] : []);
const current = computed(() => pages.value[pages.value.length - 1]);

watch(
  () => webr.helpPage,
  (page) => page && pages.value.push(page),
);

function search() {
  if (topic.value.trim()) webr.help(topic.value.trim());
}

// sandboxed page cannot run scripts: links are handled from here
function onLoad(e: Event) {
  const doc = (e.target as HTMLIFrameElement).contentDocument;
  doc?.addEventListener('click', (ev) => {
    const href = (ev.target as Element).closest('a')?.getAttribute('href');
    if (!href) return;
    ev.preventDefault();
    let m;
    if (href.startsWith('#')) {
      const id = decodeURIComponent(href.slice(1));
      (doc.getElementById(id) ?? doc.getElementsByName(id)[0])?.scrollIntoView();
    } else if (/^https?:/.test(href)) {
      window.open(href, '_blank', 'noopener');
    } else if ((m = /\.\.\/\.\.\/([^/]*)\/help\/([^#?]+)/.exec(href))) {
      // dynamic help link: ../../<package, may be empty>/help/<topic>
      webr.help(decodeURIComponent(m[2]!), m[1] || undefined);
    } else if ((m = /\.\.\/\.\.\/([^/]+)\/html\/00Index\.html/.exec(href))) {
      webr.help(undefined, m[1]);
    }
  });
}
</script>

<style scoped>
.help-frame {
  border: none;
  width: 100%;
  background: white;
}
</style>
