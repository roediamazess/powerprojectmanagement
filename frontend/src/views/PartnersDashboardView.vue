<template>
  <div class="partners-dashboard">
    <!-- Header -->
    <div class="d-flex align-items-center justify-content-between mb-4">
      <div>
        <h2 class="fw-bold text-primary mb-1">Partners Insight</h2>
        <p class="text-muted">Strategic overview and operational status of all partners</p>
      </div>
      <div class="d-flex gap-2">
        <Button icon="pi pi-refresh" label="Reload Data" :loading="loading" @click="loadDashboard" class="p-button-outlined" />
        <Button icon="pi pi-plus" label="New Partner" @click="showCreateModal = true" />
      </div>
    </div>

    <!-- KPI Cards -->
    <div class="row g-3 mb-4">
      <div v-for="kpi in kpiCards" :key="kpi.title" class="col-xl-3 col-md-6">
        <div class="card kpi-card border-0 shadow-sm h-100" :style="{ borderLeft: `4px solid ${kpi.color}` }">
          <div class="card-body d-flex align-items-center">
            <div class="kpi-icon me-3" :style="{ background: `${kpi.color}15`, color: kpi.color }">
              <i :class="kpi.icon"></i>
            </div>
            <div>
              <p class="text-muted small fw-bold text-uppercase mb-0">{{ kpi.title }}</p>
              <h3 class="fw-bold mb-0">{{ kpi.value }}</h3>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Charts Row -->
    <div class="row g-3 mb-4">
      <div class="col-xl-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <h5 class="fw-bold mb-0"><i class="pi pi-chart-pie me-2 text-primary"></i>Status Distribution</h5>
          </div>
          <div class="card-body d-flex justify-content-center align-items-center">
            <Chart type="doughnut" :data="statusChartData" :options="chartOptions" class="w-full md:w-30rem" style="max-height: 300px" />
          </div>
        </div>
      </div>
      <div class="col-xl-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <h5 class="fw-bold mb-0"><i class="pi pi-map-marker me-2 text-info"></i>Area Breakdown</h5>
          </div>
          <div class="card-body">
            <Chart type="bar" :data="areaChartData" :options="horizontalBarOptions" style="max-height: 300px" />
          </div>
        </div>
      </div>
    </div>

    <!-- Action Tables Row -->
    <div class="row g-3 mb-4">
      <div class="col-xl-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-header bg-transparent border-0 pt-3 pb-0 d-flex justify-content-between align-items-center">
            <h5 class="fw-bold mb-0 text-danger"><i class="pi pi-exclamation-triangle me-2"></i>Needs Attention</h5>
            <Badge :value="dashboardData.needs_attention?.length || 0" severity="danger"></Badge>
          </div>
          <div class="card-body p-0 mt-3">
            <DataTable :value="dashboardData.needs_attention" class="p-datatable-sm" responsiveLayout="scroll">
              <Column field="cnc_id" header="CNC ID" class="fw-bold"></Column>
              <Column field="name" header="Name"></Column>
              <Column field="last_visit" header="Last Visit">
                <template #body="slotProps">
                  <span :class="{'text-danger fw-bold': !slotProps.data.last_visit}">
                    {{ slotProps.data.last_visit ? formatDate(slotProps.data.last_visit) : 'No Data' }}
                  </span>
                </template>
              </Column>
            </DataTable>
          </div>
        </div>
      </div>
      <div class="col-xl-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-header bg-transparent border-0 pt-3 pb-0 d-flex justify-content-between align-items-center">
            <h5 class="fw-bold mb-0 text-success"><i class="pi pi-calendar-check me-2"></i>Recently Visited</h5>
            <Badge :value="dashboardData.recently_visited?.length || 0" severity="success"></Badge>
          </div>
          <div class="card-body p-0 mt-3">
            <DataTable :value="dashboardData.recently_visited" class="p-datatable-sm" responsiveLayout="scroll">
              <Column field="name" header="Name"></Column>
              <Column field="last_visit" header="Last Visit">
                <template #body="slotProps">
                   {{ formatDate(slotProps.data.last_visit) }}
                </template>
              </Column>
              <Column field="last_visit_type" header="Type">
                <template #body="slotProps">
                  <Tag :value="slotProps.data.last_visit_type" severity="info" v-if="slotProps.data.last_visit_type"/>
                </template>
              </Column>
            </DataTable>
          </div>
        </div>
      </div>
    </div>

    <!-- Main List -->
    <div class="card border-0 shadow-sm">
      <div class="card-header bg-transparent border-0 pt-3 pb-0 d-flex justify-content-between align-items-center">
        <h5 class="fw-bold mb-0">All Partners</h5>
        <div class="p-input-icon-left">
          <i class="pi pi-search" />
          <InputText v-model="searchQuery" placeholder="Search partners..." @input="debouncedSearch" />
        </div>
      </div>
      <div class="card-body">
        <DataTable 
          :value="partners" 
          :loading="loadingPartners" 
          stripedRows 
          paginator 
          :rows="10" 
          responsiveLayout="scroll"
          class="p-datatable-customers"
        >
          <Column field="cnc_id" header="CNC ID" sortable class="fw-bold"></Column>
          <Column field="name" header="Name" sortable></Column>
          <Column field="star" header="Star" sortable>
            <template #body="slotProps">
              <span v-if="slotProps.data.star" class="text-warning">
                <i class="pi pi-star-fill" v-for="i in slotProps.data.star" :key="i"></i>
              </span>
              <span v-else class="text-muted">-</span>
            </template>
          </Column>
          <Column field="area" header="Area" sortable></Column>
          <Column header="Status">
            <template #body="slotProps">
              <Tag :value="slotProps.data.status_label || 'Unknown'" :severity="getStatusSeverity(slotProps.data.status_label)" />
            </template>
          </Column>
          <Column header="Actions" class="text-end">
            <template #body>
              <Button icon="pi pi-pencil" class="p-button-text p-button-sm" />
              <Button icon="pi pi-external-link" class="p-button-text p-button-sm p-button-info" />
            </template>
          </Column>
        </DataTable>
      </div>
    </div>

    <!-- Create Modal Placeholder -->
    <Dialog v-model:visible="showCreateModal" header="Add New Partner" :modal="true" :style="{width: '450px'}">
        <div class="p-fluid">
            <div class="field mb-3">
                <label for="cncId" class="mb-2 d-block">CNC ID</label>
                <InputText id="cncId" v-model="newPartner.cnc_id" />
            </div>
            <div class="field mb-3">
                <label for="name" class="mb-2 d-block">Partner Name</label>
                <InputText id="name" v-model="newPartner.name" />
            </div>
        </div>
        <template #footer>
            <div class="d-flex justify-content-end gap-2 w-100">
                <Button label="Save" icon="pi pi-check" @click="createPartner" :loading="creatingPartner" />
                <Button label="Cancel" icon="pi pi-times" @click="showCreateModal = false" class="p-button-text"/>
            </div>
        </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Chart from 'primevue/chart'
