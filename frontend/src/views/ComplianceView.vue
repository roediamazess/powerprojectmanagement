<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Compliance</h4>
          <Button label="Refresh" :loading="loading" @click="load" />
        </div>
        <div class="card-body">
          <div class="mb-4">
            <div class="d-flex align-items-center justify-content-between mb-2">
              <div class="fw-semibold">Trend (Avg Score)</div>
              <div class="text-muted">{{ trendPoints.length ? `Last ${trendPoints.length} quarters` : 'No data' }}</div>
            </div>
            <div class="rounded border p-3 bg-white">
              <div v-if="loadingTrends" class="text-muted">Loading trend…</div>
              <svg v-else-if="trendPoints.length" viewBox="0 0 1000 200" width="100%" height="140" preserveAspectRatio="none">
                <line x1="0" y1="160" x2="1000" y2="160" stroke="#e2e8f0" stroke-width="2" />
                <line x1="0" y1="110" x2="1000" y2="110" stroke="#f1f5f9" stroke-width="2" />
                <line x1="0" y1="60" x2="1000" y2="60" stroke="#f1f5f9" stroke-width="2" />
                <polyline
                  v-for="(seg, idx) in trendPolylineSegments"
                  :key="idx"
                  :points="seg"
                  fill="none"
                  stroke="#8b5cf6"
                  stroke-width="4"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
                <g v-for="(p, idx) in trendChartPoints" :key="p.key">
                  <circle :cx="p.x" :cy="p.y" r="6" :fill="p.hasScore ? '#8b5cf6' : '#cbd5e1'">
                    <title>{{ trendPointTitle(idx) }}</title>
                  </circle>
                </g>
              </svg>
              <div v-else class="text-muted">No trend data yet.</div>

              <div v-if="trendPoints.length" class="d-flex justify-content-between mt-2 text-muted" style="font-size: 12px">
                <span v-for="p in trendPoints" :key="p.label">{{ p.label }}</span>
              </div>
            </div>
          </div>

          <div class="row g-2 mb-4">
            <div class="col-md-2">
              <label class="form-label">Summary Year</label>
              <InputText v-model="summaryYear" class="w-100" />
            </div>
            <div class="col-md-2">
              <label class="form-label">Summary Q</label>
              <Dropdown v-model="summaryQuarter" :options="quarterOptionsAll" optionLabel="label" optionValue="value" class="w-100" />
            </div>
            <div class="col-md-3 d-flex align-items-end">
              <Button label="Load Summary" class="w-100" severity="secondary" :loading="loadingSummary" @click="loadSummary" />
            </div>
            <div class="col-md-5 d-flex align-items-end justify-content-end">
              <div class="text-muted">
                Total: <strong>{{ summaryStats.count }}</strong>
                <span class="mx-2">|</span>
                Submitted: <strong>{{ summaryStats.submitted }}</strong>
                <span class="mx-2">|</span>
                Draft: <strong>{{ summaryStats.draft }}</strong>
                <span class="mx-2">|</span>
                Avg: <strong>{{ summaryStats.avg_score ?? '—' }}</strong>
              </div>
            </div>
          </div>

          <DataTable :value="summaryRows" :loading="loadingSummary" stripedRows class="mb-4">
            <Column field="partner_name" header="Partner" />
            <Column field="project_name" header="Project" />
            <Column field="year" header="Year" />
            <Column field="quarter" header="Q" />
            <Column field="status" header="Status" />
            <Column field="score_total" header="Score" />
          </DataTable>

          <div class="row g-2 mb-3">
            <div class="col-md-3">
              <label class="form-label">Template</label>
              <Dropdown
                v-model="templateId"
                :options="templates"
                optionLabel="label"
                optionValue="value"
                class="w-100"
                placeholder="Select template"
              />
            </div>
            <div class="col-md-3">
              <label class="form-label">Partner</label>
              <Dropdown
                v-model="partnerId"
                :options="partners"
                optionLabel="label"
                optionValue="value"
                class="w-100"
                placeholder="Select partner"
                showClear
              />
            </div>
            <div class="col-md-3">
              <label class="form-label">Project</label>
              <Dropdown
                v-model="projectId"
                :options="projects"
                optionLabel="label"
                optionValue="value"
                class="w-100"
                placeholder="Select project"
                showClear
              />
            </div>
            <div class="col-md-2">
              <label class="form-label">Year</label>
              <InputText v-model="year" class="w-100" />
            </div>
            <div class="col-md-1">
              <label class="form-label">Q</label>
              <Dropdown v-model="quarter" :options="quarterOptions" optionLabel="label" optionValue="value" class="w-100" />
            </div>
            <div class="col-md-3 d-flex align-items-end">
              <Button label="Create Survey" class="w-100" :disabled="!templateId" @click="createSurvey" />
            </div>
          </div>

          <DataTable :value="surveys" :loading="loading" stripedRows>
            <Column field="template_name" header="Template" />
            <Column field="partner_name" header="Partner" />
            <Column field="project_name" header="Project" />
            <Column field="year" header="Year" />
            <Column field="quarter" header="Q" />
            <Column field="status" header="Status" />
            <Column header="Open">
              <template #body="{ data }">
                <RouterLink :to="`/compliance/surveys/${data.id}`">Open</RouterLink>
              </template>
            </Column>
            <Column header="Share">
              <template #body="{ data }">
                <a v-if="data.share_token" :href="sharePageUrl(data.share_token)" target="_blank" rel="noreferrer">Link</a>
              </template>
            </Column>
          </DataTable>

          <div v-if="error" class="mt-3 text-danger">{{ error }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import Button from 'primevue/button'
import Dropdown from 'primevue/dropdown'
import InputText from 'primevue/inputtext'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import { api } from '../lib/api'

type TemplateRow = { id: string; name: string; version: number; status: string }
type SurveyRow = {
  id: string
  template_name: string
  partner_name: string | null
  project_name: string | null
  year: number
  quarter: number
  status: string
  share_token: string | null
}
type PartnerRow = { id: string; cnc_id: string; name: string }
type ProjectRow = { id: string; partner_id: string; name: string }

const loading = ref(false)
const error = ref<string | null>(null)

const templates = ref<{ label: string; value: string }[]>([])
const partners = ref<{ label: string; value: string }[]>([])
const projects = ref<{ label: string; value: string }[]>([])
const surveys = ref<SurveyRow[]>([])

type TrendPoint = { year: number; quarter: number; label: string; count: number; avg_score: number | null }
const loadingTrends = ref(false)
const trendPoints = ref<TrendPoint[]>([])

const loadingSummary = ref(false)
const summaryRows = ref<any[]>([])
const summaryYear = ref(String(new Date().getFullYear()))
const summaryQuarter = ref<number | null>(null)
const summaryStats = ref<{ count: number; avg_score: number | null; submitted: number; draft: number }>({
  count: 0,
  avg_score: null,
  submitted: 0,
  draft: 0
})

const templateId = ref<string | null>(null)
const partnerId = ref<string | null>(null)
const projectId = ref<string | null>(null)
const year = ref(String(new Date().getFullYear()))
const quarter = ref<number>(Math.floor(new Date().getMonth() / 3) + 1)

const quarterOptions = [
  { label: '1', value: 1 },
  { label: '2', value: 2 },
  { label: '3', value: 3 },
  { label: '4', value: 4 }
]

const quarterOptionsAll = [{ label: 'All', value: null }, ...quarterOptions]

const sharePageUrl = (token: string) => `${window.location.origin}/compliance/public/${token}`

const loadTrends = async () => {
  loadingTrends.value = true
  try {
    const res = await api.get('/api/compliance/trends', { params: { limit: 8 } })
    trendPoints.value = res.data.points || []
  } finally {
    loadingTrends.value = false
  }
}

const trendPointTitle = (idx: number) => {
  const p = trendPoints.value[idx]
  if (!p) return ''
  const score = p.avg_score == null ? '—' : Number(p.avg_score).toFixed(2)
  return `${p.label}: ${score} (n=${p.count})`
}

const trendChartPoints = computed(() => {
  const pts = trendPoints.value
  if (!pts.length) return []
  const w = 1000
  const minY = 40
  const maxY = 160
  const step = pts.length === 1 ? 0 : w / (pts.length - 1)

  return pts.map((p, idx) => {
    const hasScore = p.avg_score != null
    const score = hasScore ? Number(p.avg_score) : 0
    const y = maxY - ((score / 100) * (maxY - minY))
    return { key: `${p.year}-${p.quarter}`, x: idx * step, y, hasScore }
  })
})

const trendPolylineSegments = computed(() => {
  const pts = trendPoints.value
  if (!pts.length) return []
  const w = 1000
  const minY = 40
  const maxY = 160
  const step = pts.length === 1 ? 0 : w / (pts.length - 1)

  const segments: string[] = []
  let current: string[] = []

  for (let idx = 0; idx < pts.length; idx++) {
    const p = pts[idx]
    if (p.avg_score == null) {
      if (current.length >= 2) segments.push(current.join(' '))
      current = []
      continue
    }
    const score = Number(p.avg_score)
    const x = idx * step
    const y = maxY - ((score / 100) * (maxY - minY))
    current.push(`${x},${y}`)
  }

  if (current.length >= 2) segments.push(current.join(' '))
  return segments
})

const loadSummary = async () => {
  loadingSummary.value = true
  try {
    const params: any = {}
    if (summaryYear.value) params.year = Number(summaryYear.value)
    if (summaryQuarter.value) params.quarter = summaryQuarter.value
    const res = await api.get('/api/compliance/summary', { params })
    summaryRows.value = res.data.rows
    summaryStats.value = res.data.stats
  } finally {
    loadingSummary.value = false
  }
}

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const [t, p, pr, s] = await Promise.all([
      api.get<TemplateRow[]>('/api/compliance/templates'),
      api.get<PartnerRow[]>('/api/partners'),
      api.get<ProjectRow[]>('/api/projects'),
      api.get<SurveyRow[]>('/api/compliance/surveys')
    ])

    templates.value = t.data.map((x: TemplateRow) => ({ label: `${x.name} (v${x.version})`, value: x.id }))
    partners.value = p.data.map((x: PartnerRow) => ({ label: `${x.cnc_id} — ${x.name}`, value: x.id }))
    projects.value = pr.data.map((x: ProjectRow) => ({ label: x.name, value: x.id }))
    surveys.value = s.data

    if (!templateId.value && templates.value.length) {
      templateId.value = templates.value[0].value
    }

    await Promise.all([loadTrends().catch(() => {}), loadSummary().catch(() => {})])
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load compliance data'
  } finally {
    loading.value = false
  }
}

const createSurvey = async () => {
  if (!templateId.value) return
  loading.value = true
  error.value = null
  try {
    await api.post('/api/compliance/surveys', {
      template_id: templateId.value,
      partner_id: partnerId.value,
      project_id: projectId.value,
      year: Number(year.value),
      quarter: quarter.value
    })
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to create survey'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load()
})
</script>
