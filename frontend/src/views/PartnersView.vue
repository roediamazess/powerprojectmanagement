<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Partners</h4>
          <Button label="Refresh" :loading="loading" @click="load" />
        </div>
        <div class="card-body">
          <div class="row g-2 mb-3">
            <div class="col-md-3">
              <label class="form-label">CNC ID</label>
              <InputText v-model="cncId" class="w-100" />
            </div>
            <div class="col-md-6">
              <label class="form-label">Name</label>
              <InputText v-model="name" class="w-100" />
            </div>
            <div class="col-md-3 d-flex align-items-end">
              <Button label="Create" class="w-100" :disabled="!cncId || !name" @click="create" />
            </div>
          </div>

          <DataTable :value="rows" :loading="loading" stripedRows>
            <Column field="cnc_id" header="CNC ID" />
            <Column field="name" header="Name" />
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
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import { api } from '../lib/api'

type PartnerRow = { id: string; cnc_id: string; name: string }

const rows = ref<PartnerRow[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const cncId = ref('')
const name = ref('')

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const res = await api.get('/api/partners')
    rows.value = res.data
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load partners'
  } finally {
    loading.value = false
  }
}

const create = async () => {
  loading.value = true
  error.value = null
  try {
    await api.post('/api/partners', { cnc_id: cncId.value, name: name.value })
    cncId.value = ''
    name.value = ''
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to create partner'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load()
})
</script>

