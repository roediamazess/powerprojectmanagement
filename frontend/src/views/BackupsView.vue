<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Backups</h4>
          <div class="d-flex gap-2">
            <Button label="Run Backup" :loading="running" @click="runBackup" />
            <Button label="Refresh" :loading="loading" severity="secondary" @click="load" />
          </div>
        </div>
        <div class="card-body">
          <DataTable :value="rows" :loading="loading" stripedRows>
            <Column field="created_at" header="Created" />
            <Column field="status" header="Status" />
            <Column field="started_at" header="Started" />
            <Column field="finished_at" header="Finished" />
            <Column header="File">
              <template #body="{ data }">
                <a v-if="data.status === 'SUCCEEDED'" :href="`/api/backups/${data.id}/download`" target="_blank" rel="noreferrer">
                  Download
                </a>
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
import { onMounted, ref } from 'vue'
import Button from 'primevue/button'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import { api } from '../lib/api'

type Row = {
  id: string
  status: string
  created_at: string
  started_at: string | null
  finished_at: string | null
  error: string | null
}

const rows = ref<Row[]>([])
const loading = ref(false)
const running = ref(false)
const error = ref<string | null>(null)

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const res = await api.get('/api/backups')
    rows.value = res.data
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load backups'
  } finally {
    loading.value = false
  }
}

const runBackup = async () => {
  running.value = true
  error.value = null
  try {
    await api.post('/api/backups/run')
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to run backup'
  } finally {
    running.value = false
  }
}

onMounted(() => {
  void load()
})
</script>
