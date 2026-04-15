<template>
  <div class="partners-list">
    <!-- Header -->
    <div class="d-flex align-items-center justify-content-between mb-4">
      <div>
        <h2 class="fw-bold text-primary mb-1">Partner Management</h2>
        <p class="text-muted">Manage all partners and their basic configuration</p>
      </div>
      <div class="d-flex gap-2">
        <Button icon="pi pi-plus" label="New Partner" @click="showCreateModal = true" />
      </div>
    </div>

    <!-- Main List -->
    <div class="card border-0 shadow-sm">
      <div class="card-header bg-transparent border-0 pt-3 pb-0 d-flex justify-content-between align-items-center">
        <div class="p-input-icon-left">
          <i class="pi pi-search" />
          <InputText v-model="searchQuery" placeholder="Search partners..." @input="debouncedSearch" />
        </div>
      </div>
      <div class="card-body">
        <DataTable 
          :value="partners" 
          :loading="loadingPartners" 
          stripedRows 
          paginator 
          :rows="15" 
          responsiveLayout="scroll"
          class="p-datatable-customers"
        >
          <Column field="cnc_id" header="CNC ID" sortable class="fw-bold"></Column>
          <Column field="name" header="Name" sortable></Column>
          <Column field="star" header="Star" sortable>
            <template #body="slotProps">
              <span v-if="slotProps.data.star" class="text-warning">
                <i class="pi pi-star-fill" v-for="i in slotProps.data.star" :key="i"></i>
              </span>
              <span v-else class="text-muted">-</span>
            </template>
          </Column>
          <Column field="area" header="Area" sortable></Column>
          <Column field="sub_area" header="Sub Area" sortable></Column>
          <Column header="Status">
            <template #body="slotProps">
              <Tag :value="slotProps.data.status_label || 'Unknown'" :severity="getStatusSeverity(slotProps.data.status_label)" />
            </template>
          </Column>
          <Column header="Actions" class="text-end">
            <template #body="slotProps">
              <Button icon="pi pi-pencil" class="p-button-text p-button-sm" @click="openEdit(slotProps.data)" />
              <Button icon="pi pi-external-link" class="p-button-text p-button-sm p-button-info" />
            </template>
          </Column>
        </DataTable>
      </div>
    </div>

    <!-- Create Modal (Standardized - Identical to Edit Modal) -->
    <Dialog 
      v-model:visible="showCreateModal" 
      header="Create New Partner Record" 
      :modal="true" 
      :style="{ width: '55vw' }"
      :breakpoints="{'960px': '85vw', '640px': '95vw'}"
      class="custom-edit-modal"
      @show="initNewPartnerContacts"
    >
        <div class="p-fluid px-5 py-3">
             <!-- Section: General Information -->
            <div class="modal-section-header mb-4 mt-2">
                <i class="pi pi-plus-circle me-2"></i>
                <span>General Information</span>
            </div>
            <div class="px-2">
                <div class="row g-4 mb-4">
                    <div class="col-md-6">
                        <label class="field-label">Partner Name</label>
                        <div class="p-inputgroup">
                            <span class="p-inputgroup-addon"><i class="pi pi-building"></i></span>
                            <InputText v-model="newPartner.name" placeholder="Enter full partner name" />
                        </div>
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">CNC ID (Shortcode)</label>
                        <InputText v-model="newPartner.cnc_id" placeholder="e.g. 101" />
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">Partner Type</label>
                        <Dropdown v-model="newPartner.partner_type_id" :options="lookupOptions.partner_type" optionLabel="label" optionValue="id" placeholder="Select Type" />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Partner Group / Chain</label>
                        <Dropdown v-model="newPartner.partner_group_id" :options="lookupOptions.partner_group" optionLabel="label" optionValue="id" placeholder="Select Group" />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Full Address</label>
                        <InputText v-model="newPartner.address" placeholder="Physical address..." />
                    </div>
                </div>
            </div>

            <!-- Section: Visit & Project History -->
            <div class="modal-section-header mb-4">
                <i class="pi pi-history me-2"></i>
                <span>Visit & Project History</span>
            </div>
            <div class="px-2">
                <div class="row g-4 mb-4">
                    <div class="col-md-3">
                        <label class="field-label">Last Visit Date</label>
                        <Calendar v-model="newPartner.last_visit" dateFormat="yy-mm-dd" showIcon iconDisplay="input" />
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">Last Visit Type</label>
                        <InputText v-model="newPartner.last_visit_type" placeholder="e.g. Maintenance" />
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">Last Project</label>
                        <InputText v-model="newPartner.last_project" placeholder="Project name/ID" />
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">Last Project Type</label>
                        <InputText v-model="newPartner.last_project_type" placeholder="e.g. Upgrade" />
                    </div>
                </div>
            </div>

            <!-- Section: Infrastructure & Capacity -->
            <div class="modal-section-header mb-4">
                <i class="pi pi-bolt me-2"></i>
                <span>Status & Capacity</span>
            </div>
            <div class="px-2">
                <div class="row g-4 mb-4">
                    <div class="col-md-6">
                        <label class="field-label">Status</label>
                        <Dropdown v-model="newPartner.status_id" :options="lookupOptions.partner_status" optionLabel="label" optionValue="id" placeholder="Select Status" class="w-100" />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Service Quality (Star)</label>
                        <div class="star-rating-container p-2 border rounded d-flex align-items-center" style="height: 40px;">
                            <Rating v-model="newPartner.star" :cancel="false" />
                        </div>
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Area / Region</label>
                        <Dropdown v-model="newPartner.area" :options="lookupOptions.partner_area" optionLabel="label" optionValue="label" placeholder="Select Area" class="w-100" filter editable />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Sub Area / City</label>
                        <Dropdown v-model="newPartner.sub_area" :options="filteredSubAreasForNew" optionLabel="label" optionValue="label" placeholder="Select Sub Area" class="w-100" filter editable />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Total Rooms</label>
                        <InputNumber v-model="newPartner.room" showButtons :min="0" buttonLayout="horizontal" incrementButtonIcon="pi pi-plus" decrementButtonIcon="pi pi-minus" />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Outlets Count</label>
                        <InputNumber v-model="newPartner.outlet" showButtons :min="0" buttonLayout="horizontal" incrementButtonIcon="pi pi-plus" decrementButtonIcon="pi pi-minus" />
                    </div>
                </div>
            </div>

            <!-- Section: Management & Department Contacts -->
            <div class="modal-section-header mb-4 mt-4">
                <div class="d-flex align-items-center">
                    <i class="pi pi-briefcase me-2"></i>
                    <span>Management & Department Contacts</span>
                </div>
            </div>
            <div class="px-2">
                <div class="row g-3">
                    <div v-for="(contact, index) in newPartner.contacts" :key="contact.role_key" class="col-md-4">
                        <div class="p-3 border rounded bg-light shadow-sm h-100 department-contact-card">
                            <div class="d-flex align-items-center justify-content-between mb-2">
                                <div class="d-flex align-items-center">
                                    <Badge :value="contact.role_key" severity="info" class="me-2" />
                                    <span class="fw-bold small text-uppercase">{{ contact.role_key }}</span>
                                </div>
                                <i class="pi pi-envelope text-muted"></i>
                            </div>
                            <div class="field mb-2">
                                <label class="small text-muted mb-1 d-block">Pic Name</label>
                                <InputText v-model="contact.name" placeholder="Name" class="p-inputtext-sm w-100" />
                            </div>
                            <div class="field">
                                <label class="small text-muted mb-1 d-block">Direct Email</label>
                                <InputText v-model="contact.email" placeholder="email@example.com" class="p-inputtext-sm w-100" />
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Section: System & Deployment -->
            <div class="modal-section-header mb-4">
                <i class="pi pi-desktop me-2"></i>
                <span>System & Deployment</span>
            </div>
            <div class="px-2">
                <div class="row g-4 mb-2">
                    <div class="col-md-4">
                        <label class="field-label">System Version</label>
                        <Dropdown v-model="newPartner.system_version_id" :options="lookupOptions.system_version" optionLabel="label" optionValue="id" placeholder="Select Version" />
                    </div>
                    <div class="col-md-4">
                        <label class="field-label">Implementation</label>
                        <Dropdown v-model="newPartner.implementation_type_id" :options="lookupOptions.implementation_type" optionLabel="label" optionValue="id" placeholder="Select Type" />
                    </div>
                </div>
            </div>
        </div>
        <template #footer>
            <div class="px-4 pb-3 d-flex justify-content-end gap-2 w-100">
                <Button label="Create Record" icon="pi pi-check" @click="createPartner" :loading="creatingPartner" class="px-4" />
                <Button label="Discard" icon="pi pi-times" @click="showCreateModal = false" class="p-button-text p-button-secondary" />
            </div>
        </template>
    </Dialog>

    <!-- Edit Modal -->
    <Dialog 
      v-model:visible="showEditModal" 
      header="Partner Profile Configuration" 
      :modal="true" 
      :style="{ width: '55vw' }" 
      :breakpoints="{'960px': '85vw', '640px': '95vw'}"
      class="custom-edit-modal"
    >
        <div class="p-fluid px-5 py-3">
            <!-- Section: General Information -->
            <div class="modal-section-header mb-4 mt-2">
                <i class="pi pi-info-circle me-2"></i>
                <span>General Information</span>
            </div>
            <div class="px-2">
                <div class="row g-4 mb-4">
                    <div class="col-md-6">
                        <label class="field-label">Partner Name</label>
                        <div class="p-inputgroup">
                            <span class="p-inputgroup-addon"><i class="pi pi-building"></i></span>
                            <InputText v-model="editForm.name" placeholder="Enter partner name" />
                        </div>
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">CNC ID</label>
                        <InputText v-model="editForm.cnc_id" disabled class="p-disabled-custom" />
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">Partner Type</label>
                        <Dropdown v-model="editForm.partner_type_id" :options="lookupOptions.partner_type" optionLabel="label" optionValue="id" placeholder="Select Type" />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Partner Group / Chain</label>
                        <Dropdown v-model="editForm.partner_group_id" :options="lookupOptions.partner_group" optionLabel="label" optionValue="id" placeholder="Select Group" />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Full Address</label>
                        <InputText v-model="editForm.address" placeholder="Physical address..." />
                    </div>
                </div>
            </div>

            <!-- Section: Visit & Project History -->
            <div class="modal-section-header mb-4">
                <i class="pi pi-history me-2"></i>
                <span>Visit & Project History</span>
            </div>
            <div class="px-2">
                <div class="row g-4 mb-4">
                    <div class="col-md-3">
                        <label class="field-label">Last Visit Date</label>
                        <Calendar v-model="editForm.last_visit" dateFormat="yy-mm-dd" showIcon iconDisplay="input" />
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">Last Visit Type</label>
                        <InputText v-model="editForm.last_visit_type" placeholder="e.g. Maintenance" />
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">Last Project</label>
                        <InputText v-model="editForm.last_project" placeholder="Project name/ID" />
                    </div>
                    <div class="col-md-3">
                        <label class="field-label">Last Project Type</label>
                        <InputText v-model="editForm.last_project_type" placeholder="e.g. Upgrade" />
                    </div>
                </div>
            </div>

            <!-- Section: Infrastructure & Capacity -->
            <div class="modal-section-header mb-4">
                <i class="pi pi-bolt me-2"></i>
                <span>Status & Capacity</span>
            </div>
            <div class="px-2">
                <div class="row g-4 mb-4">
                    <div class="col-md-6">
                        <label class="field-label">Status</label>
                        <Dropdown v-model="editForm.status_id" :options="lookupOptions.partner_status" optionLabel="label" optionValue="id" placeholder="Select Status" class="w-100">
                            <template #option="slotProps">
                                <Tag :value="slotProps.option.label" :severity="getStatusSeverity(slotProps.option.label)" />
                            </template>
                        </Dropdown>
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Service Quality (Star)</label>
                        <div class="star-rating-container p-2 border rounded d-flex align-items-center" style="height: 40px;">
                            <Rating v-model="editForm.star" :cancel="false" />
                        </div>
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Area / Region</label>
                        <div class="p-inputgroup">
                            <span class="p-inputgroup-addon"><i class="pi pi-map"></i></span>
                            <Dropdown v-model="editForm.area" :options="lookupOptions.partner_area" optionLabel="label" optionValue="label" placeholder="Select Area" class="w-100" filter editable />
                        </div>
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Sub Area / City</label>
                        <Dropdown v-model="editForm.sub_area" :options="filteredSubAreasForEdit" optionLabel="label" optionValue="label" placeholder="Select Sub Area" class="w-100" filter editable />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Total Rooms</label>
                        <InputNumber v-model="editForm.room" showButtons :min="0" buttonLayout="horizontal" incrementButtonIcon="pi pi-plus" decrementButtonIcon="pi pi-minus" />
                    </div>
                    <div class="col-md-6">
                        <label class="field-label">Outlets Count</label>
                        <InputNumber v-model="editForm.outlet" showButtons :min="0" buttonLayout="horizontal" incrementButtonIcon="pi pi-plus" decrementButtonIcon="pi pi-minus" />
                    </div>
                </div>
            </div>

            <!-- Section: Department Contacts (Standard Roles) -->
            <div class="modal-section-header mb-4 mt-4">
                <div class="d-flex align-items-center">
                    <i class="pi pi-briefcase me-2"></i>
                    <span>Management & Department Contacts</span>
                </div>
            </div>
            <div class="px-2">
                <div class="row g-3">
                    <div v-for="(contact, index) in editForm.contacts" :key="contact.role_key" class="col-md-4">
                        <div class="p-3 border rounded bg-light shadow-sm h-100 department-contact-card">
                            <div class="d-flex align-items-center justify-content-between mb-2">
                                <div class="d-flex align-items-center">
                                    <Badge :value="contact.role_key" severity="info" class="me-2" />
                                    <span class="fw-bold small text-uppercase">{{ contact.role_key }}</span>
                                </div>
                                <i class="pi pi-envelope text-muted"></i>
                            </div>
                            <div class="field mb-2">
                                <label class="small text-muted mb-1 d-block">Pic Name</label>
                                <InputText v-model="contact.name" placeholder="Name" class="p-inputtext-sm w-100" />
                            </div>
                            <div class="field">
                                <label class="small text-muted mb-1 d-block">Direct Email</label>
                                <InputText v-model="contact.email" placeholder="email@example.com" class="p-inputtext-sm w-100" />
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Section: System & Deployment -->
            <div class="modal-section-header mb-4">
                <i class="pi pi-desktop me-2"></i>
                <span>System & Deployment</span>
            </div>
            <div class="px-2">
                <div class="row g-4 mb-2">
                    <div class="col-md-4">
                        <label class="field-label">System Version</label>
                        <Dropdown v-model="editForm.system_version_id" :options="lookupOptions.system_version" optionLabel="label" optionValue="id" placeholder="Select Version" />
                    </div>
                    <div class="col-md-4">
                        <label class="field-label">Implementation</label>
                        <Dropdown v-model="editForm.implementation_type_id" :options="lookupOptions.implementation_type" optionLabel="label" optionValue="id" placeholder="Select Type" />
                    </div>
                    <div class="col-md-4">
                        <label class="field-label">System Live Date</label>
                        <Calendar v-model="editForm.system_live" dateFormat="yy-mm-dd" showIcon iconDisplay="input" />
                    </div>
                </div>
            </div>
        </div>
        <template #footer>
            <div class="px-4 pb-3 d-flex justify-content-end gap-2 w-100">
                <Button label="Update Partner Profile" icon="pi pi-check" @click="savePartner" :loading="savingPartner" class="px-4" />
                <Button label="Discard Changes" icon="pi pi-times" @click="showEditModal = false" class="p-button-text p-button-secondary" />
            </div>
        </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import InputNumber from 'primevue/inputnumber'
