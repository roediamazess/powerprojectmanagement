import { defineStore } from 'pinia'
import { api } from '../lib/api'

export type Me = { id: string; email: string; name: string; roles: string[] }

export const useAuthStore = defineStore('auth', {
  state: () => ({
    me: null as Me | null,
    loaded: false
  }),
  getters: {
    isAuthenticated: (state) => Boolean(state.me),
    displayName: (state) => state.me?.name || 'User'
  },
  actions: {
    async loadMe() {
      try {
        const res = await api.get('/api/auth/me')
        this.me = res.data
      } catch {
        this.me = null
      } finally {
        this.loaded = true
      }
    },
    async login(email: string, password: string) {
      await api.get('/api/auth/csrf')
      const res = await api.post('/api/auth/login', { email, password })
      this.me = res.data
      this.loaded = true
    },
    async logout() {
      try {
        await api.post('/api/auth/logout')
      } finally {
        this.me = null
        this.loaded = true
      }
    }
  }
})

