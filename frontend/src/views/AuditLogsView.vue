<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Audit Logs</h4>
          <Button label="Refresh" :loading="loading" @click="load" />
        </div>
        <div class="card-body">
          <DataTable :value="rows" :loading="loading" stripedRows>
            <Column field="created_at" header="Time" />
            <Column field="actor_email" header="Actor" />
            <Column field="action" header="Action" />
            <Column field="entity_type" header="Entity" />
            <Column field="entity_id" header="Entity ID" />
            <Column header="Meta">
              <template #body="{ data }">
                <span v-if="data.meta">{{ JSON.stringify(data.meta) }}</span>
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
  id: number
  created_at: string
  actor_user_id: string | null
  actor_name: string | null
  actor_email: string | null
  action: string
  entity_type: string
  entity_id: string | null
  meta: any
}

const rows = ref<Row[]>([])
const loading = ref(false)
const error = ref<string | null>(null)

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const res = await api.get('/api/audit-logs')
    rows.value = res.data
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load audit logs'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load()
})
</script>
