<template>
  <template v-if="layout === 'public'">
    <RouterView />
  </template>

  <!-- Authenticated App / Auth layout -->
  <template v-else-if="layout === 'app' || layout === 'auth'">
    <div id="preloader">
      <div class="lds-ripple">
        <div></div>
        <div></div>
      </div>
    </div>

    <div id="main-wrapper" :class="{ 'vh-100': layout === 'auth' }">
      <template v-if="layout === 'app'">
        <div class="nav-header">
          <a class="brand-logo" href="/dashboard">
            <img class="logo-abbr" :src="logoUrl" alt="Power Pro Logo" style="width: 40px; height: 40px" />
            <div class="brand-title d-none d-md-block">
              <span class="brand-title-full">Power Project Management</span>
              <span class="brand-title-short">PPM</span>
            </div>
          </a>
          <div class="nav-control d-none d-md-block">
            <div class="hamburger">
              <span class="line" />
              <span class="line" />
              <span class="line" />
            </div>
          </div>
        </div>

        <div class="header">
          <div class="header-content">
            <nav class="navbar navbar-expand">
              <div class="navbar-collapse justify-content-between">
                <div class="header-left">
                  <div class="dashboard_bar">{{ currentTitle }}</div>
                </div>

                <ul class="navbar-nav header-right">
                   <!-- Theme Toggle -->
                  <li class="nav-item">
                    <a href="javascript:void(0)" class="nav-link" @click="toggleTheme" style="padding: 8px 14px" title="Change Theme">
                      <i :class="isDark ? 'fas fa-sun' : 'fas fa-moon'" class="fs-5" />
                    </a>
                  </li>

                  <!-- Notifications -->
                  <li class="nav-item dropdown notification_dropdown">
                    <a class="nav-link ai-control" href="javascript:void(0)" role="button" data-bs-toggle="dropdown">
                      <i class="fas fa-bell fs-5" />
                      <span class="badge light text-white bg-primary rounded-circle">4</span>
                    </a>
                    <div class="dropdown-menu dropdown-menu-end">
                      <div id="DZ_W_Notification1" class="widget-media dlab-scroll p-3" style="height:380px;">
                        <ul class="timeline">
                          <li>
                            <div class="timeline-panel">
                              <div class="media me-2">
                                <img alt="image" width="50" src="/images/avatar/1.jpg">
                              </div>
                              <div class="media-body">
                                <h6 class="mb-1">Dr Franklin left a comment </h6>
                                <small class="d-block">29 July 2020 - 02:26 PM</small>
                              </div>
                            </div>
                          </li>
                        </ul>
                      </div>
                      <RouterLink class="all-notification" to="/notifications">See all notifications <i class="ti-arrow-right"></i></RouterLink>
                    </div>
                  </li>

                  <!-- User menu -->
                  <li class="nav-item dropdown header-profile">
                    <a class="nav-link" href="javascript:void(0)" role="button" data-bs-toggle="dropdown" id="user-menu">
                      <span class="d-inline-flex align-items-center" style="min-width: 0; max-width: 220px">
                        <span class="text-truncate" style="max-width: 220px" :title="displayName">{{ displayName }}</span>
                        <i class="ms-2 fas fa-chevron-down" />
                      </span>
                    </a>
                    <div class="dropdown-menu dropdown-menu-end">
                      <RouterLink class="dropdown-item ai-icon" to="/profile">
                        <i class="fas fa-user me-2" />
                        <span>My Profile</span>
                      </RouterLink>
                      <div class="dropdown-divider" />
                      <a class="dropdown-item ai-icon" href="javascript:void(0)" @click="onLogout">
                        <i class="fas fa-sign-out-alt me-2" />
                        <span>Logout</span>
                      </a>
                    </div>
                  </li>
                </ul>
              </div>
            </nav>
          </div>
        </div>

        <div class="dlabnav">
          <div class="dlabnav-scroll">
            <ul class="metismenu" id="menu">
              <!-- Dashboard -->
              <li>
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false">
                  <i class="fas fa-home" />
                  <span class="nav-text">Dashboard</span>
                </a>
                <ul aria-expanded="false">
                  <li><RouterLink to="/dashboard" active-class="mm-active">Home Overview</RouterLink></li>
                  <li><RouterLink to="/dashboard/partners-insight" active-class="mm-active">Partners Insight</RouterLink></li>
                </ul>
              </li>
              
              <li>
                <RouterLink to="/office-agent" active-class="mm-active">
                  <i class="fas fa-robot" />
                  <span class="nav-text">Office Agent</span>
                </RouterLink>
              </li>

              <!-- Operational Modules (Top Level) -->
              <li>
                <RouterLink to="/partners" active-class="mm-active">
                  <i class="fas fa-handshake" />
                  <span class="nav-text">Partners</span>
                </RouterLink>
              </li>
              <li>
                <RouterLink to="/projects" active-class="mm-active">
                  <i class="fas fa-project-diagram" />
                  <span class="nav-text">Projects</span>
                </RouterLink>
              </li>
              <li>
                <RouterLink to="/time-boxing" active-class="mm-active">
                  <i class="fas fa-stopwatch" />
                  <span class="nav-text">Time Boxing</span>
                </RouterLink>
              </li>
              <li>
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false">
                  <i class="fas fa-tasks" />
                  <span class="nav-text">Arrangements</span>
                </a>
                <ul aria-expanded="false">
                  <li><RouterLink to="/arrangements" active-class="mm-active">Overview</RouterLink></li>
                  <li><RouterLink to="/arrangements/jobsheet" active-class="mm-active">Jobsheets</RouterLink></li>
                </ul>
              </li>

              <!-- Tools -->
              <li>
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false">
                  <i class="fas fa-database text-primary" />
                  <span class="nav-text">Tools</span>
                </a>
                <ul aria-expanded="false">
                  <li><RouterLink to="/tables/partner-setup" active-class="mm-active">Partners</RouterLink></li>
                  <li><RouterLink to="/tables/time-boxing-setup" active-class="mm-active">Time Boxing</RouterLink></li>
                </ul>
              </li>

              <!-- Compliance & Health -->
              <li>
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false">
                  <i class="fas fa-chart-line" />
                  <span class="nav-text">Quality</span>
                </a>
                <ul aria-expanded="false">
                  <li><RouterLink to="/compliance" active-class="mm-active">Compliance</RouterLink></li>
                  <li><RouterLink to="/health-score" active-class="mm-active">Health Score</RouterLink></li>
                </ul>
              </li>

              <!-- System group -->
              <li>
                <a class="has-arrow" href="javascript:void(0)" aria-expanded="false">
                  <i class="fas fa-cog" />
                  <span class="nav-text">System</span>
                </a>
                <ul aria-expanded="false">
                  <li><RouterLink to="/roles" active-class="mm-active">Roles &amp; Permissions</RouterLink></li>
                  <li><RouterLink to="/messages" active-class="mm-active">Messages</RouterLink></li>
                  <li><RouterLink to="/notifications" active-class="mm-active">Notifications</RouterLink></li>
                  <li><RouterLink to="/audit-logs" active-class="mm-active">Audit Logs</RouterLink></li>
                  <li><RouterLink to="/backups" active-class="mm-active">Backups</RouterLink></li>
                </ul>
              </li>
            </ul>
          </div>
        </div>
      </template>

      <div :class="layout === 'app' ? 'content-body default-height' : ''">
        <div :class="layout === 'app' ? 'container-fluid' : ''">
          <RouterView />
        </div>
      </div>
    </div>
  </template>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from './stores/auth'