import Dropdown from 'primevue/dropdown'
import Rating from 'primevue/rating'
import Textarea from 'primevue/textarea'
import Calendar from 'primevue/calendar'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Tag from 'primevue/tag'
import Dialog from 'primevue/dialog'
import { api } from '../lib/api'

// State
const loadingPartners = ref(false)
const searchQuery = ref('')
const partners = ref<any[]>([])

// Create Modal
const showCreateModal = ref(false)
const creatingPartner = ref(false)
const newPartner = ref<any>({ 
    cnc_id: '', 
    name: '',
    address: '',
    area: null,
    sub_area: null,
    status_id: null,
    star: 0,
    room: 0,
    outlet: 0,
    system_live: null,
    system_version_id: null,
    implementation_type_id: null,
    partner_type_id: null,
    partner_group_id: null,
    last_visit: null,
    last_visit_type: '',
    last_project: '',
    last_project_type: '',
    contacts: []
})

// Edit Modal
const showEditModal = ref(false)
const savingPartner = ref(false)
const editForm = ref<any>({})
const lookupOptions = ref<any>({
    partner_status: [],
    system_version: [],
    implementation_type: [],
    partner_type: [],
    partner_group: [],
    partner_area: [],
    partner_sub_area: []
})

const filteredSubAreasForNew = computed(() => {
    if (!newPartner.value.area) return lookupOptions.value.partner_sub_area
    return lookupOptions.value.partner_sub_area.filter((s: any) => !s.parent_label || s.parent_label === newPartner.value.area)
})

