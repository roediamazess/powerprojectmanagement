<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Roles &amp; Permissions</h4>
          <Button label="+ New Role" @click="openCreate" />
        </div>
        <div class="card-body">
          <div class="row">
            <!-- Left: Roles list -->
            <div class="col-md-4 border-end">
              <div class="mb-2 fw-semibold text-muted small">ROLES</div>
              <div
                v-for="r in roles"
                :key="r.id"
                class="p-2 rounded mb-1 cursor-pointer"
                :class="selectedRole?.id === r.id ? 'bg-primary text-white' : 'bg-light'"
                style="cursor: pointer"
                @click="selectRole(r)"
              >
                <div class="fw-semibold">{{ r.name }}</div>
                <div class="small opacity-75">{{ r.permissions.length }} permissions</div>
              </div>
              <div v-if="!roles.length && !loading" class="text-muted small">No roles yet.</div>
            </div>

            <!-- Right: Role detail -->
            <div class="col-md-8 ps-4">
              <div v-if="!selectedRole" class="text-muted mt-4">← Select a role to manage permissions</div>
              <div v-else>
                <div class="d-flex align-items-center justify-content-between mb-3">
                  <h5 class="mb-0">{{ selectedRole.name }}</h5>
                  <div>
                    <Button icon="pi pi-pencil" size="small" severity="secondary" class="me-1" @click="openEdit(selectedRole)" />
                    <Button icon="pi pi-trash" size="small" severity="danger" @click="removeRole(selectedRole)" />
                  </div>
                </div>
                <div class="mb-2 fw-semibold text-muted small">PERMISSIONS</div>
                <div class="row g-2">
                  <div v-for="p in allPermissions" :key="p.id" class="col-md-6">
                    <div class="form-check">
                      <input
                        class="form-check-input"
                        type="checkbox"
                        :id="`perm-${p.id}`"
                        :checked="selectedRole.permissions.some(x => x.id === p.id)"
                        @change="togglePermission(p)"
                      />
                      <label class="form-check-label" :for="`perm-${p.id}`">
                        <span class="fw-semibold">{{ p.key }}</span>
                        <div v-if="p.description" class="text-muted small">{{ p.description }}</div>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div v-if="error" class="mt-3 text-danger">{{ error }}</div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Dialog -->
    <Dialog v-model:visible="showDialog" :header="editingRole ? 'Edit Role' : 'Create Role'" :modal="true" style="width: 400px">
      <div class="mb-3">
        <label class="form-label">Role Name *</label>
        <InputText v-model="form.name" class="w-100" />
      </div>
      <div v-if="dialogError" class="text-danger mb-2">{{ dialogError }}</div>
      <template #footer>
        <div class="d-flex justify-content-end gap-2 w-100">
          <Button :label="editingRole ? 'Save' : 'Create'" :loading="saving" @click="submitForm" />
          <Button label="Cancel" severity="secondary" @click="showDialog = false" />
        </div>
      </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Dialog from 'primevue/dialog'
import { api } from '../lib/api'

type PermRef = { id: string; key: string; description: string | null }
type RoleRow = { id: string; name: string; permissions: PermRef[] }

const roles = ref<RoleRow[]>([])
const allPermissions = ref<PermRef[]>([])
const selectedRole = ref<RoleRow | null>(null)
const loading = ref(false)
const saving = ref(false)
const error = ref<string | null>(null)
const dialogError = ref<string | null>(null)
const showDialog = ref(false)
const editingRole = ref<RoleRow | null>(null)
const form = ref({ name: '' })

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const [rolesRes, permsRes] = await Promise.all([
      api.get('/api/roles'),
      api.get('/api/permissions'),
    ])
    roles.value = rolesRes.data.data
    allPermissions.value = permsRes.data.data
    // Re-sync selectedRole
    if (selectedRole.value) {
      selectedRole.value = roles.value.find(r => r.id === selectedRole.value?.id) || null
    }
  } catch (e: any) {
    error.value = e?.response?.data?.error?.message || 'Failed to load'
  } finally {
    loading.value = false
  }
}

const selectRole = (r: RoleRow) => { selectedRole.value = r }

const togglePermission = async (p: PermRef) => {
  if (!selectedRole.value) return
  const current = selectedRole.value.permissions.map(x => x.id)
  const has = current.includes(p.id)
  const newIds = has ? current.filter(id => id !== p.id) : [...current, p.id]
  try {
    await api.patch(`/api/roles/${selectedRole.value.id}`, { permission_ids: newIds })
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.error?.message || 'Failed to update'
  }
}

const openCreate = () => {
  editingRole.value = null
  form.value = { name: '' }
  dialogError.value = null
  showDialog.value = true
}

const openEdit = (r: RoleRow) => {
  editingRole.value = r
  form.value = { name: r.name }
  dialogError.value = null
  showDialog.value = true
}

const submitForm = async () => {
  saving.value = true
  dialogError.value = null
  try {
    if (editingRole.value) {
      await api.patch(`/api/roles/${editingRole.value.id}`, { name: form.value.name })
    } else {
      await api.post('/api/roles', { name: form.value.name, permission_ids: [] })
    }
    showDialog.value = false
    await load()
  } catch (e: any) {
    dialogError.value = e?.response?.data?.error?.message || 'Failed to save'
  } finally {
    saving.value = false
  }
}

const removeRole = async (r: RoleRow) => {
  if (!confirm(`Delete role "${r.name}"?`)) return
  try {
    await api.delete(`/api/roles/${r.id}`)
    if (selectedRole.value?.id === r.id) selectedRole.value = null
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.error?.message || 'Failed to delete'
  }
}

onMounted(() => load())
</script>
