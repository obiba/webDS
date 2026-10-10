<template>
  <div class="column no-wrap">
    <q-toolbar class="q-px-xs q-py-sm" style="min-height: 0">
      <q-btn flat dense size="sm" icon="note_add" title="New file" @click="create(false)" />
      <q-btn
        flat
        dense
        size="sm"
        icon="create_new_folder"
        title="New folder"
        @click="create(true)"
      />
      <q-btn flat dense size="sm" icon="upload" title="Upload" @click="uploader?.click()" />
      <q-btn
        flat
        dense
        size="sm"
        icon="download"
        title="Download"
        :disable="!selectedNode || selectedNode.isFolder"
        @click="download"
      />
      <q-btn
        flat
        dense
        size="sm"
        icon="delete"
        title="Delete"
        :disable="!selectedNode || selectedNode.path === HOME"
        @click="remove"
      />
      <q-space />
      <q-btn flat dense size="sm" icon="refresh" title="Refresh" @click="refresh" />
      <input ref="uploader" type="file" multiple hidden @change="upload" />
    </q-toolbar>
    <q-separator />
    <q-tree
      v-model:selected="selected"
      v-model:expanded="expanded"
      class="col scroll q-pa-xs"
      :nodes="nodes"
      node-key="path"
      dense
      no-transition
      @update:selected="onSelect"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, useTemplateRef, watch } from 'vue';
import { useQuasar } from 'quasar';
import type { FSNode } from 'webr';
import { useWebRStore } from '@/stores/webr';

interface TreeNode {
  label: string;
  path: string;
  isFolder: boolean;
  icon: string;
  children?: TreeNode[];
}

const HOME = '/home/web_user';
// webR runtime artifacts, not user files
const HIDDEN = ['default.profraw'];

const emit = defineEmits<{ open: [path: string] }>();

const $q = useQuasar();
const webr = useWebRStore();
const uploader = useTemplateRef<HTMLInputElement>('uploader');
const nodes = ref<TreeNode[]>([]);
const selected = ref<string | null>(null);
const expanded = ref<string[]>([HOME]);

const selectedNode = computed(() =>
  selected.value ? find(nodes.value, selected.value) : undefined,
);

// directory where new/uploaded files go: selected folder, else the selected file's folder
const targetDir = computed(() => {
  const node = selectedNode.value;
  if (!node) return HOME;
  return node.isFolder ? node.path : node.path.slice(0, node.path.lastIndexOf('/'));
});

onMounted(() => {
  if (webr.status === 'ready') void refresh();
});
// R may create or delete files: refresh whenever it is ready for input again
watch(
  () => webr.status === 'ready' && !webr.busy,
  (idle) => idle && void refresh(),
);

function toTree(node: FSNode, path: string): TreeNode {
  const children = node.isFolder
    ? Object.values(node.contents ?? {})
        .filter((child) => !HIDDEN.includes(child.name))
        .map((child) => toTree(child, `${path}/${child.name}`))
        .sort((a, b) => Number(b.isFolder) - Number(a.isFolder) || a.label.localeCompare(b.label))
    : undefined;
  return {
    label: node.name,
    path,
    isFolder: node.isFolder,
    icon: node.isFolder ? 'folder' : 'description',
    ...(children && { children }),
  };
}

function find(list: TreeNode[], path: string): TreeNode | undefined {
  for (const node of list) {
    if (node.path === path) return node;
    const found = node.children && find(node.children, path);
    if (found) return found;
  }
}

/** Run a file operation, report errors, refresh and expand the folder it touched. */
async function guard(action: () => Promise<unknown>, dir?: string) {
  try {
    await action();
  } catch (e) {
    $q.notify({ type: 'negative', message: e instanceof Error ? e.message : String(e) });
  }
  await refresh();
  // new array: q-tree does not see in-place mutations
  if (dir && !expanded.value.includes(dir)) expanded.value = [...expanded.value, dir];
}

async function refresh() {
  try {
    nodes.value = [toTree(await webr.fs().lookupPath(HOME), HOME)];
    if (selected.value && !find(nodes.value, selected.value)) selected.value = null;
  } catch (e) {
    console.error(e);
  }
}

function onSelect(path: string | null) {
  const node = path ? find(nodes.value, path) : undefined;
  if (node && !node.isFolder) emit('open', node.path);
}

function create(folder: boolean) {
  $q.dialog({
    title: folder ? 'New folder' : 'New file',
    message: `In ${targetDir.value}`,
    prompt: { model: '', type: 'text' },
    cancel: true,
  }).onOk((name: string) => {
    name = name.trim();
    if (!name) return;
    const dir = targetDir.value;
    const path = `${dir}/${name}`;
    void guard(async () => {
      if (folder) await webr.fs().mkdir(path);
      else await webr.fs().writeFile(path, new Uint8Array());
      selected.value = path;
      if (!folder) emit('open', path);
    }, dir);
  });
}

function upload() {
  const files = Array.from(uploader.value?.files ?? []);
  const dir = targetDir.value;
  void guard(async () => {
    for (const file of files) {
      await webr.fs().writeFile(`${dir}/${file.name}`, new Uint8Array(await file.arrayBuffer()));
    }
  }, dir);
  // allow uploading the same file again
  if (uploader.value) uploader.value.value = '';
}

function download() {
  const node = selectedNode.value;
  if (!node) return;
  void guard(async () => {
    const data = await webr.fs().readFile(node.path);
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([data as Uint8Array<ArrayBuffer>]));
    a.download = node.label;
    a.click();
    URL.revokeObjectURL(a.href);
  });
}

async function removeNode(node: TreeNode) {
  if (!node.isFolder) return webr.fs().unlink(node.path);
  for (const child of node.children ?? []) await removeNode(child);
  await webr.fs().rmdir(node.path);
}

function remove() {
  const node = selectedNode.value;
  if (!node) return;
  $q.dialog({
    title: 'Delete',
    message: `Delete ${node.path}${node.isFolder ? ' and all its content' : ''}?`,
    cancel: true,
  }).onOk(() => {
    selected.value = null;
    void guard(() => removeNode(node));
  });
}
</script>