const filteredSubAreasForEdit = computed(() => {
    if (!editForm.value.area) return lookupOptions.value.partner_sub_area
    return lookupOptions.value.partner_sub_area.filter((s: any) => !s.parent_label || s.parent_label === editForm.value.area)
})

watch(() => newPartner.value.area, (newVal) => {
    if (newPartner.value.sub_area) {
        const isValid = filteredSubAreasForNew.value.some((s: any) => s.label === newPartner.value.sub_area)
        if (!isValid) newPartner.value.sub_area = null
    }
})

watch(() => editForm.value.area, (newVal) => {
    if (editForm.value.sub_area) {
        const isValid = filteredSubAreasForEdit.value.some((s: any) => s.label === editForm.value.sub_area)
        if (!isValid) editForm.value.sub_area = null
    }
})

// Methods
const initNewPartnerContacts = () => {
    const standardRoles = ['GM', 'FC', 'CA', 'CC', 'IA', 'IT', 'HRD', 'FOM', 'DOS', 'EHK', 'FBM']
    newPartner.value.contacts = standardRoles.map(role => ({
        role_key: role,
        name: '',
        email: '',
        phone: '',
        is_primary: role === 'GM'
    }))
}

const loadPartners = async () => {
  loadingPartners.value = true
  try {
    const res = await api.get('/api/partners', { params: { q: searchQuery.value } })
    partners.value = res.data.data
  } catch (e) {
    console.error('Failed to load partners', e)
  } finally {
    loadingPartners.value = false
  }
}

