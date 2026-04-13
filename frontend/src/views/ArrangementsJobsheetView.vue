<template>
  <div class="row">
    <div class="col-xl-3">
      <div class="card h-100">
        <div class="card-header d-flex justify-content-between align-items-center">
          <h4 class="card-title">Jobsheet Periods</h4>
          <Button icon="pi pi-plus" size="small" severity="secondary" @click="openCreatePeriod" />
        </div>
        <div class="card-body p-0">
          <div class="list-group list-group-flush border-bottom-0">
            <template v-if="loadingPeriods">
              <div class="p-4 text-center"><i class="pi pi-spin pi-spinner fs-2"></i></div>
            </template>
            <template v-else-if="periods.length === 0">
              <div class="p-4 text-center text-muted">No periods found</div>
            </template>
            <template v-else>
              <button
                v-for="p in periods"
                :key="p.id"
                class="list-group-item list-group-item-action d-flex flex-column py-3"
                :class="{ 'active bg-primary text-white': selectedPeriod?.id === p.id }"
                @click="selectPeriod(p)"
              >
                <div class="d-flex justify-content-between w-100 fw-bold">
                  {{ p.name }}
                  <span v-if="p.is_default" class="badge bg-warning text-dark"><i class="pi pi-star-fill" style="font-size: 0.6rem"></i> Default</span>
                </div>
                <small :class="selectedPeriod?.id === p.id ? 'text-white-50' : 'text-muted'">
                  {{ p.start_date }} - {{ p.end_date }}
                </small>
              </button>
            </template>
          </div>
        </div>
      </div>
    </div>

    <div class="col-xl-9">
      <div class="card h-100">
        <div class="card-header d-flex justify-content-between align-items-center">
          <h4 class="card-title">
            <span v-if="selectedPeriod">{{ selectedPeriod.name }} Entries</span>
            <span v-else class="text-muted">Jobsheet Grid</span>
          </h4>
          <div v-if="selectedPeriod">
            <Button
              v-if="!selectedPeriod.is_default"
              label="Set Default"
              icon="pi pi-star"
              size="small"
              severity="secondary"
              class="me-2"
              @click="setDefault(selectedPeriod.id)"
            />
            <Button label="Clear Entries" icon="pi pi-eraser" size="small" severity="danger" class="me-2" @click="openClear" />
            <Button label="Upsert Entry" icon="pi pi-pencil" size="small" @click="openUpsert" />
          </div>
        </div>
        <div class="card-body">
          <div v-if="!selectedPeriod" class="text-center py-5 text-muted">
            <i class="pi pi-calendar mb-3" style="font-size: 3rem; opacity: 0.5;"></i>
            <p>Select a period from the left to view and manage Jobsheet entries.</p>
          </div>
          <div v-else-if="loadingGrid" class="text-center py-5">
            <i class="pi pi-spin pi-spinner" style="font-size: 2rem"></i>
          </div>
          <div v-else class="table-responsive">
            <table class="table table-bordered table-sm text-center align-middle" style="white-space: nowrap;">
              <thead class="table-light">
                <tr>
                  <th class="text-start position-sticky start-0 bg-light" style="min-width: 150px; z-index: 10;">User / Name</th>
                  <th v-for="d in dateHeaders" :key="d" style="width: 50px;">
                    <div class="small text-muted">{{ getDayName(d) }}</div>
                    <div>{{ getDayNumber(d) }}</div>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="users.length === 0">
                  <td :colspan="dateHeaders.length + 1" class="text-muted py-4">No Internal PICs Found</td>
                </tr>
                <tr v-for="user in users" :key="user.id">
                  <td class="text-start position-sticky start-0 bg-white fw-bold shadow-sm" style="z-index: 5;">
                    {{ user.name }}
                  </td>
                  <td v-for="d in dateHeaders" :key="d" class="p-0">
                    <!-- Overlap assignment rendering vs manual entries -->
                    <div 
                       v-if="isApprovedAssignment(user.id, d)" 
                       class="bg-success text-white w-100 h-100 d-flex align-items-center justify-content-center"
                       style="min-height: 40px;"
                    >
                      A
                    </div>
                    <div 
                       v-else-if="getManualCode(user.id, d)" 
                       class="bg-primary text-white w-100 h-100 d-flex align-items-center justify-content-center fw-bold"
                       style="min-height: 40px; cursor: pointer;"
                       @click="openUpsertSingle(user.id, d)"
                    >
                      {{ getManualCode(user.id, d) }}
                    </div>
                    <div 
                       v-else 
                       class="text-muted w-100 h-100 d-flex align-items-center justify-content-center"
                       style="min-height: 40px; cursor: pointer;"
                       @click="openUpsertSingle(user.id, d)"
                    >
                      -
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- Create Period Dialog -->
    <Dialog v-model:visible="showCreatePeriod" header="Create Period" :modal="true" style="width: 400px">
      <div class="mb-3">
        <label class="form-label">Name *</label>
        <InputText v-model="periodForm.name" class="w-100" placeholder="e.g. September 2026" />
      </div>
      <div class="mb-3">
        <label class="form-label">Start Date *</label>
        <InputText type="date" v-model="periodForm.start_date" class="w-100" />
      </div>
      <div class="mb-3">
        <label class="form-label">End Date *</label>
        <InputText type="date" v-model="periodForm.end_date" class="w-100" />
      </div>
      <div v-if="dialogError" class="text-danger mb-3">{{ dialogError }}</div>
      <template #footer>
        <Button label="Cancel" severity="secondary" @click="showCreatePeriod = false" />
        <Button label="Create" :loading="saving" @click="submitPeriod" />
      </template>
    </Dialog>

    <!-- Upsert Entry Dialog -->
    <Dialog v-model:visible="showUpsert" header="Upsert Entries" :modal="true" style="width: 450px">
      <div class="mb-3">
        <label class="form-label">User *</label>
        <select v-model="upsertForm.user_id" class="form-select w-100">
          <option v-for="u in users" :key="u.id" :value="u.id">{{ u.name }}</option>
        </select>
      </div>
      <div class="row mb-3">
        <div class="col-6">
          <label class="form-label">Start Date *</label>
          <InputText type="date" v-model="upsertForm.start_date" class="w-100" :min="selectedPeriod?.start_date" :max="selectedPeriod?.end_date" />
        </div>
        <div class="col-6">
          <label class="form-label">End Date *</label>
          <InputText type="date" v-model="upsertForm.end_date" class="w-100" :min="selectedPeriod?.start_date" :max="selectedPeriod?.end_date" />
        </div>
      </div>
      <div class="mb-3">
        <label class="form-label">Entry Code *</label>
        <InputText v-model="upsertForm.code" class="w-100" placeholder="e.g. M.TCK, D, I.TLN" />
        <small class="text-muted">Will overwrite any existing manual entries. Approved assignments cannot be overwritten.</small>
      </div>
      <div v-if="upsertError" class="text-danger mb-3">{{ upsertError }}</div>
      <template #footer>
        <Button label="Cancel" severity="secondary" @click="showUpsert = false" />
        <Button label="Save Changes" :loading="saving" @click="submitUpsert" />
      </template>
    </Dialog>

  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import InputText from 'primevue/inputtext'
