<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <h4 class="card-title mb-0">Notifications</h4>
          <Button label="Mark all read" severity="secondary" :disabled="unreadCount === 0" @click="markAll" />
        </div>
        <div class="card-body">
          <div class="d-flex gap-2 mb-3">
            <Button :label="`All (${meta.total})`" :severity="!unreadOnly ? 'primary' : 'secondary'" size="small" @click="setFilter(false)" />
            <Button :label="`Unread (${unreadCount})`" :severity="unreadOnly ? 'primary' : 'secondary'" size="small" @click="setFilter(true)" />
          </div>

          <div v-if="loading" class="text-center py-4">
            <i class="pi pi-spin pi-spinner" style="font-size:2rem" />
          </div>

          <div v-else-if="!rows.length" class="text-center text-muted py-5">
            <i class="pi pi-bell-slash" style="font-size:2.5rem;opacity:.4" />
            <div class="mt-2">{{ unreadOnly ? 'No unread notifications' : 'No notifications yet' }}</div>
          </div>

          <div v-else>
            <div
              v-for="n in rows"
              :key="n.id"
              class="d-flex align-items-start p-3 mb-2 rounded border"
              :class="!n.is_read ? 'border-primary bg-light' : 'border-light'"
              style="cursor:pointer"
              @click="markRead(n)"
            >
              <div class="me-3 mt-1">
                <span
                  class="badge rounded-circle"
                  :style="`background:${!n.is_read ? '#5b8dee' : '#dee2e6'};width:10px;height:10px;display:inline-block`"
                />
              </div>
              <div class="flex-grow-1">
                <div class="fw-semibold">{{ n.title }}</div>
                <div class="text-muted small mt-1">{{ n.body }}</div>
                <div class="text-muted" style="font-size:.75rem">{{ timeAgo(n.created_at) }}</div>
              </div>
            </div>
          </div>

          <Paginator
            v-if="meta.total > meta.page_size"
            :rows="meta.page_size"
            :totalRecords="meta.total"
            @page="e => load(e.page + 1)"
            class="mt-2"
          />

          <div v-if="error" class="text-danger mt-2">{{ error }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import Button from 'primevue/button'
import Paginator from 'primevue/paginator'
import { api } from '../lib/api'

type Notif = { id: string; title: string; body: string; is_read: boolean; created_at: string }

const rows = ref<Notif[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const unreadOnly = ref(false)
const meta = ref({ total: 0, page: 1, page_size: 20, unread_count: 0 })
const unreadCount = ref(0)

const timeAgo = (iso: string) => {
  const diff = Date.now() - new Date(iso).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.floor(hours / 24)}d ago`
}

const load = async (page = 1) => {
  loading.value = true
  error.value = null
  try {
    const res = await api.get('/api/notifications', { params: { page, page_size: 20, unread_only: unreadOnly.value } })
    rows.value = res.data.data
    meta.value = res.data.meta
    unreadCount.value = res.data.meta.unread_count
  } catch (e: any) {
    error.value = e?.response?.data?.error?.message || 'Failed to load'
  } finally {
    loading.value = false
  }
}

const setFilter = (unread: boolean) => {
  unreadOnly.value = unread
  load(1)
}

const markRead = async (n: Notif) => {
  if (n.is_read) return
  try {
    await api.patch(`/api/notifications/${n.id}/read`)
    n.is_read = true
    unreadCount.value = Math.max(0, unreadCount.value - 1)
  } catch {}
}

const markAll = async () => {
  try {
    await api.patch('/api/notifications/mark-all-read')
    await load(1)
  } catch (e: any) {
    error.value = 'Failed to mark all read'
  }
}

onMounted(() => load())
</script>