const loadLookups = async () => {
    try {
        const res = await api.get('/api/lookup')
        const data = res.data.data
        const activeOnly = (values: any[]) => (values || []).filter((v: any) => v?.is_active !== false)

        lookupOptions.value.partner_status = activeOnly(data.find((c: any) => c.key === 'partner.status')?.values)
        lookupOptions.value.system_version = activeOnly(data.find((c: any) => c.key === 'partner.system_version')?.values)
        lookupOptions.value.implementation_type = activeOnly(data.find((c: any) => c.key === 'partner.implementation_type')?.values)
        lookupOptions.value.partner_type = activeOnly(data.find((c: any) => c.key === 'partner.type')?.values)
        lookupOptions.value.partner_group = activeOnly(data.find((c: any) => c.key === 'partner.group')?.values)
        lookupOptions.value.partner_area = activeOnly(data.find((c: any) => c.key === 'partner.area')?.values)
        lookupOptions.value.partner_sub_area = activeOnly(data.find((c: any) => c.key === 'partner.sub_area')?.values)

        if (!newPartner.value.status_id) {
            const preferred = lookupOptions.value.partner_status.find((v: any) => String(v?.value).toUpperCase() === 'ACTIVE')
            newPartner.value.status_id = (preferred?.id || lookupOptions.value.partner_status[0]?.id) ?? null
        }
    } catch (e) {
        console.error('Failed to load lookups', e)
    }
}

