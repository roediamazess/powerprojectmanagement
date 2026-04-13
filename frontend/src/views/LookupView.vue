<template>
  <div class="row">
    <div class="col-xl-4">
      <div class="card h-100">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Categories</h4>
          <Button icon="pi pi-plus" size="small" severity="secondary" @click="openCreateCat" />
        </div>
        <div class="card-body p-0">
          <div class="list-group list-group-flush border-bottom-0">
            <template v-if="loadingCategories">
              <div class="p-4 text-center"><i class="pi pi-spin pi-spinner" style="font-size: 2rem"></i></div>
            </template>
            <template v-else-if="categories.length === 0">
              <div class="p-4 text-center text-muted">No categories found</div>
            </template>
            <template v-else>
              <button
                v-for="cat in categories"
                :key="cat.id"
                class="list-group-item list-group-item-action d-flex justify-content-between align-items-center fw-semibold py-3"
                :class="{ 'active bg-primary text-white': selectedCat?.id === cat.id }"
                @click="selectedCat = cat"
              >
                {{ cat.key }}
                <span
                  class="badge rounded-pill"
                  :class="selectedCat?.id === cat.id ? 'bg-white text-primary' : 'bg-light text-dark'"
                >
                  {{ cat.values.length }}
                </span>
              </button>
            </template>
          </div>
        </div>
      </div>
    </div>

    <div class="col-xl-8">
      <div class="card h-100">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">
            <span v-if="selectedCat">Values: <span class="text-primary">{{ selectedCat.key }}</span></span>
            <span v-else class="text-muted">Select a category</span>
          </h4>
          <Button
            v-if="selectedCat"
            label="+ Add Value"
            size="small"
            @click="openCreateVal"
          />
        </div>
        <div class="card-body">
          <div v-if="!selectedCat" class="text-center text-muted py-5">
            <i class="fas fa-arrow-left fs-3 mb-3 opacity-50"></i>
            <div>Click a category on the left to manage its values.</div>
          </div>
          <div v-else>
            <DataTable :value="selectedCat.values" stripedRows>
              <Column field="sort_order" header="Order" style="width: 80px">
                <template #body="{ data }">
                  <span class="text-muted fw-bold">{{ data.sort_order }}</span>
                </template>
              </Column>
              <Column field="value" header="System Value (Key)" />
              <Column field="label" header="Display Label" />
              <Column field="is_active" header="Status">
                <template #body="{ data }">
                  <Tag :value="data.is_active ? 'Active' : 'Inactive'" :severity="data.is_active ? 'success' : 'danger'" />
                </template>
              </Column>
              <Column header="Actions" style="width: 120px">
                <template #body="{ data }">
                  <Button icon="pi pi-pencil" size="small" severity="secondary" class="me-1" @click="openEditVal(data)" />
                  <Button icon="pi pi-trash" size="small" severity="danger" @click="removeVal(data)" />
                </template>
              </Column>
              <template #empty>
                <div class="text-center py-3 text-muted">No values added yet.</div>
              </template>
            </DataTable>
          </div>
        </div>
      </div>
    </div>

    <!-- Category Dialog -->
    <Dialog v-model:visible="showCatDialog" header="New Category" :modal="true" style="width: 400px">
      <div class="mb-3">
        <label class="form-label">Category Key *</label>
        <InputText v-model="catForm.key" class="w-100" placeholder="e.g. project_status" />
        <small class="text-muted">Use snake_case. Cannot be edited later.</small>
      </div>
      <div v-if="dialogError" class="text-danger mb-3">{{ dialogError }}</div>
      <template #footer>
        <Button label="Cancel" severity="secondary" @click="showCatDialog = false" />
        <Button label="Create" :loading="saving" @click="submitCat" />
      </template>
    </Dialog>

    <!-- Value Dialog -->
    <Dialog v-model:visible="showValDialog" :header="editValId ? 'Edit Value' : 'Add Value'" :modal="true" style="width: 450px">
      <div class="mb-3">
        <label class="form-label">System Value *</label>
        <InputText v-model="valForm.value" class="w-100" placeholder="e.g. IN_PROGRESS" :disabled="!!editValId" />
      </div>
      <div class="mb-3">
        <label class="form-label">Display Label *</label>
        <InputText v-model="valForm.label" class="w-100" placeholder="e.g. In Progress" />
      </div>
      <div class="row mb-3">
        <div class="col-md-6">
          <label class="form-label">Sort Order</label>
          <InputText v-model="valForm.sort_order" type="number" class="w-100" />
        </div>
        <div class="col-md-6 d-flex align-items-end">
          <div class="form-check form-switch mb-2">
            <input class="form-check-input" type="checkbox" id="isActiveSwitch" v-model="valForm.is_active" />
            <label class="form-check-label" for="isActiveSwitch">Active</label>
          </div>
        </div>
      </div>
      <div v-if="dialogError" class="text-danger mb-3">{{ dialogError }}</div>
      <template #footer>
        <Button label="Cancel" severity="secondary" @click="showValDialog = false" />
        <Button :label="editValId ? 'Save' : 'Add'" :loading="saving" @click="submitVal" />
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
import Dialog from 'primevue/dialog'
import { api } from '../lib/api'

