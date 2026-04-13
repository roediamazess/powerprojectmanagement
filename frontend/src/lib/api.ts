import axios from 'axios'

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '',
  withCredentials: true
})

api.interceptors.request.use((config) => {
  const csrf = document.cookie
    .split(';')
    .map((c) => c.trim())
    .find((c) => c.startsWith('ppm_csrf='))
    ?.split('=')[1]
  if (csrf) {
    config.headers = config.headers || {}
    config.headers['X-CSRF-Token'] = decodeURIComponent(csrf)
  }
  return config
})

api.interceptors.response.use(
  (response) => {
    const body = response.data as any
    if (body && typeof body === 'object' && 'data' in body && 'meta' in body && 'error' in body) {
      response.data = body.data
    }
    return response
  },
  (error) => {
    const data = error?.response?.data as any
    if (data && typeof data === 'object' && data.error?.message && !data.detail) {
      data.detail = data.error.message
    }
    return Promise.reject(error)
  }
)