const createPartner = async () => {
    creatingPartner.value = true
    try {
        const defaultStatusId = (
            lookupOptions.value.partner_status.find((v: any) => String(v?.value).toUpperCase() === 'ACTIVE')?.id
            || lookupOptions.value.partner_status[0]?.id
            || null
        )
        await api.post('/api/partners', newPartner.value)
        showCreateModal.value = false
        // Reset all fields
        newPartner.value = { 
            cnc_id: '', 
            name: '', 
            address: '', 
            area: null,
            sub_area: null,
            status_id: defaultStatusId,
            star: 0,
            room: 0,
            outlet: 0,
            system_live: null,
            system_version_id: null,
            implementation_type_id: null,
            partner_type_id: null,
            partner_group_id: null,
            last_visit: null,
            last_visit_type: '',
            last_project: '',
            last_project_type: '',
            contacts: []
        }
        await loadPartners()
    } catch (e) {
        console.error('Failed to create partner', e)
    } finally {
        creatingPartner.value = false
    }
}

const openEdit = async (partner: any) => {
    try {
        const res = await api.get(`/api/partners/${partner.id}`)
        const data = res.data
        
        // Ensure all standard roles exist for easy editing
        const standardRoles = ['GM', 'FC', 'CA', 'CC', 'IA', 'IT', 'HRD', 'FOM', 'DOS', 'EHK', 'FBM']
        if (!data.contacts) data.contacts = []
        
        standardRoles.forEach(role => {
            const exists = data.contacts.find((c: any) => c.role_key === role)
            if (!exists) {
                data.contacts.push({
                    role_key: role,
                    name: '',
                    email: '',
                    phone: '',
                    is_primary: role === 'GM'
                })
            }
        })
        
        // Sort contacts to show standard roles first in a fixed order
        data.contacts.sort((a: any, b: any) => {
            const idxA = standardRoles.indexOf(a.role_key)
            const idxB = standardRoles.indexOf(b.role_key)
            if (idxA !== -1 && idxB !== -1) return idxA - idxB
            if (idxA !== -1) return -1
            if (idxB !== -1) return 1
            return 0
        })

        // Convert ISO date string to Date object for Calendar component
        if (data.system_live) {
            data.system_live = new Date(data.system_live)
        }
        if (data.last_visit) {
            data.last_visit = new Date(data.last_visit)
        }
        
        editForm.value = data
        showEditModal.value = true
    } catch (e) {
        console.error('Failed to load partner details', e)
    }
}

