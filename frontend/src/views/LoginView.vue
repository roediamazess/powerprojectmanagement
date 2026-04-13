<template>
  <div class="fix-wrapper">
    <div class="container">
      <div class="row justify-content-center">
        <div class="col-lg-5 col-md-6">
          <div class="card mb-0 h-auto">
            <div class="card-body">
              <div class="text-center mb-3">
                <RouterLink to="/" class="d-flex flex-column align-items-center text-decoration-none">
                  <img
                    class="logo-auth"
                    :src="logoUrl"
                    alt="Power Pro Logo"
                    style="max-width: 140px"
                  />
                </RouterLink>
              </div>

              <h4 class="text-center mb-4">Sign in your account</h4>

              <form @submit.prevent="onLogin">
                <div class="form-group mb-4">
                  <label class="form-label" for="email">Email</label>
                  <input
                    id="email"
                    v-model="email"
                    type="email"
                    name="email"
                    class="form-control"
                    placeholder="Enter email"
                    autocomplete="username"
                    autofocus
                  />
                </div>

                <div class="mb-sm-4 mb-3 position-relative">
                  <label class="form-label" for="password">Password</label>
                  <input
                    id="password"
                    v-model="password"
                    type="password"
                    name="password"
                    class="form-control"
                    placeholder="Enter password"
                    autocomplete="current-password"
                  />
                </div>

                <div v-if="error" class="alert alert-danger">{{ error }}</div>
                <div v-if="me" class="alert alert-success">Logged in as {{ me.name }}</div>

                <div class="text-center">
                  <button type="submit" class="btn btn-primary btn-block" :disabled="loading">
                    Sign In
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref<string | null>(null)
const me = ref<{ id: string; email: string; name: string; roles: string[] } | null>(null)
const router = useRouter()
const auth = useAuthStore()
const logoUrl = '/images/power-pro-logo-plain.png?v=20260326'

const onLogin = async () => {
  loading.value = true
  error.value = null
  me.value = null
  try {
    await auth.login(email.value, password.value)
    me.value = auth.me
    await router.push({ name: 'dashboard' })
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Login failed'
  } finally {
    loading.value = false
  }
}
</script>