import { api } from '../lib/api'

type Period = { id: string; name: string; start_date: string; end_date: string; is_default: boolean }
type User = { id: string; name: string }

const periods = ref<Period[]>([])
const loadingPeriods = ref(false)
const selectedPeriod = ref<Period | null>(null)

const users = ref<User[]>([])
const loadingGrid = ref(false)

const manualEntries = ref<any[]>([])
const approvedAssignments = ref<any[]>([])

const showCreatePeriod = ref(false)
const periodForm = ref({ name: '', start_date: '', end_date: '' })
const saving = ref(false)
const dialogError = ref('')

const showUpsert = ref(false)
const upsertForm = ref({ user_id: '', start_date: '', end_date: '', code: '' })
const upsertError = ref('')

const loadPeriods = async () => {
  loadingPeriods.value = true
  try {
    const res = await api.get('/api/arrangements/jobsheet/periods')
    periods.value = res.data.data
  } finally {
    loadingPeriods.value = false
  }
}

const loadUsers = async () => {
  try {
    const res = await api.get('/api/users?page_size=200')
    // Get active users
    users.value = res.data.data.filter((u: any) => u.is_active)
  } catch (e) {
    console.error(e)
  }
}

const selectPeriod = async (p: Period) => {
  selectedPeriod.value = p
  await loadGridData(p.id)
}