import Badge from 'primevue/badge'
import Tag from 'primevue/tag'
import Dialog from 'primevue/dialog'
import { api } from '../lib/api'

// State
const loading = ref(false)
const loadingPartners = ref(false)
const searchQuery = ref('')
const showCreateModal = ref(false)
const creatingPartner = ref(false)
const newPartner = ref({ cnc_id: '', name: '' })

const dashboardData = ref<any>({
  kpi: {},
  status_breakdown: {},
  area_breakdown: [],
  needs_attention: [],
  recently_visited: []
})
const partners = ref<any[]>([])

// Computed
const kpiCards = computed(() => [
  { title: 'Total Partners', value: dashboardData.value.kpi.total || 0, icon: 'pi pi-users', color: '#6366F1' },
  { title: 'Active', value: dashboardData.value.kpi.active || 0, icon: 'pi pi-check-circle', color: '#22C55E' },
  { title: 'Freeze', value: dashboardData.value.kpi.freeze || 0, icon: 'pi pi-pause-circle', color: '#F59E0B' },
  { title: 'Inactive', value: dashboardData.value.kpi.inactive || 0, icon: 'pi pi-times-circle', color: '#EF4444' }
])

const statusChartData = computed(() => {
  const bd = dashboardData.value.status_breakdown || {}
  return {
    labels: Object.keys(bd),
    datasets: [
      {
        data: Object.values(bd),
        backgroundColor: ['#22C55E', '#F59E0B', '#EF4444', '#6366F1', '#8B5CF6'],
        hoverBackgroundColor: ['#16a34a', '#d97706', '#dc2626', '#4f46e5', '#7c3aed']
      }
    ]
  }
})

