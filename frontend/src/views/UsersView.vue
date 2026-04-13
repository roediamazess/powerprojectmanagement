<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">User Management</h4>
          <Button label="+ New User" @click="openCreate" />
        </div>
        <div class="card-body">
          <!-- Search -->
          <div class="row g-2 mb-3">
            <div class="col-md-4">
              <InputText v-model="search" class="w-100" placeholder="Search name or email…" @input="onSearch" />
            </div>
            <div class="col-md-2 d-flex align-items-end">
              <Button label="Refresh" :loading="loading" severity="secondary" class="w-100" @click="() => load()" />
            </div>
          </div>

          <!-- Table -->
          <DataTable :value="rows" :loading="loading" stripedRows>
            <Column field="name" header="Name" />
            <Column field="email" header="Email" />
            <Column header="Roles">
              <template #body="{ data }">
                <Tag v-for="r in data.roles" :key="r.id" :value="r.name" severity="info" class="me-1" />
                <span v-if="!data.roles.length" class="text-muted">—</span>
              </template>
            </Column>
            <Column header="Status">
              <template #body="{ data }">
                <Tag :value="data.is_active ? 'Active' : 'Inactive'" :severity="data.is_active ? 'success' : 'danger'" />
              </template>
            </Column>
            <Column header="Actions" style="width: 180px">
              <template #body="{ data }">
                <Button icon="pi pi-pencil" size="small" severity="secondary" class="me-1" @click="openEdit(data)" />
                <Button
                  :icon="data.is_active ? 'pi pi-ban' : 'pi pi-check'"
                  size="small"
                  :severity="data.is_active ? 'warning' : 'success'"
                  class="me-1"
                  @click="toggleActive(data)"
                />
                <Button icon="pi pi-trash" size="small" severity="danger" @click="removeUser(data)" />
              </template>
            </Column>
          </DataTable>

          <!-- Pagination -->
          <Paginator
            v-if="meta.total > meta.page_size"
            :rows="meta.page_size"
            :totalRecords="meta.total"
            @page="onPage"
            class="mt-2"
          />

          <div v-if="error" class="mt-3 text-danger">{{ error }}</div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Dialog -->
    <Dialog v-model:visible="showDialog" :header="editId ? 'Edit User' : 'Create User'" :modal="true" style="width: 480px">
      <div class="mb-3">
        <label class="form-label">Name *</label>
        <InputText v-model="form.name" class="w-100" />
      </div>
      <div class="mb-3">
        <label class="form-label">Email *</label>
        <InputText v-model="form.email" class="w-100" :disabled="!!editId" />
      </div>
      <div class="mb-3">
        <label class="form-label">{{ editId ? 'New Password (leave blank to keep)' : 'Password *' }}</label>
        <InputText v-model="form.password" type="password" class="w-100" />
      </div>
      <div class="mb-3">
        <label class="form-label">Roles</label>
        <MultiSelect
          v-model="form.role_ids"
          :options="allRoles"
          optionLabel="name"
          optionValue="id"
          class="w-100"
          placeholder="Select roles"
        />
      </div>
      <div v-if="dialogError" class="text-danger mb-2">{{ dialogError }}</div>
      <template #footer>
        <Button label="Cancel" severity="secondary" @click="showDialog = false" />
        <Button :label="editId ? 'Save' : 'Create'" :loading="saving" @click="submitForm" />
      </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Tag from 'primevue/tag'
import Paginator from 'primevue/paginator'
import Dialog from 'primevue/dialog'
import MultiSelect from 'primevue/multiselect'
import { api } from '../lib/api'

type RoleRef = { id: string; name: string }
type UserRow = { id: string; email: string; name: string; is_active: boolean; roles: RoleRef[] }

const rows = ref<UserRow[]>([])
const allRoles = ref<RoleRef[]>([])
const loading = ref(false)
const saving = ref(false)
const error = ref<string | null>(null)
const dialogError = ref<string | null>(null)
const search = ref('')
const meta = ref({ total: 0, page: 1, page_size: 50 })
const showDialog = ref(false)
const editId = ref<string | null>(null)

const form = ref({ name: '', email: '', password: '', role_ids: [] as string[] })

let searchTimer: ReturnType<typeof setTimeout>

const load = async (page = 1) => {
  loading.value = true
  error.value = null
  try {
    const params: Record<string, any> = { page, page_size: meta.value.page_size }
    if (search.value) params.q = search.value
    const res = await api.get('/api/users', { params })
    rows.value = res.data.data
    meta.value = res.data.meta
  } catch (e: any) {
    error.value = e?.response?.data?.error?.message || 'Failed to load users'
  } finally {
    loading.value = false
  }
}

const loadRoles = async () => {
  try {
    const res = await api.get('/api/roles')
    allRoles.value = res.data.data
  } catch {}
}

const onSearch = () => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => load(1), 400)
}

const onPage = (e: any) => load(e.page + 1)

const openCreate = () => {
  editId.value = null
  form.value = { name: '', email: '', password: '', role_ids: [] }
  dialogError.value = null
  showDialog.value = true
}

const openEdit = (row: UserRow) => {
  editId.value = row.id
  form.value = { name: row.name, email: row.email, password: '', role_ids: row.roles.map(r => r.id) }
  dialogError.value = null
  showDialog.value = true
}

const submitForm = async () => {
  saving.value = true
  dialogError.value = null
  try {
    if (editId.value) {
      const payload: any = { name: form.value.name, role_ids: form.value.role_ids }
      if (form.value.password) payload.password = form.value.password
      await api.patch(`/api/users/${editId.value}`, payload)
    } else {
      await api.post('/api/users', form.value)
    }
    showDialog.value = false
    await load(meta.value.page)
  } catch (e: any) {
    dialogError.value = e?.response?.data?.error?.message || 'Failed to save'
  } finally {
    saving.value = false
  }
}

const toggleActive = async (row: UserRow) => {
  try {
    await api.patch(`/api/users/${row.id}`, { is_active: !row.is_active })
    await load(meta.value.page)
  } catch (e: any) {
    error.value = e?.response?.data?.error?.message || 'Failed to update'
  }
}

const removeUser = async (row: UserRow) => {
  if (!confirm(`Delete user "${row.name}"?`)) return
  try {
    await api.delete(`/api/users/${row.id}`)
    await load(meta.value.page)
  } catch (e: any) {
    error.value = e?.response?.data?.error?.message || 'Failed to delete'
  }
}

onMounted(async () => {
  await Promise.all([load(), loadRoles()])
})
</script>
