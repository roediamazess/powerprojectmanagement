<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-3">
          <div>
            <h4 class="card-title mb-0">Time Boxing</h4>
            <p v-if="meta" class="mb-0 text-muted small">
              Showing {{ (meta.page - 1) * meta.page_size + 1 }} - {{ Math.min(meta.page * meta.page_size, meta.total) }} of {{ meta.total }}
            </p>
          </div>
          <div class="d-flex gap-2">
            <Button label="New" icon="pi pi-plus" severity="success" @click="openCreate" />
            <Button label="Refresh" icon="pi pi-refresh" :loading="loading" @click="load" />
          </div>
        </div>
        <div class="card-body">
          <!-- Status Selectors -->
          <div class="row mb-3">
            <div class="col-12 d-flex gap-2 align-items-center">
              <div class="btn-group" role="group">
                <button
                  v-for="s in statusSegments"
                  :key="s.key"
                  type="button"
                  class="btn btn-sm"
                  :class="statusFilter === s.key ? 'btn-primary' : 'btn-outline-secondary'"
                  @click="setStatusFilter(s.key)"
                >
                  {{ s.label }}
                </button>
              </div>
              <small class="text-muted ms-2 d-none d-md-inline">Default view: Active Status</small>
            </div>
          </div>

          <div class="table-responsive">
            <DataTable
              :value="rows"
              :loading="loading"
              stripedRows
              class="p-datatable-sm"
              rowHover
              @row-click="onRowClick"
              style="cursor: pointer"
            >
              <Column field="no" header="ID" style="width: 70px" />
              
              <Column header="Information Date" style="min-width: 150px">
                <template #body="{ data }">
                  {{ formatDate(data.information_date) }}
                </template>
              </Column>

              <Column header="Type" style="min-width: 130px">
                <template #body="{ data }">
                  {{ getLookupLabel('time_boxing.type', data.type_id) }}
                </template>
              </Column>

              <Column header="Priority" style="min-width: 110px">
                <template #body="{ data }">
                  <span :class="getPriorityBadgeClass(data.priority_id)" class="badge">
                    {{ getLookupLabel('time_boxing.priority', data.priority_id) }}
                  </span>
                </template>
              </Column>

              <Column field="user_position" header="User & Position" style="min-width: 180px" />

              <Column header="Partner" style="min-width: 220px">
                <template #body="{ data }">
                  <div v-if="data.partner">
                    <div class="fw-bold">{{ data.partner.cnc_id }}</div>
                    <div class="text-muted small">{{ data.partner.name }}</div>
                  </div>
                  <span v-else>-</span>
                </template>
              </Column>

              <Column field="description" header="Descriptions" style="min-width: 300px">
                <template #body="{ data }">
                  <div style="white-space: pre-wrap; word-break: break-word">{{ data.description || '-' }}</div>
                </template>
              </Column>

              <Column field="action_solution" header="Action / Solution" style="min-width: 300px">
                <template #body="{ data }">
                  <div style="white-space: pre-wrap; word-break: break-word">{{ data.action_solution || '-' }}</div>
                </template>
              </Column>

              <Column header="Status" style="width: 130px">
                <template #body="{ data }">
                  <span :class="getStatusBadgeClass(data.status_id)" class="badge">
                    {{ getLookupLabel('time_boxing.status', data.status_id) }}
                  </span>
                </template>
              </Column>

              <Column header="Due Date" style="min-width: 140px">
                <template #body="{ data }">
                  {{ formatDate(data.due_date) }}
                </template>
              </Column>
            </DataTable>
          </div>

          <div v-if="error" class="mt-3 text-danger">{{ error }}</div>
        </div>
      </div>
    </div>
  </div>

  <!-- Create/Edit Modal -->
  <Dialog v-model:visible="showModal" :header="editingId ? 'Edit Time Boxing' : 'New Time Boxing'" :modal="true" style="width: 700px" class="p-fluid">
    <div class="row g-3 mt-1">
      <div class="col-md-6">
        <label class="form-label fw-bold">Information Date</label>
        <Calendar v-model="form.information_date" dateFormat="yy-mm-dd" showIcon />
      </div>
      <div class="col-md-6">
        <label class="form-label fw-bold">Due Date</label>
        <Calendar v-model="form.due_date" dateFormat="yy-mm-dd" showIcon />
      </div>

      <div class="col-md-4">
        <label class="form-label fw-bold">Type</label>
        <Dropdown v-model="form.type_value" :options="typeOptions" optionLabel="label" optionValue="value" placeholder="Select type" />
      </div>
      <div class="col-md-4">
        <label class="form-label fw-bold">Priority</label>
        <Dropdown v-model="form.priority_value" :options="priorityOptions" optionLabel="label" optionValue="value" placeholder="Select priority" />
      </div>
      <div class="col-md-4">
        <label class="form-label fw-bold">Status</label>
        <Dropdown v-model="form.status_value" :options="statusOptions" optionLabel="label" optionValue="value" placeholder="Select status" />
      </div>

      <div class="col-12">
        <label class="form-label fw-bold">User Position</label>
        <InputText v-model="form.user_position" placeholder="e.g. IT Manager, Owner, etc." />
      </div>

      <div class="col-md-6">
        <label class="form-label fw-bold">Partner</label>
        <div class="p-inputgroup">
          <InputText :value="partnerDisplay" placeholder="Select partner..." readonly @click="showPartnerPicker = true" style="cursor: pointer" />
          <Button icon="pi pi-search" @click="showPartnerPicker = true" />
          <Button v-if="form.partner_id" icon="pi pi-times" severity="secondary" @click="form.partner_id = null" />
        </div>
      </div>
      <div class="col-md-6">
        <label class="form-label fw-bold">Project</label>
        <div class="p-inputgroup">
          <InputText :value="projectDisplay" placeholder="Select project..." readonly @click="showProjectPicker = true" style="cursor: pointer" />
          <Button icon="pi pi-search" @click="showProjectPicker = true" />
          <Button v-if="form.project_id" icon="pi pi-times" severity="secondary" @click="form.project_id = null" />
        </div>
      </div>

      <div class="col-12">
        <label class="form-label fw-bold">Description</label>
        <Textarea v-model="form.description" rows="3" autoResize />
      </div>

      <div class="col-12">
        <label class="form-label fw-bold">Action / Solution</label>
        <Textarea v-model="form.action_solution" rows="3" autoResize />
      </div>
    </div>

    <template #footer>
      <div class="d-flex justify-content-end gap-2 w-100">
        <Button :label="editingId ? 'Update Record' : 'Create Record'" :loading="saving" @click="save" />
        <Button label="Discard" severity="secondary" @click="showModal = false" class="p-button-text" />
      </div>
    </template>
  </Dialog>

  <!-- Partner Picker -->
  <Dialog v-model:visible="showPartnerPicker" header="Select Partner" :modal="true" style="width: 600px">
    <div class="mb-3">
      <span class="p-input-icon-left w-100">
        <i class="pi pi-search" />
        <InputText v-model="partnerSearch" placeholder="Search partner by name or ID..." class="w-100" />
      </span>
    </div>
    <div style="max-height: 400px; overflow-y: auto">
      <ul class="list-group">
        <li
          v-for="p in filteredPartners"
          :key="p.id"
          class="list-group-item list-group-item-action border-0 px-3 py-2 rounded mb-1"
          style="cursor: pointer"
          @click="selectPartner(p)"
        >
          <div class="fw-bold">{{ p.cnc_id }} — {{ p.name }}</div>
          <small class="text-muted">{{ p.group }} | {{ p.area }}</small>
        </li>
      </ul>
    </div>
  </Dialog>

  <!-- Project Picker -->
  <Dialog v-model:visible="showProjectPicker" header="Select Project" :modal="true" style="width: 600px">
    <div class="mb-3">
      <span class="p-input-icon-left w-100">
        <i class="pi pi-search" />
        <InputText v-model="projectSearch" placeholder="Search project by name or ID..." class="w-100" />
      </span>
    </div>
    <div style="max-height: 400px; overflow-y: auto">
      <ul class="list-group">
        <li
          v-for="p in filteredProjects"
          :key="p.id"
          class="list-group-item list-group-item-action border-0 px-3 py-2 rounded mb-1"
          style="cursor: pointer"
          @click="selectProject(p)"
        >
          <div class="fw-bold">{{ p.cnc_id }} — {{ p.project_name }}</div>
          <small class="text-muted">{{ p.partner_name }}</small>
        </li>
      </ul>
    </div>
  </Dialog>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Textarea from 'primevue/textarea'