const areaChartData = computed(() => {
  const bd = dashboardData.value.area_breakdown || []
  return {
    labels: bd.slice(0, 10).map((i: any) => i.label),
    datasets: [
      {
        label: 'Partners',
        data: bd.slice(0, 10).map((i: any) => i.value),
        backgroundColor: '#3B82F6',
        borderRadius: 4
      }
    ]
  }
})

const chartOptions = {
  plugins: {
    legend: { position: 'bottom' }
  },
  cutout: '60%'
}

const horizontalBarOptions = {
  indexAxis: 'y',
  plugins: {
    legend: { display: false }
  },
  scales: {
    x: { grid: { display: false } },
    y: { grid: { display: false } }
  }
}

// Methods
const loadDashboard = async () => {
  loading.value = true
  try {
    const res = await api.get('/api/dashboard/partners')
    dashboardData.value = res.data.data
  } catch (e) {
    console.error('Failed to load dashboard', e)
  } finally {
    loading.value = false
  }
}

const loadPartners = async () => {
  loadingPartners.value = true
  try {
    const res = await api.get('/api/partners', { params: { q: searchQuery.value } })
    partners.value = res.data.data
  } catch (e) {
    console.error('Failed to load partners', e)
  } finally {
    loadingPartners.value = false
  }
}

const createPartner = async () => {
    creatingPartner.value = true
    try {
        await api.post('/api/partners', newPartner.value)
        showCreateModal.value = false
        newPartner.value = { cnc_id: '', name: '' }
        await loadPartners()
        await loadDashboard()
    } catch (e) {
        console.error('Failed to create partner', e)
    } finally {
        creatingPartner.value = false
    }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

const getStatusSeverity = (status: string) => {
  if (!status) return 'info'
  const s = status.toLowerCase()
  if (s.includes('active')) return 'success'
  if (s.includes('freeze')) return 'warning'
  if (s.includes('inactive')) return 'danger'
  return 'info'
}

let searchTimeout: any = null
const debouncedSearch = () => {
  if (searchTimeout) clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    void loadPartners()
  }, 300)
}

onMounted(() => {
  void loadDashboard()
  void loadPartners()
})
</script>

<style scoped>
.partners-dashboard {
  background: transparent;
}

.kpi-card {
  transition: transform 0.2s;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(10px);
}

.kpi-card:hover {
  transform: translateY(-5px);
}

.kpi-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
}

.text-primary {
  color: #6366F1 !important;
}

:deep(.p-datatable) {
  background: white;
  border-radius: 8px;
  overflow: hidden;
}

:deep(.p-datatable-thead > tr > th) {
  background: #f8fafc;
  color: #64748b;
  font-weight: 600;
  font-size: 0.875rem;
  text-transform: uppercase;
  letter-spacing: 0.025em;
  padding: 1rem;
}

:deep(.p-datatable-tbody > tr > td) {
  padding: 1rem;
}

.p-input-icon-left > i {
  color: #94a3b8;
}

:deep(.p-inputtext) {
  border-radius: 8px;
  border: 1px solid #e2e8f0;
}

:deep(.p-button) {
  border-radius: 8px;
}
</style>

