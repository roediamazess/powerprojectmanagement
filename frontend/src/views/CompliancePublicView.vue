<template>
  <div class="ppm-landing min-h-screen antialiased selection:bg-brand-purple selection:text-white">
    <div class="fixed inset-0 z-[-1] overflow-hidden pointer-events-none">
      <div class="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] rounded-full bg-brand-purple/10 blur-[100px] animate-blob"></div>
      <div
        class="absolute top-[20%] right-[-10%] w-[30%] h-[40%] rounded-full bg-brand-pink/10 blur-[100px] animate-blob"
        style="animation-delay: 2s;"
      ></div>
      <div
        class="absolute bottom-[-20%] left-[20%] w-[50%] h-[50%] rounded-full bg-brand-orange/10 blur-[100px] animate-blob"
        style="animation-delay: 4s;"
      ></div>
    </div>

    <nav class="fixed w-full z-50 glass-nav transition-all duration-300">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-20">
          <div class="flex items-center gap-3">
            <img :src="logoUrl" alt="Power Pro Logo" class="w-10 h-10 flex-shrink-0" />
            <div>
              <div class="text-sm font-semibold">Power Project Management</div>
              <div class="text-xs text-slate-500">Compliance Report</div>
            </div>
          </div>
          <RouterLink to="/login" class="glow-button px-4 py-2 rounded-lg bg-brand-purple text-white font-bold text-sm">
            Login
          </RouterLink>
        </div>
      </div>
    </nav>

    <div class="mx-auto max-w-7xl px-4 pt-28 pb-10">
      <div class="mb-6">
        <div
          class="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-purple-200 bg-purple-50 text-sm text-brand-purple font-medium shadow-sm animate-fade-in-up"
        >
          <span class="flex h-2 w-2 rounded-full bg-brand-purple animate-pulse"></span>
          Public Compliance Report
        </div>
        <h1 class="mt-4 text-3xl md:text-4xl font-extrabold tracking-tight">
          {{ data?.template?.name || 'Compliance Survey' }}
        </h1>
        <div class="mt-2 text-sm text-slate-600 flex flex-wrap gap-x-2 gap-y-1 items-center">
          <span>{{ data?.partner_name || '—' }} <span v-if="data?.project_name">/ {{ data?.project_name }}</span></span>
          <span class="mx-2">•</span>
          <span>Year {{ data?.year }} — Q{{ data?.quarter }}</span>
          <span class="mx-2">•</span>
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full border text-xs font-semibold" :class="statusPillClass">
            {{ statusText }}
          </span>
        </div>
      </div>

      <div v-if="error" class="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
        {{ error }}
      </div>

      <div v-else class="grid gap-6 lg:grid-cols-3">
        <div class="glass-card rounded-2xl p-6">
          <div class="text-xs font-semibold text-slate-500">Total Score</div>
          <div class="mt-3 flex items-end gap-2">
            <div class="text-5xl font-extrabold text-gradient leading-none">{{ scoreText }}</div>
            <div class="text-sm text-slate-400 pb-1">/ 100</div>
          </div>
          <div class="mt-2 text-sm text-slate-500">Overall compliance score for this period.</div>
        </div>

        <div class="glass-card rounded-2xl p-6 lg:col-span-2">
          <div class="flex items-center justify-between">
            <div class="text-xs font-semibold text-slate-500">Category Scores</div>
          </div>
          <div v-if="categoryRows.length" class="mt-4 space-y-3">
            <div v-for="row in categoryRows" :key="row.name" class="flex items-center justify-between rounded-xl bg-white/70 border border-slate-100 p-4">
              <div class="font-semibold text-slate-800">{{ row.name }}</div>
              <div class="font-bold text-slate-700">{{ row.score.toFixed(2) }}</div>
            </div>
          </div>
          <div v-else class="mt-4 text-sm text-slate-500">No category scores yet.</div>
        </div>

        <div class="glass-card rounded-2xl p-6 lg:col-span-3">
          <div class="text-xs font-semibold text-slate-500">Module Scores</div>
          <div v-if="moduleRows.length" class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <div v-for="row in moduleRows" :key="row.name" class="flex items-center justify-between rounded-xl bg-white/70 border border-slate-100 p-4">
              <div class="font-semibold text-slate-800">{{ row.name }}</div>
              <div class="font-bold text-slate-700">{{ row.score.toFixed(2) }}</div>
            </div>
          </div>
          <div v-else class="mt-4 text-sm text-slate-500">No module scores yet.</div>
        </div>
      </div>

      <div class="mt-10 text-center text-xs text-slate-500">© 2026 — Where Insights Drive Action</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { api } from '../lib/api'

const route = useRoute()
const token = computed(() => String(route.params.token))

const logoUrl = '/images/power-pro-logo-plain.png?v=20260326'
const error = ref<string | null>(null)
const data = ref<any>(null)

const scoreText = computed(() => (data.value?.score_total == null ? '—' : Number(data.value.score_total).toFixed(2)))
const statusText = computed(() => String(data.value?.status || '—'))
const statusPillClass = computed(() => {
  const s = String(data.value?.status || '').toLowerCase()
  if (s === 'submitted') return 'bg-emerald-50 border-emerald-200 text-emerald-700'
  if (s === 'draft') return 'bg-amber-50 border-amber-200 text-amber-700'
  return 'bg-slate-50 border-slate-200 text-slate-600'
})

const categoryRows = computed(() => {
  const obj = data.value?.score_by_category
  if (!obj) return []
  return Object.keys(obj).map((k) => ({ name: k, score: Number(obj[k]) }))
})

const moduleRows = computed(() => {
  const obj = data.value?.score_by_module
  if (!obj) return []
  return Object.keys(obj).map((k) => ({ name: k, score: Number(obj[k]) }))
})

const load = async () => {
  error.value = null
  try {
    const res = await api.get(`/api/compliance/public/${token.value}`)
    data.value = res.data
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Link not found'
  }
}

onMounted(() => {
  void load()
})
</script>
