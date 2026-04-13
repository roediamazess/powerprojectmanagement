<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex justify-content-between">
          <h4 class="card-title">Analytics Dashboard</h4>
          <!-- Optional filters could go here -->
        </div>
        <div class="card-body">
          <TabView>
            <!-- TAB 1: Partners & Projects -->
            <TabPanel header="Partners & Projects">
              <div v-if="loading.partners" class="text-center py-4">
                <i class="pi pi-spin pi-spinner" style="font-size: 2rem"></i>
              </div>
              <div v-else class="row">
                <div class="col-md-6 mb-4">
                  <div class="card bg-primary text-white h-100 shadow-sm">
                    <div class="card-body d-flex align-items-center justify-content-between">
                      <div>
                        <h6 class="text-white-50 mb-2">Total Partners</h6>
                        <h2 class="text-white mb-0 fw-bold">{{ partnerData.total_partners }}</h2>
                      </div>
                      <i class="pi pi-users text-white-50" style="font-size: 3rem"></i>
                    </div>
                  </div>
                </div>
                <div class="col-md-6 mb-4">
                  <div class="card bg-success text-white h-100 shadow-sm">
                    <div class="card-body d-flex align-items-center justify-content-between">
                      <div>
                        <h6 class="text-white-50 mb-2">Total Managed Projects</h6>
                        <h2 class="text-white mb-0 fw-bold">{{ partnerData.total_projects }}</h2>
                      </div>
                      <i class="pi pi-briefcase text-white-50" style="font-size: 3rem"></i>
                    </div>
                  </div>
                </div>

                <div class="col-12 mt-2">
                  <h5 class="mb-3 border-bottom pb-2">Partner Categories</h5>
                  <div class="row">
                    <div v-for="cat in partnerData.categories" :key="cat.name" class="col-md-3 col-sm-6 mb-3">
                      <div class="p-3 border rounded shadow-sm text-center">
                        <div class="fw-bold fs-5 mb-1">{{ cat.count }}</div>
                        <div class="text-muted small">{{ cat.name }}</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </TabPanel>

            <!-- TAB 2: Time Boxing -->
            <TabPanel header="Time Boxing">
              <div v-if="loading.timeboxing" class="text-center py-4">
                <i class="pi pi-spin pi-spinner" style="font-size: 2rem"></i>
              </div>
              <div v-else class="row">
                <div class="col-12 mb-4">
                  <div class="card bg-info text-white shadow-sm border-0">
                    <div class="card-body d-flex align-items-center justify-content-between">
                      <div>
                        <h6 class="text-white-50 mb-2">Total Time Boxing Records</h6>
                        <h2 class="text-white mb-0 fw-bold">{{ tbData.total_records }}</h2>
                      </div>
                      <i class="pi pi-clock text-white-50" style="font-size: 3rem"></i>
                    </div>
                  </div>
                </div>
                <div class="col-12 mt-2">
                  <h5 class="mb-3 border-bottom pb-2">Status Distribution</h5>
                  <div class="row">
                    <div v-for="stat in tbData.status_distribution" :key="stat.status" class="col-md-4 mb-3">
                      <div class="p-3 border rounded shadow-sm d-flex justify-content-between align-items-center">
                        <span class="text-muted fw-bold">{{ stat.status }}</span>
                        <span class="badge bg-primary rounded-pill px-3 py-2 fs-6">{{ stat.count }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </TabPanel>

            <!-- TAB 3: Health Score -->
            <TabPanel header="Health Score">
              <div v-if="loading.healthscore" class="text-center py-4">
                <i class="pi pi-spin pi-spinner" style="font-size: 2rem"></i>
              </div>
              <div v-else class="row">
                <div class="col-md-6 mb-4">
                  <div class="card bg-warning shadow-sm border-0">
                    <div class="card-body d-flex align-items-center justify-content-between">
                      <div>
                        <h6 class="text-dark mb-2 opacity-75">Avg Health Score</h6>
                        <h2 class="text-dark mb-0 fw-bold">{{ hsData.average_score }} <small class="fs-6 fw-normal">/ 100</small></h2>
                      </div>
                      <i class="pi pi-heart-fill text-dark opacity-50" style="font-size: 3rem"></i>
                    </div>
                  </div>
                </div>
                <div class="col-md-6 mb-4">
                  <div class="card bg-secondary text-white shadow-sm border-0">
                    <div class="card-body d-flex align-items-center justify-content-between">
                      <div>
                        <h6 class="text-white-50 mb-2">Total Surveys Completed</h6>
                        <h2 class="text-white mb-0 fw-bold">{{ hsData.total_surveys }}</h2>
                      </div>
                      <i class="pi pi-list text-white-50" style="font-size: 3rem"></i>
                    </div>
                  </div>
                </div>

                <div class="col-12 mt-2">
                  <h5 class="mb-3 border-bottom pb-2">Survey Status Breakdown</h5>
                  <div class="row">
                    <div v-for="stat in hsData.status_distribution" :key="stat.status" class="col-md-4 mb-3">
                      <div class="p-3 border rounded shadow-sm d-flex justify-content-between align-items-center">
                        <span class="text-muted fw-bold">{{ stat.status }}</span>
                        <span class="badge bg-dark rounded-pill px-3 py-2 fs-6">{{ stat.count }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </TabPanel>
          </TabView>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import TabView from 'primevue/tabview'
import TabPanel from 'primevue/tabpanel'
import { api } from '../lib/api'

const loading = ref({
  partners: true,
  timeboxing: true,
  healthscore: true
})

const partnerData = ref({
  total_partners: 0,
  total_projects: 0,
  categories: [] as any[]
})

const tbData = ref({
  total_records: 0,
  status_distribution: [] as any[]
})

const hsData = ref({
  total_surveys: 0,
  average_score: 0,
  status_distribution: [] as any[]
})

const fetchData = async () => {
  // Parallel fetch for performance
  Promise.allSettled([
    api.get('/api/dashboard/partners').then(r => {
      partnerData.value = r.data.data
      loading.value.partners = false
    }).catch(e => console.error(e)),
    api.get('/api/dashboard/time-boxing').then(r => {
      tbData.value = r.data.data
      loading.value.timeboxing = false
    }).catch(e => console.error(e)),
    api.get('/api/dashboard/health-score').then(r => {
      hsData.value = r.data.data
      loading.value.healthscore = false
    }).catch(e => console.error(e))
  ])
}

onMounted(() => {
  fetchData()
})
</script>

<style scoped>
/* Optional styling wrapper for dynamic transitions */
.p-tabview {
  padding: 0 !important;
}
</style>