const handlePrimaryChange = (index: number) => {
    if (editForm.value.contacts[index].is_primary) {
        editForm.value.contacts.forEach((c: any, i: number) => {
            if (i !== index) c.is_primary = false
        })
    }
}

const savePartner = async () => {
    savingPartner.value = true
    try {
        const id = editForm.value.id
        const payload = { ...editForm.value }
        delete payload.id
        
        // Format date back to ISO string for API
        if (payload.system_live instanceof Date) {
            payload.system_live = payload.system_live.toISOString()
        }
        if (payload.last_visit instanceof Date) {
            payload.last_visit = payload.last_visit.toISOString()
        }
        
        await api.put(`/api/partners/${id}`, payload)
        showEditModal.value = false
        await loadPartners()
    } catch (e) {
        console.error('Failed to update partner', e)
    } finally {
        savingPartner.value = false
    }
}

const getStatusSeverity = (status: string) => {
  if (!status) return 'info'
  const s = status.toLowerCase()
  if (s.includes('active')) return 'success'
  if (s.includes('freeze')) return 'warning'
  if (s.includes('inactive')) return 'danger'
  return 'info'
}

let searchTimeout: any = null
const debouncedSearch = () => {
  if (searchTimeout) clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    void loadPartners()
  }, 300)
}