const loadGridData = async (periodId: string) => {
  loadingGrid.value = true
  try {
    const res = await api.get(`/api/arrangements/jobsheet/active-data?period_id=${periodId}`)
    const d = res.data.data
    manualEntries.value = d.manual_entries
    approvedAssignments.value = d.approved_assignments
  } finally {
    loadingGrid.value = false
  }
}

const initialize = async () => {
  await Promise.all([loadPeriods(), loadUsers()])
  const defaultP = periods.value.find(p => p.is_default) || periods.value[0]
  if (defaultP) {
    selectPeriod(defaultP)
  }
}

onMounted(() => initialize())

// Grid helpers
const dateHeaders = computed(() => {
  if (!selectedPeriod.value) return []
  const start = new Date(selectedPeriod.value.start_date)
  const end = new Date(selectedPeriod.value.end_date)
  const dates = []
  let curr = new Date(start)
  while (curr <= end) {
    dates.push(curr.toISOString().split('T')[0])
    curr.setDate(curr.getDate() + 1)
  }
  return dates
})

const getDayName = (dStr: string) => {
  return new Date(dStr).toLocaleDateString('en-US', { weekday: 'short' })
}
const getDayNumber = (dStr: string) => {
  return new Date(dStr).getDate()
}

const isApprovedAssignment = (userId: string, dateStr: string) => {
  return approvedAssignments.value.some(a => 
    a.user_id === userId && dateStr >= a.start_date && dateStr <= a.end_date
  )
}

const getManualCode = (userId: string, dateStr: string) => {
  const e = manualEntries.value.find(e => e.user_id === userId && e.work_date === dateStr)
  return e ? e.code : null
}

// Dialog actions
const openCreatePeriod = () => {
  periodForm.value = { name: '', start_date: '', end_date: '' }
  dialogError.value = ''
  showCreatePeriod.value = true
}

const submitPeriod = async () => {
  saving.value = true
  dialogError.value = ''
  try {
    await api.post('/api/arrangements/jobsheet/periods', periodForm.value)
    showCreatePeriod.value = false
    await loadPeriods()
  } catch (e: any) {
    dialogError.value = e?.response?.data?.detail || 'Failed'
  } finally {
    saving.value = false
  }
}

const setDefault = async (id: string) => {
  try {
    await api.post(`/api/arrangements/jobsheet/periods/${id}/set-default`)
    await loadPeriods()
    const p = periods.value.find(p => p.id === id)
    if (p) selectPeriod(p)
  } catch (e) {
    console.error(e)
  }
}

const openUpsert = () => {
  if (!selectedPeriod.value) return
  upsertForm.value = {
    user_id: users.value[0]?.id || '',
    start_date: selectedPeriod.value.start_date,
    end_date: selectedPeriod.value.end_date,
    code: ''
  }
  upsertError.value = ''
  showUpsert.value = true
}

const openUpsertSingle = (userId: string, dateStr: string) => {
  if (isApprovedAssignment(userId, dateStr)) {
    return // cannot edit approved assignments
  }
  upsertForm.value = {
    user_id: userId,
    start_date: dateStr,
    end_date: dateStr,
    code: getManualCode(userId, dateStr) || ''
  }
  upsertError.value = ''
  showUpsert.value = true
}

const submitUpsert = async () => {
  saving.value = true
  upsertError.value = ''
  try {
    if (!upsertForm.value.code) {
      // Clear if empty
      await api.post('/api/arrangements/jobsheet/entries/clear', {
        period_id: selectedPeriod.value!.id,
        user_id: upsertForm.value.user_id,
        start_date: upsertForm.value.start_date,
        end_date: upsertForm.value.end_date
      })
    } else {
      await api.post('/api/arrangements/jobsheet/entries/upsert', {
        period_id: selectedPeriod.value!.id,
        ...upsertForm.value
      })
    }
    showUpsert.value = false
    await loadGridData(selectedPeriod.value!.id)
  } catch (e: any) {
    upsertError.value = e?.response?.data?.detail || 'Failed to upsert entry'
  } finally {
    saving.value = false
  }
}

const openClear = () => {
  openUpsert()
  upsertForm.value.code = ''
}
</script>
