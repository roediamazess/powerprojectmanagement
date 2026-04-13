<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Time Boxing</h4>
          <Button label="Refresh" :loading="loading" @click="load" />
        </div>
        <div class="card-body">
          <div class="row g-2 mb-3">
            <div class="col-md-3">
              <label class="form-label">Information Date</label>
              <Calendar v-model="informationDate" class="w-100" dateFormat="yy-mm-dd" />
            </div>
            <div class="col-md-3">
              <label class="form-label">Type</label>
              <Dropdown v-model="typeValue" :options="typeOptions" optionLabel="label" optionValue="value" class="w-100" />
            </div>
            <div class="col-md-3">
              <label class="form-label">Priority</label>
              <Dropdown v-model="priorityValue" :options="priorityOptions" optionLabel="label" optionValue="value" class="w-100" />
            </div>
            <div class="col-md-3">
              <label class="form-label">Due Date</label>
              <Calendar v-model="dueDate" class="w-100" dateFormat="yy-mm-dd" />
            </div>
            <div class="col-md-9">
              <label class="form-label">Description</label>
              <InputText v-model="description" class="w-100" />
            </div>
            <div class="col-md-3 d-flex align-items-end">
              <Button label="Create" class="w-100" :disabled="!informationDate || !typeValue || !priorityValue" @click="create" />
            </div>
          </div>

          <DataTable :value="rows" :loading="loading" stripedRows>
            <Column field="no" header="No" />
            <Column field="information_date" header="Info Date" />
            <Column field="due_date" header="Due Date" />
            <Column field="description" header="Description" />
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
import Calendar from 'primevue/calendar'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import { api } from '../lib/api'

type Row = { id: string; no: number; information_date: string; due_date: string | null; description: string | null }

const rows = ref<Row[]>([])
const loading = ref(false)
const error = ref<string | null>(null)

const informationDate = ref<Date | null>(new Date())
const dueDate = ref<Date | null>(null)
const description = ref('')

const typeOptions = [
  { label: 'Incident', value: 'INCIDENT' },
  { label: 'Request', value: 'REQUEST' },
  { label: 'Task', value: 'TASK' }
]
const priorityOptions = [
  { label: 'Low', value: 'LOW' },
  { label: 'Medium', value: 'MEDIUM' },
  { label: 'High', value: 'HIGH' },
  { label: 'Urgent', value: 'URGENT' }
]

const typeValue = ref<string | null>('INCIDENT')
const priorityValue = ref<string | null>('MEDIUM')

const formatDate = (d: Date | null) => {
  if (!d) return null
  const yyyy = d.getFullYear()
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  const dd = String(d.getDate()).padStart(2, '0')
  return `${yyyy}-${mm}-${dd}`
}

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const res = await api.get('/api/time-boxings')
    rows.value = res.data
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load time boxings'
  } finally {
    loading.value = false
  }
}

const create = async () => {
  if (!informationDate.value || !typeValue.value || !priorityValue.value) return
  loading.value = true
  error.value = null
  try {
    await api.post('/api/time-boxings', {
      information_date: formatDate(informationDate.value),
      type_value: typeValue.value,
      priority_value: priorityValue.value,
      due_date: formatDate(dueDate.value),
      description: description.value
    })
    description.value = ''
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to create time boxing'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load()
})
</script>
