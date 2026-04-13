<template>
  <div class="row">
    <!-- Stats row -->
    <div class="col-xl-3 col-sm-6" v-for="stat in stats" :key="stat.label">
      <div class="card">
        <div class="card-body d-flex align-items-center">
          <div class="me-3" :style="`background:${stat.color};padding:14px;border-radius:12px`">
            <i :class="stat.icon" style="font-size:1.4rem;color:#fff" />
          </div>
          <div>
            <div class="fs-4 fw-bold">{{ stat.value }}</div>
            <div class="text-muted small">{{ stat.label }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Surveys Table -->
    <div class="col-xl-12 mt-2">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Health Score Surveys</h4>
          <Button label="Refresh" :loading="loading" severity="secondary" @click="() => load()" />
        </div>
        <div class="card-body">
          <!-- Filters -->
          <div class="row g-2 mb-3">
            <div class="col-md-3">
              <label class="form-label">Partner</label>
              <InputText v-model="filterPartner" class="w-100" placeholder="Partner name…" @input="() => load()" />
            </div>
            <div class="col-md-2">
              <label class="form-label">Year</label>
              <Dropdown v-model="filterYear" :options="yearOptions" class="w-100" placeholder="All" showClear />
            </div>
            <div class="col-md-2">
              <label class="form-label">Quarter</label>
              <Dropdown v-model="filterQuarter" :options="[1,2,3,4]" class="w-100" placeholder="All" showClear />
            </div>
          </div>

          <DataTable :value="rows" :loading="loading" stripedRows>
            <Column header="Partner / Project">
              <template #body="{ data }">
                <div class="fw-semibold">{{ data.partner_name || '—' }}</div>
                <div class="text-muted small">{{ data.project_name || 'No project' }}</div>
              </template>
            </Column>
            <Column header="Period">
              <template #body="{ data }">Q{{ data.quarter }} {{ data.year }}</template>
            </Column>
            <Column header="Score">
              <template #body="{ data }">
                <span v-if="data.score_total !== null">
                  <span class="fw-bold fs-5" :class="scoreColor(data.score_total)">{{ data.score_total.toFixed(1) }}</span>
                  <span class="text-muted"> / 100</span>
                </span>
                <span v-else class="text-muted">—</span>
              </template>
            </Column>
            <Column header="Status">
              <template #body="{ data }">
                <Tag :value="data.status" :severity="statusSeverity(data.status)" />
              </template>
            </Column>
            <Column header="Submitted">
              <template #body="{ data }">
                {{ data.submitted_at ? new Date(data.submitted_at).toLocaleDateString() : '—' }}
              </template>
            </Column>
            <Column header="Actions" style="width:80px">
              <template #body="{ data }">
                <Button icon="pi pi-eye" size="small" severity="secondary" @click="viewSurvey(data.id)" />
              </template>
            </Column>
          </DataTable>

          <Paginator
            v-if="meta.total > meta.page_size"
            :rows="meta.page_size"
            :totalRecords="meta.total"
            @page="e => load(e.page + 1)"
            class="mt-2"
          />
          <div v-if="error" class="text-danger mt-2">{{ error }}</div>
        </div>
      </div>
    </div>

    <!-- Templates Card -->
    <div class="col-xl-12 mt-2">
      <div class="card">
        <div class="card-header"><h5 class="mb-0">Templates</h5></div>
        <div class="card-body">
          <DataTable :value="templates" stripedRows>
            <Column field="name" header="Name" />
            <Column field="status" header="Status">
              <template #body="{ data }">
                <Tag :value="data.status" :severity="data.status === 'Active' ? 'success' : 'secondary'" />
              </template>
            </Column>
            <Column field="version" header="Version" />
            <Column header="Actions" style="width:80px">
              <template #body="{ data }">
                <Button icon="pi pi-eye" size="small" severity="secondary" @click="viewTemplate(data.id)" />
              </template>
            </Column>
          </DataTable>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Tag from 'primevue/tag'
import Paginator from 'primevue/paginator'
import Dropdown from 'primevue/dropdown'
import { api } from '../lib/api'

const router = useRouter()

type Survey = {
  id: string; partner_name: string | null; project_name: string | null
  year: number; quarter: number; status: string; score_total: number | null
  submitted_at: string | null
}
type Template = { id: string; name: string; status: string; version: number }

const rows = ref<Survey[]>([])
const templates = ref<Template[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const meta = ref({ total: 0, page: 1, page_size: 20 })
const filterPartner = ref('')
const filterYear = ref<number | null>(null)
const filterQuarter = ref<number | null>(null)

const yearOptions = computed(() => {
  const y = new Date().getFullYear()
  return [y, y - 1, y - 2, y - 3]
})

const stats = computed(() => [
  { label: 'Total Surveys', value: meta.value.total, icon: 'fas fa-clipboard-list', color: '#5b8dee' },
  { label: 'Submitted', value: rows.value.filter(r => r.status === 'Submitted').length, icon: 'fas fa-check-circle', color: '#17a673' },
  { label: 'Avg Score', value: avgScore.value, icon: 'fas fa-chart-bar', color: '#f4a261' },
  { label: 'Templates', value: templates.value.length, icon: 'fas fa-layer-group', color: '#e76f51' },
])

const avgScore = computed(() => {
  const withScore = rows.value.filter(r => r.score_total !== null)
  if (!withScore.length) return '—'
  return (withScore.reduce((acc, r) => acc + (r.score_total || 0), 0) / withScore.length).toFixed(1)
})

const scoreColor = (score: number) => {
  if (score >= 80) return 'text-success'
  if (score >= 60) return 'text-warning'
  return 'text-danger'
}

const statusSeverity = (status: string) => {
  const map: Record<string, string> = { Submitted: 'success', Draft: 'secondary', InProgress: 'info' }
  return map[status] || 'secondary'
}

const load = async (page = 1) => {
  loading.value = true
  error.value = null
  try {
    const params: Record<string, any> = { page, page_size: meta.value.page_size }
    if (filterYear.value) params.year = filterYear.value
    if (filterQuarter.value) params.quarter = filterQuarter.value
    const [surveyRes, tplRes] = await Promise.all([
      api.get('/api/health-score/surveys', { params }),
      api.get('/api/health-score/templates'),
    ])
    rows.value = surveyRes.data.data
    meta.value = surveyRes.data.meta
    templates.value = tplRes.data.data
  } catch (e: any) {
    error.value = e?.response?.data?.error?.message || 'Failed to load'
  } finally {
    loading.value = false
  }
}

const viewSurvey = (id: string) => router.push(`/compliance/surveys/${id}`)
const viewTemplate = (id: string) => { /* TODO: template detail route */ }

onMounted(() => load())
</script>
