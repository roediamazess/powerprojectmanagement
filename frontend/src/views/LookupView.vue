<template>
  <div class="row">
    <div class="col-xl-4">
      <div class="card h-100">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">{{ pageTitle }}</h4>
          <Button v-if="!isRestricted" icon="pi pi-plus" size="small" severity="secondary" @click="openCreateCat" />
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
                {{ formatCategoryLabel(cat.key) }}
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
            <span v-if="selectedCat">Values: <span class="text-primary">{{ formatCategoryLabel(selectedCat.key) }}</span></span>
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
              <Column v-if="selectedCat?.key === 'partner.sub_area'" field="parent_label" header="Area (Parent)" />
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
        <div class="d-flex justify-content-end gap-2 w-100">
          <Button label="Create" :loading="saving" @click="submitCat" />
          <Button label="Cancel" severity="secondary" @click="showCatDialog = false" />
        </div>
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
      <div v-if="selectedCat?.key === 'partner.sub_area'" class="mb-3">
        <label class="form-label">Area (Parent) *</label>
        <Dropdown 
          v-model="valForm.parent_id" 
          :options="parentOptions" 
          optionLabel="label" 
          optionValue="id" 
          placeholder="Select Area" 
          class="w-100" 
          filter
        />
      </div>
      <div class="row mb-3">
        <div class="col-md-6">
          <label class="form-label">Sort Order</label>
          <InputNumber v-model="valForm.sort_order" class="w-100" />
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
        <div class="d-flex justify-content-end gap-2 w-100">
          <Button :label="editValId ? 'Save' : 'Add'" :loading="saving" @click="submitVal" />
          <Button label="Cancel" severity="secondary" @click="showValDialog = false" />
        </div>
      </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router'
import { computed, onMounted, ref, watch } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import InputNumber from 'primevue/inputnumber'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Tag from 'primevue/tag'
import Dialog from 'primevue/dialog'
import Dropdown from 'primevue/dropdown'
import { api } from '../lib/api'

type LookupValue = { id: string; value: string; label: string; parent_id: string | null; parent_label?: string; sort_order: number; is_active: boolean }
type LookupCategory = { id: string; key: string; values: LookupValue[] }

const categoryLabels: Record<string, string> = {
  'partner.implementation_type': 'Implementation Type',
  'partner.system_version': 'System Version',
  'partner.type': 'Type',
  'partner.group': 'Group',
  'partner.area': 'Area',
  'partner.sub_area': 'Sub Area',
  'project.type': 'Project Type',
  'project.status': 'Project Status',
  'time_boxing.type': 'Time Boxing Type',
  'arrangement.batch_status': 'Batch Status',
  'arrangement.schedule_status': 'Schedule Status',
  'arrangement.pickup_status': 'Pickup Status',
  'arrangement.schedule_type': 'Schedule Type',
  'arrangement.jobsheet_code': 'Jobsheet Code',
  'time_boxing.priority': 'Priority',
  'time_boxing.status': 'Status',
  'partner.status': 'Partner Status'
}

const formatCategoryLabel = (key: string) => categoryLabels[key] || key

const props = defineProps<{
  allowedKeys?: string[]
  prefix?: string
  title?: string
}>()

const route = useRoute()
const categories = ref<LookupCategory[]>([])
const selectedCat = ref<LookupCategory | null>(null)
const loadingCategories = ref(false)
const saving = ref(false)
const dialogError = ref<string | null>(null)

const isRestricted = computed(() => Boolean((props.allowedKeys && props.allowedKeys.length > 0) || props.prefix))
const pageTitle = computed(() => props.title || String(route.meta?.title || 'Categories'))

// Dialogs
const showCatDialog = ref(false)
const catForm = ref({ key: '' })

const showValDialog = ref(false)
const editValId = ref<string | null>(null)
const valForm = ref({ value: '', label: '', parent_id: null as string | null, sort_order: 0, is_active: true })

const parentOptions = computed(() => {
  if (selectedCat.value?.key === 'partner.sub_area') {
    return categories.value.find(c => c.key === 'partner.area')?.values || []
  }
  return []
})

const ensureAllowedCategoriesExist = async (existingKeys: Set<string>) => {
  if (!props.allowedKeys || props.allowedKeys.length === 0) return false
  const missing = props.allowedKeys.filter(k => !existingKeys.has(k))
  if (missing.length === 0) return false

  for (const key of missing) {
    try {
      await api.post('/api/lookup', { key })
    } catch {
    }
  }
  return true
}

const filterCategories = (all: LookupCategory[]) => {
  if (props.allowedKeys && props.allowedKeys.length > 0) {
    const byKey = new Map(all.map(c => [c.key, c] as const))
    return props.allowedKeys.map(k => byKey.get(k)).filter(Boolean) as LookupCategory[]
  }
  if (props.prefix) {
    return all.filter(c => c.key.startsWith(props.prefix as string))
  }
  return all
}

const load = async () => {
  loadingCategories.value = true
  try {
    const res = await api.get('/api/lookup')
    const all = res.data.data as LookupCategory[]
    const created = await ensureAllowedCategoriesExist(new Set(all.map(c => c.key)))

    if (created) {
      const res2 = await api.get('/api/lookup')
      categories.value = filterCategories(res2.data.data as LookupCategory[])
    } else {
      categories.value = filterCategories(all)
    }
    
    // Auto-select from query param or restore
    const catKey = route.query.cat as string
    if (catKey) {
      selectedCat.value = categories.value.find(c => c.key === catKey) || null
    } else if (selectedCat.value) {
      selectedCat.value = categories.value.find(c => c.id === selectedCat.value?.id) || null
    } else {
      selectedCat.value = categories.value[0] || null
    }
  } catch (e) {
    console.error('Failed to load categories', e)
  } finally {
    loadingCategories.value = false
  }
}

watch(() => route.query.cat, (newCat) => {
  if (newCat && categories.value.length > 0) {
    selectedCat.value = categories.value.find(c => c.key === newCat) || null
  }
})

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
  valForm.value = { value: '', label: '', parent_id: null as string | null, sort_order: nextSort, is_active: true }
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
        parent_id: valForm.value.parent_id,
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