onMounted(() => {
  void loadPartners()
  void loadLookups()
})
</script>

<style scoped>
:deep(.p-datatable) {
  background: var(--card-bg, transparent);
  border-radius: 8px;
  overflow: hidden;
}

:deep(.p-datatable-thead > tr > th) {
  background: var(--table-header-bg, #f8fafc);
  color: var(--text-muted, #64748b);
  font-weight: 600;
  font-size: 0.875rem;
  text-transform: uppercase;
  letter-spacing: 0.025em;
  padding: 1rem;
}

:deep(.p-datatable-tbody > tr > td) {
  padding: 1rem;
  color: var(--text-base, inherit);
}

.p-input-icon-left > i {
  color: var(--text-muted, #94a3b8);
}

:deep(.p-inputtext), :deep(.p-dropdown), :deep(.p-inputnumber-input), :deep(.p-textarea) {
  border-radius: 8px;
  border: 1px solid var(--border-color, #e2e8f0);
  background: var(--input-bg, transparent);
  color: var(--text-base, inherit);
}

:deep(.p-button) {
  border-radius: 8px;
}

/* Modal Styles */
.modal-section-header {
    font-weight: 700;
    color: var(--primary-accent, #4338ca);
    font-size: 0.95rem;
    display: flex;
    align-items: center;
    border-bottom: 2px solid var(--section-border, #eef2ff);
    padding-bottom: 0.5rem;
}

.field-label {
    display: block;
    font-weight: 600;
    color: var(--text-muted, #64748b);
    font-size: 0.85rem;
    margin-bottom: 0.4rem;
}

:deep(.p-inputgroup-addon) {
    background: var(--addon-bg, #f8fafc);
    color: var(--text-muted, #94a3b8);
    border-color: var(--border-color, #e2e8f0);
}

:deep(.p-disabled-custom) {
    background: var(--disabled-bg, #f1f5f9) !important;
    color: var(--text-disabled, #64748b) !important;
    opacity: 1;
}

.star-rating-container {
    background: var(--input-bg, transparent);
    border-color: var(--border-color, #e2e8f0);
}

:deep(.p-rating .p-rating-item.p-rating-item-active .p-icon) {
    color: #f59e0b;
}

.custom-edit-modal :deep(.p-dialog-content) {
    padding: 1.5rem 2rem;
    background: var(--card-bg, transparent);
}

.custom-edit-modal :deep(.p-dialog-header) {
    background: var(--modal-header-bg, #f8fafc);
    border-bottom: 1px solid var(--border-color, #e2e8f0);
    padding: 1.25rem 2rem;
    color: var(--text-base, inherit);
}

.custom-edit-modal :deep(.p-dialog-header-title) {
    font-weight: 700;
}

.custom-edit-modal :deep(.p-dialog-footer) {
    padding: 1rem 2rem;
    background: var(--card-bg, transparent);
    border-top: 1px solid var(--border-color, #e2e8f0)
}

.department-contact-card {
    background: var(--contact-card-bg, #f8fafc) !important;
    border-color: var(--border-color, #e2e8f0) !important;
}
</style>
