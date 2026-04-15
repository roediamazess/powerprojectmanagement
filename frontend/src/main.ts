import { createApp } from 'vue'
import { createPinia } from 'pinia'
import PrimeVue from 'primevue/config'
import ToastService from 'primevue/toastservice'

import App from './App.vue'
import { router } from './router'

import './style.css'
import 'primeicons/primeicons.css'
import 'primevue/resources/primevue.min.css'
import 'primevue/resources/themes/saga-blue/theme.css'
import { useAuthStore } from './stores/auth'

declare global {
  interface Window {
    Fillow?: { init?: () => void; load?: () => void; handleMenuPosition?: () => void }
  }
}

const pinia = createPinia()
const app = createApp(App).use(pinia).use(router).use(PrimeVue).use(ToastService)
app.mount('#app')

void useAuthStore(pinia).loadMe()

const loadScript = (src: string) =>
  new Promise<void>((resolve, reject) => {
    if (document.querySelector(`script[data-legacy-src="${src}"]`)) {
      resolve()
      return
    }
    const el = document.createElement('script')
    el.src = src
    el.async = false
    el.defer = true
    el.dataset.legacySrc = src
    el.onload = () => resolve()
    el.onerror = () => reject(new Error(`Failed to load ${src}`))
    document.body.appendChild(el)
  })

const ensureLink = (href: string) => {
  const key = `data-legacy-href`
  const existing = Array.from(document.querySelectorAll<HTMLLinkElement>(`link[rel="stylesheet"][${key}]`)).find(
    (l) => l.getAttribute(key) === href
  )
  if (existing) return
  const link = document.createElement('link')
  link.rel = 'stylesheet'
  link.href = href
  link.setAttribute(key, href)
  document.head.appendChild(link)
}

const removeLegacyLinks = () => {
  Array.from(document.querySelectorAll<HTMLLinkElement>('link[rel="stylesheet"][data-legacy-href]')).forEach((l) => l.remove())
}

let legacyScriptsLoaded = false

const loadLegacyScripts = async () => {
  if (legacyScriptsLoaded) return
  try {
    const v = '?v=20260414_v1'
    await loadScript('/vendor/global/global.min.js' + v)
    await loadScript('/vendor/bootstrap-select/js/bootstrap-select.min.js' + v)
    await loadScript('/vendor/counter/counter.min.js' + v)
    await loadScript('/vendor/counter/waypoint.min.js' + v)
    await loadScript('/vendor/apexchart/apexchart.js' + v)
    await loadScript('/vendor/chart-js/chart.bundle.min.js' + v)
    await loadScript('/vendor/peity/jquery.peity.min.js' + v)
    await loadScript('/vendor/owl-carousel/owl.carousel.js' + v)
    await loadScript('/vendor/draggable/draggable.js' + v)
    await loadScript('/vendor/fullcalendar/js/main.min.js' + v)
    await loadScript('/vendor/moment/moment.min.js' + v)
    await loadScript('/vendor/bootstrap-datepicker-master/js/bootstrap-datepicker.min.js' + v)
    await loadScript('/vendor/sweetalert2/sweetalert2.min.js' + v)
    await loadScript('/js/custom.js' + v)
    await loadScript('/js/dlabnav-init.js' + v)
    await loadScript('/js/sidebar-right.js' + v)
    legacyScriptsLoaded = true
  } catch (_e) {
  }
}

const enableLegacyTheme = async () => {
  await loadLegacyScripts()
  window.Fillow?.init?.()
  window.Fillow?.load?.()
  window.Fillow?.handleMenuPosition?.()
  
  // Final safeguard: Re-apply theme after legacy scripts have run
  const theme = localStorage.getItem('theme') || 'light'
  document.body.setAttribute('data-theme-version', theme)
}

const disableLegacyTheme = () => {
  removeLegacyLinks()
}

const updateThemeByRoute = async (forceLayout?: string) => {
  const currentPath = window.location.pathname
  const layoutFromRoute = String(router.currentRoute.value.meta?.layout || '')
  
  // Backup: detect layout from path if meta is not ready (e.g. before router is ready)
  let layout = forceLayout || layoutFromRoute
  if (!layout) {
    if (currentPath === '/' || currentPath === '/landing') {
      layout = 'public'
    } else if (currentPath === '/login') {
      layout = 'auth'
    } else if (currentPath.startsWith('/compliance/public/')) {
      layout = 'public'
    } else {
      layout = 'app'
    }
  }

  if (layout === 'app' || layout === 'auth') {
    const v = '?v=20260414_v1'
    ensureLink('/vendor/bootstrap-select/css/bootstrap-select.min.css' + v)
    ensureLink('/vendor/owl-carousel/owl.carousel.css' + v)
    ensureLink('/vendor/nouislider/nouislider.min.css' + v)
    ensureLink('/vendor/fullcalendar/css/main.min.css' + v)
    ensureLink('/vendor/bootstrap-datepicker-master/css/bootstrap-datepicker.min.css' + v)
    ensureLink('/vendor/sweetalert2/sweetalert2.min.css' + v)
    ensureLink('/css/style.css' + v)

    await enableLegacyTheme()
  } else {
    disableLegacyTheme()
  }
}

// Start loading theme immediately to prevent FOUC
void updateThemeByRoute()

router.isReady().then(() => {
  void updateThemeByRoute()
})

router.afterEach(() => {
  void updateThemeByRoute()
})
