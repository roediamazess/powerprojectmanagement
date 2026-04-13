<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Arrangements</h4>
          <Button label="Refresh" :loading="loading" @click="load" />
        </div>
        <div class="card-body">
          <div class="row align-items-end g-2 mb-3">
            <div class="col-md-6">
              <label class="form-label">Create Batch</label>
              <InputText v-model="newBatchName" class="w-100" placeholder="Batch name" />
            </div>
            <div class="col-md-3">
              <Button label="Create" class="w-100" :disabled="!newBatchName" @click="createBatch" />
            </div>
          </div>

          <DataTable :value="batches" :loading="loading" stripedRows>
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

type Batch = { id: string; name: string; status_id: string }

const batches = ref<Batch[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const newBatchName = ref('')

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const res = await api.get('/api/arrangements/batches')
    batches.value = res.data
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load batches'
  } finally {
    loading.value = false
  }
}

const createBatch = async () => {
  loading.value = true
  error.value = null
  try {
    await api.post('/api/arrangements/batches', { name: newBatchName.value })
    newBatchName.value = ''
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to create batch'
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await load()
})
</script>
