import { createRouter, createWebHistory, type RouteLocationNormalized } from 'vue-router'
import { useAuthStore } from '../stores/auth'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    // Public
    { path: '/', name: 'landing', meta: { title: 'Power Project Management', layout: 'public', public: true }, component: () => import('../views/LandingView.vue') },
    { path: '/login', name: 'login', meta: { title: 'Login', layout: 'auth', public: true }, component: () => import('../views/LoginView.vue') },
    { path: '/compliance/public/:token', name: 'compliance-public', meta: { title: 'Compliance', layout: 'public', public: true }, component: () => import('../views/CompliancePublicView.vue') },
    // App
    { path: '/dashboard', name: 'dashboard', meta: { title: 'Dashboard', layout: 'app' }, component: () => import('../views/DashboardView.vue') },
    { path: '/profile', name: 'profile', meta: { title: 'Profile', layout: 'app' }, component: () => import('../views/ProfileView.vue') },
    // Partners & Projects
    { path: '/partners', name: 'partners', meta: { title: 'Partners', layout: 'app' }, component: () => import('../views/PartnersView.vue') },
    { path: '/projects', name: 'projects', meta: { title: 'Projects', layout: 'app' }, component: () => import('../views/ProjectsView.vue') },
    // Operations
    { path: '/arrangements', name: 'arrangements', meta: { title: 'Arrangement', layout: 'app' }, component: () => import('../views/ArrangementsView.vue') },
    { path: '/compliance', name: 'compliance', meta: { title: 'Compliance', layout: 'app' }, component: () => import('../views/ComplianceView.vue') },
    { path: '/compliance/surveys/:id', name: 'compliance-survey', meta: { title: 'Compliance Survey', layout: 'app' }, component: () => import('../views/ComplianceSurveyView.vue') },
    { path: '/time-boxing', name: 'time-boxing', meta: { title: 'Time Boxing', layout: 'app' }, component: () => import('../views/TimeBoxingView.vue') },
    { path: '/health-score', name: 'health-score', meta: { title: 'Health Score', layout: 'app' }, component: () => import('../views/HealthScoreView.vue') },
    // Admin
    { path: '/users', name: 'users', meta: { title: 'Users', layout: 'app' }, component: () => import('../views/UsersView.vue') },
    { path: '/roles', name: 'roles', meta: { title: 'Roles & Permissions', layout: 'app' }, component: () => import('../views/RolesView.vue') },
    // System
    { path: '/lookup', name: 'lookup', meta: { title: 'Master Data (Lookup)', layout: 'app' }, component: () => import('../views/LookupView.vue') },
    { path: '/notifications', name: 'notifications', meta: { title: 'Notifications', layout: 'app' }, component: () => import('../views/NotificationsView.vue') },
    { path: '/audit-logs', name: 'audit-logs', meta: { title: 'Audit Logs', layout: 'app' }, component: () => import('../views/AuditLogsView.vue') },
    { path: '/backups', name: 'backups', meta: { title: 'Backups', layout: 'app' }, component: () => import('../views/BackupsView.vue') },
  ]
})

router.beforeEach(async (to: RouteLocationNormalized) => {
  const auth = useAuthStore()
  if (!auth.loaded) {
    await auth.loadMe()
  }

  if (to.meta.public) {
    if (auth.isAuthenticated && to.name === 'landing') {
      return { name: 'dashboard' }
    }
    return true
  }

  if (!auth.isAuthenticated) {
    return { name: 'login' }
  }

  return true
})
