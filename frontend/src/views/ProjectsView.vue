<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Projects</h4>
          <Button label="Refresh" :loading="loading" @click="load" />
        </div>
        <div class="card-body">
          <div class="row g-2 mb-3">
            <div class="col-md-3">
              <label class="form-label">Partner</label>
              <Dropdown
                v-model="partnerId"
                :options="partners"
                optionLabel="label"
                optionValue="value"
                class="w-100"
                placeholder="Select partner"
              />
            </div>
            <div class="col-md-6">
              <label class="form-label">Name</label>
              <InputText v-model="name" class="w-100" />
            </div>
            <div class="col-md-3 d-flex align-items-end">
              <Button label="Create" class="w-100" :disabled="!partnerId || !name" @click="create" />
            </div>
          </div>

          <DataTable :value="rows" :loading="loading" stripedRows>
            <Column field="name" header="Name" />
            <Column field="partner_id" header="Partner ID" />
            <Column field="id" header="ID" />
          </DataTable>

          <div v-if="error" class="mt-3 text-danger">{{ error }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Dropdown from 'primevue/dropdown'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import { api } from '../lib/api'

type ProjectRow = { id: string; partner_id: string; name: string }
type PartnerRow = { id: string; cnc_id: string; name: string }

const rows = ref<ProjectRow[]>([])
const partners = ref<{ label: string; value: string }[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const partnerId = ref<string | null>(null)
const name = ref('')

const loadPartners = async () => {
  const res = await api.get<PartnerRow[]>('/api/partners')
  partners.value = res.data.map((p: PartnerRow) => ({ label: `${p.cnc_id} — ${p.name}`, value: p.id }))
}

const load = async () => {
  loading.value = true
  error.value = null
  try {
    await loadPartners()
    const res = await api.get('/api/projects')
    rows.value = res.data
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load projects'
  } finally {
    loading.value = false
  }
}

const create = async () => {
  if (!partnerId.value) return
  loading.value = true
  error.value = null
  try {
    await api.post('/api/projects', { partner_id: partnerId.value, name: name.value })
    name.value = ''
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to create project'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load()
})
</script>
