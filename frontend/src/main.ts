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
    await loadScript('/vendor/global/global.min.js')
    await loadScript('/vendor/bootstrap-select/js/bootstrap-select.min.js')
    await loadScript('/vendor/counter/counter.min.js')
    await loadScript('/vendor/counter/waypoint.min.js')
    await loadScript('/vendor/apexchart/apexchart.js')
    await loadScript('/vendor/chart-js/chart.bundle.min.js')
    await loadScript('/vendor/peity/jquery.peity.min.js')
    await loadScript('/vendor/owl-carousel/owl.carousel.js')
    await loadScript('/vendor/draggable/draggable.js')
    await loadScript('/vendor/fullcalendar/js/main.min.js')
    await loadScript('/vendor/moment/moment.min.js')
    await loadScript('/vendor/bootstrap-datepicker-master/js/bootstrap-datepicker.min.js')
    await loadScript('/vendor/sweetalert2/sweetalert2.min.js')
    await loadScript('/js/custom.js')
    await loadScript('/js/dlabnav-init.js')
    await loadScript('/js/sidebar-right.js')
    legacyScriptsLoaded = true
  } catch (_e) {
  }
}

const enableLegacyTheme = async () => {
  ensureLink('/vendor/bootstrap-select/css/bootstrap-select.min.css')
  ensureLink('/vendor/owl-carousel/owl.carousel.css')
  ensureLink('/vendor/nouislider/nouislider.min.css')
  ensureLink('/vendor/fullcalendar/css/main.min.css')
  ensureLink('/vendor/bootstrap-datepicker-master/css/bootstrap-datepicker.min.css')
  ensureLink('/vendor/sweetalert2/sweetalert2.min.css')
  ensureLink('/css/style.css')

  await loadLegacyScripts()
  window.Fillow?.init?.()
  window.Fillow?.load?.()
  window.Fillow?.handleMenuPosition?.()
}

const disableLegacyTheme = () => {
  removeLegacyLinks()
}

const updateThemeByRoute = async () => {
  const layout = String(router.currentRoute.value.meta?.layout || 'app')
  if (layout === 'app' || layout === 'auth') {
    await enableLegacyTheme()
  } else {
    disableLegacyTheme()
  }
}

router.isReady().then(() => {
  void updateThemeByRoute()
})

router.afterEach(() => {
  void updateThemeByRoute()
})
