<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Projects</h4>
          <div class="d-flex gap-2">
            <RouterLink to="/tables/project-setup" class="btn btn-outline-primary btn-sm">Project Setup</RouterLink>
            <Button label="Refresh" :loading="loading" @click="load" />
          </div>
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
            <div class="col-md-3">
              <label class="form-label">Type</label>
              <Dropdown
                v-model="typeId"
                :options="projectTypeOptions"
                optionLabel="label"
                optionValue="id"
                class="w-100"
                placeholder="Select type"
                showClear
                filter
              />
            </div>
            <div class="col-md-3">
              <label class="form-label">Status</label>
              <Dropdown
                v-model="statusId"
                :options="projectStatusOptions"
                optionLabel="label"
                optionValue="id"
                class="w-100"
                placeholder="Select status"
                showClear
                filter
              />
            </div>
            <div class="col-md-3">
              <label class="form-label">Name</label>
              <InputText v-model="name" class="w-100" />
            </div>
            <div class="col-md-12 d-flex align-items-end justify-content-end">
              <Button label="Create" class="w-100" :disabled="!partnerId || !name" @click="create" />
            </div>
          </div>

          <DataTable :value="rows" :loading="loading" stripedRows>
            <Column field="name" header="Name" />
            <Column field="partner_name" header="Partner" />
            <Column field="type_label" header="Type" />
            <Column field="status_label" header="Status" />
            <Column header="Actions" style="width: 120px">
              <template #body="{ data }">
                <Button icon="pi pi-pencil" size="small" severity="secondary" @click="openEdit(data)" />
              </template>
            </Column>
          </DataTable>

          <div v-if="error" class="mt-3 text-danger">{{ error }}</div>
        </div>
      </div>
    </div>
  </div>

  <Dialog v-model:visible="showEdit" header="Edit Project" :modal="true" style="width: 520px">
    <div class="mb-3">
      <label class="form-label">Partner</label>
      <Dropdown
        v-model="editForm.partner_id"
        :options="partners"
        optionLabel="label"
        optionValue="value"
        class="w-100"
        placeholder="Select partner"
        filter
      />
    </div>
    <div class="mb-3">
      <label class="form-label">Name</label>
      <InputText v-model="editForm.name" class="w-100" />
    </div>
    <div class="mb-3">
      <label class="form-label">Type</label>
      <Dropdown
        v-model="editForm.type_id"
        :options="projectTypeOptions"
        optionLabel="label"
        optionValue="id"
        class="w-100"
        placeholder="Select type"
        showClear
        filter
      />
    </div>
    <div class="mb-2">
      <label class="form-label">Status</label>
      <Dropdown
        v-model="editForm.status_id"
        :options="projectStatusOptions"
        optionLabel="label"
        optionValue="id"
        class="w-100"
        placeholder="Select status"
        showClear
        filter
      />
    </div>
    <div v-if="editError" class="text-danger mt-2">{{ editError }}</div>
    <template #footer>
      <div class="d-flex justify-content-end gap-2 w-100">
        <Button label="Save" :loading="saving" @click="saveEdit" />
        <Button label="Cancel" severity="secondary" @click="showEdit = false" />
      </div>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Dropdown from 'primevue/dropdown'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Dialog from 'primevue/dialog'
import { api } from '../lib/api'

type ProjectRow = {
  id: string
  partner_id: string
  partner_name: string
  name: string
  type_id: string | null
  type_label: string | null
  status_id: string | null
  status_label: string | null
}

const rows = ref<ProjectRow[]>([])
const partners = ref<{ label: string; value: string }[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const partnerId = ref<string | null>(null)
const typeId = ref<string | null>(null)
const statusId = ref<string | null>(null)
const name = ref('')

type LookupOption = { id: string; label: string }
const projectTypeOptions = ref<LookupOption[]>([])
const projectStatusOptions = ref<LookupOption[]>([])

const showEdit = ref(false)
const saving = ref(false)
const editError = ref<string | null>(null)
const editForm = ref<{ id: string; partner_id: string | null; name: string; type_id: string | null; status_id: string | null }>({
  id: '',
  partner_id: null,
  name: '',
  type_id: null,
  status_id: null
})

const loadPartners = async () => {
  const res = await api.get('/api/partners') as any
  partners.value = res.data.data.map((p: any) => ({ label: `${p.cnc_id} — ${p.name}`, value: p.id }))
}

const loadLookups = async () => {
  const res = await api.get('/api/lookup') as any
  const data = res.data.data as any[]
  projectTypeOptions.value = (data.find((c: any) => c.key === 'project.type')?.values || []).map((v: any) => ({ id: v.id, label: v.label }))
  projectStatusOptions.value = (data.find((c: any) => c.key === 'project.status')?.values || []).map((v: any) => ({ id: v.id, label: v.label }))
}

const load = async () => {
  loading.value = true
  error.value = null
  try {
    await loadPartners()
    await loadLookups()
    const res = await api.get('/api/projects')
    rows.value = res.data.data
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
    await api.post('/api/projects', { partner_id: partnerId.value, name: name.value, type_id: typeId.value, status_id: statusId.value })
    name.value = ''
    typeId.value = null
    statusId.value = null
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to create project'
  } finally {
    loading.value = false
  }
}

const openEdit = async (row: ProjectRow) => {
  editError.value = null
  try {
    const res = await api.get(`/api/projects/${row.id}`) as any
    const data = res.data
    editForm.value = {
      id: data.id,
      partner_id: data.partner_id,
      name: data.name,
      type_id: data.type_id,
      status_id: data.status_id
    }
    showEdit.value = true
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load project'
  }
}

const saveEdit = async () => {
  if (!editForm.value.id) return
  saving.value = true
  editError.value = null
  try {
    await api.put(`/api/projects/${editForm.value.id}`, {
      partner_id: editForm.value.partner_id,
      name: editForm.value.name,
      type_id: editForm.value.type_id,
      status_id: editForm.value.status_id
    })
    showEdit.value = false
    await load()
  } catch (e: any) {
    editError.value = e?.response?.data?.detail || 'Failed to save project'
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  void load()
})
</script>
