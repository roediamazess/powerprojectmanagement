<template>
  <RouterView v-if="layout === 'public' || layout === 'auth'" />

  <template v-else>
    <div id="preloader">
      <div class="lds-ripple">
        <div></div>
        <div></div>
      </div>
    </div>

    <div id="main-wrapper">
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
                <!-- Search -->
                <li class="nav-item d-none d-md-flex align-items-center">
                  <div class="input-group search-area">
                    <input type="text" class="form-control" placeholder="Search here..." />
                    <span class="input-group-text">
                      <a href="javascript:void(0)"><i class="flaticon-381-search-2" /></a>
                    </span>
                  </div>
                </li>

                <!-- Notifications bell -->
                <li class="nav-item">
                  <RouterLink to="/notifications" class="nav-link position-relative" style="padding: 8px 14px">
                    <i class="fas fa-bell fs-5" />
                  </RouterLink>
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
              <RouterLink to="/dashboard" active-class="mm-active">
                <i class="fas fa-home" />
                <span class="nav-text">Dashboard</span>
              </RouterLink>
            </li>

            <!-- Operations group -->
            <li>
              <a class="has-arrow" href="javascript:void(0)" aria-expanded="false">
                <i class="fas fa-briefcase" />
                <span class="nav-text">Operations</span>
              </a>
              <ul aria-expanded="false">
                <li><RouterLink to="/partners" active-class="mm-active">Partners</RouterLink></li>
                <li><RouterLink to="/projects" active-class="mm-active">Projects</RouterLink></li>
                <li><RouterLink to="/time-boxing" active-class="mm-active">Time Boxing</RouterLink></li>
                <li><RouterLink to="/arrangements" active-class="mm-active">Arrangements</RouterLink></li>
                <li><RouterLink to="/arrangements/jobsheet" active-class="mm-active">Jobsheets</RouterLink></li>
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

            <!-- Admin group -->
            <li>
              <a class="has-arrow" href="javascript:void(0)" aria-expanded="false">
                <i class="fas fa-users-cog" />
                <span class="nav-text">Administration</span>
              </a>
              <ul aria-expanded="false">
                <li><RouterLink to="/users" active-class="mm-active">Users</RouterLink></li>
                <li><RouterLink to="/roles" active-class="mm-active">Roles &amp; Permissions</RouterLink></li>
              </ul>
            </li>

            <!-- System group -->
            <li>
              <a class="has-arrow" href="javascript:void(0)" aria-expanded="false">
                <i class="fas fa-cog" />
                <span class="nav-text">System</span>
              </a>
              <ul aria-expanded="false">
                <li><RouterLink to="/lookup" active-class="mm-active">Master Data</RouterLink></li>
                <li><RouterLink to="/notifications" active-class="mm-active">Notifications</RouterLink></li>
                <li><RouterLink to="/audit-logs" active-class="mm-active">Audit Logs</RouterLink></li>
                <li><RouterLink to="/backups" active-class="mm-active">Backups</RouterLink></li>
              </ul>
            </li>

          </ul>
        </div>
      </div>

      <div class="content-body default-height">
        <div class="container-fluid">
          <RouterView />
        </div>
      </div>
    </div>
  </template>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from './stores/auth'

const route = useRoute()
const auth = useAuthStore()

const layout = computed(() => String(route.meta?.layout || 'app'))
const currentTitle = computed(() => String(route.meta?.title || route.name || 'Dashboard'))
const displayName = computed(() => auth.displayName)
const logoUrl = '/images/power-pro-logo-plain.png?v=20260326'

const onLogout = async () => {
  await auth.logout()
}
</script>