const route = useRoute()
const auth = useAuthStore()

const layout = computed(() => String(route.meta?.layout || ''))
const currentTitle = computed(() => String(route.meta?.title || route.name || 'Dashboard'))
const displayName = computed(() => auth.displayName)

const isDark = ref(localStorage.getItem('theme') === 'dark')

const applyTheme = (theme: 'dark' | 'light') => {
  document.body.setAttribute('data-theme-version', theme)
  // Fix for legacy theme persistence
  document.body.setAttribute('data-nav-headerbg', theme === 'dark' ? 'color_1' : 'color_1')
  document.body.setAttribute('data-headerbg', theme === 'dark' ? 'color_1' : 'color_1')
  document.body.setAttribute('data-sidebarbg', theme === 'dark' ? 'color_1' : 'color_1')
  
  localStorage.setItem('theme', theme)
}

const toggleTheme = () => {
  isDark.value = !isDark.value
  applyTheme(isDark.value ? 'dark' : 'light')
}

onMounted(() => {
  // Theme is already partially applied by index.html script, 
  // but we ensure state is perfectly synced and all attributes are set.
  const saved = localStorage.getItem('theme') || 'light'
  isDark.value = saved === 'dark'
  applyTheme(saved as 'dark' | 'light')
})

const logoUrl = '/images/power-pro-logo-plain.png?v=20260414_v1'

const onLogout = async () => {
  await auth.logout()
}
</script>

<style scoped>
/* Optional styling wrapper for dynamic transitions */
.p-tabview {
  padding: 0 !important;
}
</style>
