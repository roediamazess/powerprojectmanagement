<template>
  <div class="row justify-content-center">
    <div class="col-xl-7">
      <!-- Profile card -->
      <div class="card mb-3">
        <div class="card-header"><h5 class="mb-0">My Profile</h5></div>
        <div class="card-body">
          <div class="mb-3">
            <label class="form-label">Full Name</label>
            <InputText v-model="name" class="w-100" />
          </div>
          <div class="mb-3">
            <label class="form-label">Email</label>
            <InputText :value="me?.email" class="w-100" disabled />
          </div>
          <div v-if="profileError" class="text-danger mb-2">{{ profileError }}</div>
          <div v-if="profileSuccess" class="text-success mb-2">Profile updated!</div>
          <Button label="Save Profile" :loading="savingProfile" @click="saveProfile" />
        </div>
      </div>

      <!-- Change password card -->
      <div class="card">
        <div class="card-header"><h5 class="mb-0">Change Password</h5></div>
        <div class="card-body">
          <div class="mb-3">
            <label class="form-label">Current Password</label>
            <InputText v-model="currentPwd" type="password" class="w-100" />
          </div>
          <div class="mb-3">
            <label class="form-label">New Password</label>
            <InputText v-model="newPwd" type="password" class="w-100" />
          </div>
          <div class="mb-3">
            <label class="form-label">Confirm New Password</label>
            <InputText v-model="confirmPwd" type="password" class="w-100" />
          </div>
          <div v-if="pwdError" class="text-danger mb-2">{{ pwdError }}</div>
          <div v-if="pwdSuccess" class="text-success mb-2">Password changed successfully!</div>
          <Button label="Change Password" :loading="savingPwd" @click="changePwd" />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import { api } from '../lib/api'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const me = computed(() => auth.me)
const name = ref('')

const savingProfile = ref(false)
const profileError = ref<string | null>(null)
const profileSuccess = ref(false)

const currentPwd = ref('')
const newPwd = ref('')
const confirmPwd = ref('')
const savingPwd = ref(false)
const pwdError = ref<string | null>(null)
const pwdSuccess = ref(false)

import { computed } from 'vue'

onMounted(async () => {
  try {
    const res = await api.get('/api/profile/me')
    name.value = res.data.data.name
  } catch {}
})

const saveProfile = async () => {
  savingProfile.value = true
  profileError.value = null
  profileSuccess.value = false
  try {
    await api.patch('/api/profile/me', { name: name.value })
    profileSuccess.value = true
    await auth.loadMe()
    setTimeout(() => { profileSuccess.value = false }, 3000)
  } catch (e: any) {
    profileError.value = e?.response?.data?.error?.message || 'Failed to save'
  } finally {
    savingProfile.value = false
  }
}

const changePwd = async () => {
  pwdError.value = null
  pwdSuccess.value = false
  if (newPwd.value !== confirmPwd.value) {
    pwdError.value = 'Passwords do not match'
    return
  }
  if (newPwd.value.length < 8) {
    pwdError.value = 'Password must be at least 8 characters'
    return
  }
  savingPwd.value = true
  try {
    await api.post('/api/profile/me/change-password', {
      current_password: currentPwd.value,
      new_password: newPwd.value,
    })
    pwdSuccess.value = true
    currentPwd.value = ''
    newPwd.value = ''
    confirmPwd.value = ''
    setTimeout(() => { pwdSuccess.value = false }, 3000)
  } catch (e: any) {
    pwdError.value = e?.response?.data?.error?.message || 'Failed to change password'
  } finally {
    savingPwd.value = false
  }
}
</script>