import Dropdown from 'primevue/dropdown'
import Calendar from 'primevue/calendar'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Dialog from 'primevue/dialog'
import { api } from '../lib/api'

type Meta = { total: number; page: number; page_size: number }
type Row = {
  id: string
  no: number
  information_date: string
  type_id: string
  priority_id: string
  status_id: string
  user_position: string | null
  partner_id: string | null
  partner: any | null
  project_id: string | null
  project: any | null
  description: string | null
  action_solution: string | null
  due_date: string | null
  completed_at: string | null
}

const rows = ref<Row[]>([])
const loading = ref(false)
const meta = ref<Meta | null>(null)
const error = ref<string | null>(null)
const statusFilter = ref('active')

const statusSegments = [
  { key: 'all', label: 'All Status' },
  { key: 'active', label: 'Active Status' },
  { key: 'Completed', label: 'Completed' }
]

const lookups = ref<any[]>([])
const partners = ref<any[]>([])
const projects = ref<any[]>([])

const showModal = ref(false)
const saving = ref(false)
const editingId = ref<string | null>(null)
const form = ref({
  information_date: new Date(),
  type_value: '',
  priority_value: '',
  status_value: 'Brain Dump',
  user_position: '',
  partner_id: null as string | null,
  project_id: null as string | null,
  description: '',
  action_solution: '',
  due_date: null as Date | null
})

const showPartnerPicker = ref(false)
const partnerSearch = ref('')
const showProjectPicker = ref(false)
const projectSearch = ref('')

const typeOptions = computed(() => getLookupOptions('time_boxing.type'))
const priorityOptions = computed(() => getLookupOptions('time_boxing.priority'))
const statusOptions = computed(() => getLookupOptions('time_boxing.status'))