type LookupValue = { id: string; value: string; label: string; sort_order: number; is_active: boolean }
type LookupCategory = { id: string; key: string; values: LookupValue[] }

const categories = ref<LookupCategory[]>([])
const selectedCat = ref<LookupCategory | null>(null)
const loadingCategories = ref(false)
const saving = ref(false)
const dialogError = ref<string | null>(null)

// Dialogs
const showCatDialog = ref(false)
const catForm = ref({ key: '' })

const showValDialog = ref(false)
const editValId = ref<string | null>(null)
const valForm = ref({ value: '', label: '', sort_order: 0, is_active: true })

const load = async () => {
  loadingCategories.value = true
  try {
    const res = await api.get('/api/lookup')
    categories.value = res.data.data
    // Restore selection
    if (selectedCat.value) {
      selectedCat.value = categories.value.find(c => c.id === selectedCat.value?.id) || null
    }
  } catch (e) {
    console.error('Failed to load categories', e)
  } finally {
    loadingCategories.value = false
  }
}

onMounted(() => load())

// --- Actions: Category ---

const openCreateCat = () => {
  catForm.value = { key: '' }
  dialogError.value = null
  showCatDialog.value = true
}

const submitCat = async () => {
  if (!catForm.value.key) return
  saving.value = true
  dialogError.value = null
  try {
    const res = await api.post('/api/lookup', catForm.value)
    showCatDialog.value = false
    await load()
    selectedCat.value = categories.value.find(c => c.id === res.data.id) || null
  } catch (e: any) {
    dialogError.value = e?.response?.data?.error?.message || 'Failed to create category'
  } finally {
    saving.value = false
  }
}

// --- Actions: Values ---

const openCreateVal = () => {
  if (!selectedCat.value) return
  editValId.value = null
  const nextSort = selectedCat.value.values.length > 0 
    ? Math.max(...selectedCat.value.values.map(v => v.sort_order)) + 1 
    : 0;
  valForm.value = { value: '', label: '', sort_order: nextSort, is_active: true }
  dialogError.value = null
  showValDialog.value = true
}

const openEditVal = (val: LookupValue) => {
  editValId.value = val.id
  valForm.value = { ...val }
  dialogError.value = null
  showValDialog.value = true
}

const submitVal = async () => {
  if (!selectedCat.value) return
  saving.value = true
  dialogError.value = null
  try {
    if (editValId.value) {
      await api.patch(`/api/lookup/values/${editValId.value}`, {
        label: valForm.value.label,
        sort_order: Number(valForm.value.sort_order),
        is_active: valForm.value.is_active
      })
    } else {
      await api.post(`/api/lookup/${selectedCat.value.id}/values`, {
        ...valForm.value,
        sort_order: Number(valForm.value.sort_order)
      })
    }
    showValDialog.value = false
    await load()
  } catch (e: any) {
    dialogError.value = e?.response?.data?.error?.message || 'Failed to save value'
  } finally {
    saving.value = false
  }
}

const removeVal = async (val: LookupValue) => {
  if (!confirm(`Delete value "${val.label}"?`)) return
  try {
    await api.delete(`/api/lookup/values/${val.id}`)
    await load()
  } catch (e: any) {
    alert(e?.response?.data?.error?.message || 'Failed to delete value')
  }
}
</script>
