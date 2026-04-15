<template>
  <div class="row">
    <div class="col-12">
      <div class="card">
        <div class="card-header d-flex justify-content-between align-items-center">
          <h4 class="card-title">Holidays</h4>
          <Button label="New Holiday" icon="pi pi-plus" size="small" @click="openNew" />
        </div>
        <div class="card-body">
          <DataTable :value="holidays" :loading="loading" stripedRows paginator :rows="10">
            <Column field="date" header="Date">
              <template #body="{ data }">
                {{ new Date(data.date).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' }) }}
              </template>
            </Column>
            <Column field="name" header="Name" />
            <Column field="is_active" header="Status">
              <template #body="{ data }">
                <Tag :value="data.is_active ? 'Active' : 'Inactive'" :severity="data.is_active ? 'success' : 'danger'" />
              </template>
            </Column>
            <Column header="Actions" style="width: 120px">
              <template #body="{ data }">
                <Button icon="pi pi-pencil" size="small" severity="secondary" class="me-1" @click="openEdit(data)" />
                <Button icon="pi pi-trash" size="small" severity="danger" @click="remove(data)" />
              </template>
            </Column>
          </DataTable>
        </div>
      </div>
    </div>

    <Dialog v-model:visible="showDialog" :header="editId ? 'Edit Holiday' : 'New Holiday'" :modal="true" style="width: 400px">
      <div class="mb-3">
        <label class="form-label">Date</label>
        <InputText type="date" v-model="form.date" class="w-100" />
      </div>
      <div class="mb-3">
        <label class="form-label">Name</label>
        <InputText v-model="form.name" class="w-100" placeholder="e.g. New Year" />
      </div>
      <div class="form-check form-switch mb-3">
        <input class="form-check-input" type="checkbox" id="holidayStatus" v-model="form.is_active" />
        <label class="form-check-label" for="holidayStatus">Active</label>
      </div>
      <template #footer>
        <div class="d-flex justify-content-end gap-2 w-100">
          <Button :label="editId ? 'Save' : 'Create'" :loading="saving" @click="submit" />
          <Button label="Cancel" severity="secondary" @click="showDialog = false" />
        </div>
      </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Button from 'primevue/button'
import Tag from 'primevue/tag'
import Dialog from 'primevue/dialog'
import InputText from 'primevue/inputtext'
import { api } from '../lib/api'

const holidays = ref([])
const loading = ref(false)
const showDialog = ref(false)
const saving = ref(false)
const editId = ref<string | null>(null)
const form = ref({ name: '', date: '', is_active: true })

const load = async () => {
  loading.value = true
  try {
    const res = await api.get('/api/holidays')
    holidays.value = res.data.data
  } finally {
    loading.value = false
  }
}

const openNew = () => {
  editId.value = null
  form.value = { name: '', date: new Date().toISOString().split('T')[0], is_active: true }
  showDialog.value = true
}

const openEdit = (data: any) => {
  editId.value = data.id
  form.value = { ...data }
  showDialog.value = true
}

const submit = async () => {
  saving.value = true
  try {
    if (editId.value) {
      await api.patch(`/api/holidays/${editId.value}`, form.value)
    } else {
      await api.post('/api/holidays', form.value)
    }
    showDialog.value = false
    await load()
  } finally {
    saving.value = false
  }
}

const remove = async (data: any) => {
  if (!confirm(`Delete holiday "${data.name}"?`)) return
  await api.delete(`/api/holidays/${data.id}`)
  await load()
}

onMounted(() => load())
</script>