const getLookupOptions = (key: string) => {
  const cat = lookups.value.find((c) => c.key === key)
  return (cat?.values || []).map((v: any) => ({ label: v.label, value: v.value }))
}

const getLookupLabel = (key: string, id: string) => {
  const cat = lookups.value.find((c) => c.key === key)
  const val = (cat?.values || []).find((v: any) => v.id === id)
  return val ? val.label : '-'
}

const getLookupValue = (key: string, id: string) => {
  const cat = lookups.value.find((c) => c.key === key)
  const val = (cat?.values || []).find((v: any) => v.id === id)
  return val ? val.value : ''
}

const partnerDisplay = computed(() => {
  if (!form.value.partner_id) return ''
  const p = partners.value.find((x) => x.id === form.value.partner_id)
  return p ? `${p.cnc_id} — ${p.name}` : ''
})

const projectDisplay = computed(() => {
  if (!form.value.project_id) return ''
  const p = projects.value.find((x) => x.id === form.value.project_id)
  return p ? `${p.cnc_id} — ${p.project_name}` : ''
})

const filteredPartners = computed(() => {
  const q = partnerSearch.value.toLowerCase().trim()
  if (!q) return partners.value.slice(0, 50)
  return partners.value.filter((p) => p.name.toLowerCase().includes(q) || p.cnc_id.toLowerCase().includes(q)).slice(0, 50)
})

const filteredProjects = computed(() => {
  const q = projectSearch.value.toLowerCase().trim()
  if (!q) return projects.value.slice(0, 50)
  return projects.value.filter((p) => p.project_name.toLowerCase().includes(q) || p.cnc_id.toLowerCase().includes(q)).slice(0, 50)
})

const formatDate = (iso: string | null) => {
  if (!iso) return '-'
  return iso.split('T')[0]
}

const toIsoDate = (d: Date | null) => {
  if (!d) return null
  const offset = d.getTimezoneOffset()
  const val = new Date(d.getTime() - offset * 60 * 1000)
  return val.toISOString().split('T')[0]
}

const getPriorityBadgeClass = (id: string) => {
  const val = getLookupValue('time_boxing.priority', id)
  if (val === 'Urgent') return 'bg-danger'
  if (val === 'High') return 'bg-warning'
  return 'bg-secondary'
}

const getStatusBadgeClass = (id: string) => {
  const val = getLookupValue('time_boxing.status', id)
  if (val === 'Completed') return 'bg-success'
  if (val === 'Brain Dump') return 'bg-secondary'
  return 'bg-primary'
}

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const res = await api.get('/api/time-boxings', { params: { status: statusFilter.value } })
    rows.value = res.data.data
    meta.value = res.data.meta
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load data'
  } finally {
    loading.value = false
  }
}

const setStatusFilter = (val: string) => {
  statusFilter.value = val
  void load()
}

const openCreate = () => {
  editingId.value = null
  form.value = {
    information_date: new Date(),
    type_value: typeOptions.value[0]?.value || '',
    priority_value: priorityOptions.value[0]?.value || 'Normal',
    status_value: 'Brain Dump',
    user_position: '',
    partner_id: null,
    project_id: null,
    description: '',
    action_solution: '',
    due_date: null
  }
  showModal.value = true
}

const onRowClick = (event: any) => {
  const data = event.data as Row
  editingId.value = data.id
  form.value = {
    information_date: data.information_date ? new Date(data.information_date) : new Date(),
    type_value: getLookupValue('time_boxing.type', data.type_id),
    priority_value: getLookupValue('time_boxing.priority', data.priority_id),
    status_value: getLookupValue('time_boxing.status', data.status_id),
    user_position: data.user_position || '',
    partner_id: data.partner_id,
    project_id: data.project_id,
    description: data.description || '',
    action_solution: data.action_solution || '',
    due_date: data.due_date ? new Date(data.due_date) : null
  }
  showModal.value = true
}

const selectPartner = (p: any) => {
  form.value.partner_id = p.id
  showPartnerPicker.value = false
}

const selectProject = (p: any) => {
  form.value.project_id = p.id
  showProjectPicker.value = false
}

const save = async () => {
  saving.value = true
  try {
    const payload = {
      ...form.value,
      information_date: toIsoDate(form.value.information_date),
      due_date: toIsoDate(form.value.due_date)
    }
    if (editingId.value) {
      await api.put(`/api/time-boxings/${editingId.value}`, payload)
    } else {
      await api.post('/api/time-boxings', payload)
    }
    showModal.value = false
    await load()
  } catch (e: any) {
    alert(e?.response?.data?.detail || 'Failed to save')
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  try {
    const [lRes, pRes, prRes] = await Promise.all([
      api.get('/api/lookup'),
      api.get('/api/partners'),
      api.get('/api/projects')
    ])
    lookups.value = lRes.data.data
    partners.value = pRes.data.data
    projects.value = prRes.data.data
    void load()
  } catch {}
})
</script>

<style scoped>
.badge {
  font-weight: 500;
  padding: 0.5em 0.8em;
}
</style>
