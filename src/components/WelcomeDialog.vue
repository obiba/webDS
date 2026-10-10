<template>
  <q-dialog v-model="show">
    <q-card style="width: 600px; max-width: 90vw">
      <q-card-section class="text-h6">What is DataSHIELD?</q-card-section>
      <q-card-section class="q-pt-none">
        <p>
          DataSHIELD lets you analyse sensitive data held by several organisations
          <b>without the data ever leaving them</b>. From R, you send analysis commands to each data
          server. Each server runs them on its own data and sends back only aggregated,
          non-disclosive results (counts, means, model coefficients...), which are then combined
          across servers.
        </p>
        <svg
          viewBox="0 0 480 220"
          class="full-width"
          role="img"
          aria-label="DataSHIELD architecture"
        >
          <defs>
            <marker
              id="arrow"
              viewBox="0 0 10 10"
              refX="9"
              refY="5"
              markerWidth="6"
              markerHeight="6"
              orient="auto-start-reverse"
            >
              <path d="M0 0 L10 5 L0 10 Z" fill="currentColor" />
            </marker>
          </defs>
          <g fill="none" stroke="currentColor" stroke-width="1.5">
            <rect x="10" y="80" width="130" height="60" rx="6" />
            <line
              v-for="y in ys"
              :key="y"
              x1="142"
              y1="110"
              :x2="318"
              :y2="y + 27"
              marker-start="url(#arrow)"
              marker-end="url(#arrow)"
            />
          </g>
          <text x="75" y="106" text-anchor="middle" font-weight="bold" fill="currentColor">
            Analyst
          </text>
          <text x="75" y="124" text-anchor="middle" font-size="12" fill="currentColor">
            R + dsBaseClient
          </text>
          <text x="230" y="62" text-anchor="middle" font-size="11" fill="currentColor">
            R commands →
          </text>
          <text x="230" y="168" text-anchor="middle" font-size="11" fill="currentColor">
            ← aggregated results only
          </text>
          <g v-for="(y, i) in ys" :key="i">
            <rect
              x="320"
              :y="y"
              width="150"
              height="55"
              rx="6"
              fill="none"
              stroke="#007bff"
              stroke-width="1.5"
            />
            <text x="340" :y="y + 24" font-weight="bold" fill="currentColor">
              Server {{ i + 1 }}
            </text>
            <text x="340" :y="y + 42" font-size="12" fill="currentColor">Opal + dsBase</text>
            <!-- data cylinder -->
            <g fill="#007bff" fill-opacity="0.25" stroke="#007bff">
              <path :d="`M435 ${y + 15} v24 a12 5 0 0 0 24 0 v-24`" />
              <ellipse cx="447" :cy="y + 15" rx="12" ry="5" />
            </g>
          </g>
        </svg>
        <p class="q-mt-md q-mb-none">
          This playground runs the R client in your browser: the example script in the editor runs
          against the demo servers.
        </p>
      </q-card-section>
      <q-card-actions align="right">
        <q-btn
          flat
          no-caps
          color="primary"
          label="Learn more"
          href="https://wiki.datashield.org"
          target="_blank"
        />
        <q-btn flat no-caps color="primary" label="Get started" v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue';

// shown at each visit, like the playground banner
const show = ref(true);
const ys = [35, 130];
</script>
