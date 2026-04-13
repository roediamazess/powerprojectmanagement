<template>
  <div class="row h-100 message-layout">
    <div class="col-xl-4 h-100 border-end pe-0 mb-3 mb-xl-0 d-flex flex-column" style="max-height: 80vh">
      <div class="card h-100 shadow-sm border-0 rounded-start">
        <div class="card-header d-flex justify-content-between align-items-center bg-light">
          <h4 class="card-title mb-0">Messages</h4>
          <Button icon="pi pi-pencil" size="small" rounded title="New Message" @click="showNewModal = true" />
        </div>
        <div class="card-body p-0 overflow-auto">
          <div v-if="loadingThreads" class="text-center py-5">
            <i class="pi pi-spin pi-spinner fs-2"></i>
          </div>
          <div v-else-if="threads.length === 0" class="text-center py-5 text-muted">
            <i class="pi pi-inbox fs-1 mb-2"></i>
            <p>No messages yet.</p>
          </div>
          <div v-else class="list-group list-group-flush border-0">
            <button
              v-for="t in threads"
              :key="t.user.id"
              class="list-group-item list-group-item-action py-3 border-bottom"
              :class="{ 'bg-primary-subtle border-start border-4 border-primary': selectedUserId === t.user.id }"
              @click="openThread(t.user.id)"
            >
              <div class="d-flex w-100 justify-content-between align-items-center mb-1">
                <h6 class="mb-0 fw-bold" :class="{'text-primary': t.unread_count > 0}">{{ t.user.name }}</h6>
                <small class="text-muted">{{ formatDateObj(t.last_message.created_at) }}</small>
              </div>
              <p class="mb-0 text-truncate text-muted" style="max-width: 90%" :class="{'fw-bold text-dark': t.unread_count > 0 && String(t.last_message.sender_id) !== String(auth.me?.id)}">
                <i v-if="String(t.last_message.sender_id) === String(auth.me?.id)" class="pi pi-replay fw-bold me-1 font-12"></i>
                {{ t.last_message.body }}
              </p>
              <div v-if="t.unread_count > 0" class="position-absolute" style="right: 15px; bottom: 15px">
                <span class="badge bg-danger rounded-pill">{{ t.unread_count }}</span>
              </div>
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="col-xl-8 h-100 ps-0 d-flex flex-column" style="max-height: 80vh">
      <div v-if="!selectedUserId" class="card h-100 shadow-sm border-0 rounded-end d-flex align-items-center justify-content-center">
        <div class="text-center text-muted">
          <i class="pi pi-comments mb-3" style="font-size: 4rem; opacity: 0.5;"></i>
          <h4>Select a thread to view message</h4>
        </div>
      </div>
      <div v-else class="card h-100 shadow-sm border-0 rounded-end d-flex flex-column" style="overflow: hidden;">
        <!-- Chat Header -->
        <div class="card-header bg-white border-bottom shadow-sm z-1 py-3">
          <div class="d-flex align-items-center">
            <div class="me-3 d-xl-none">
              <Button icon="pi pi-arrow-left" text rounded @click="selectedUserId = null" />
            </div>
            <div
               class="d-flex align-items-center justify-content-center bg-primary text-white rounded-circle me-3 fw-bold fs-5 shadow-sm"
               style="width: 45px; height: 45px"
            >
              {{ getInitials(activeThreadUser?.name) }}
            </div>
            <div>
              <h5 class="mb-0 fw-bold">{{ activeThreadUser?.name || 'Loading...' }}</h5>
              <div class="small text-muted">{{ activeThreadUser?.email }}</div>
            </div>
          </div>
        </div>
        
        <!-- Chat Body -->
        <div class="card-body p-4 overflow-auto bg-light" ref="chatBody">
          <div v-if="loadingMessages" class="text-center py-5">
            <i class="pi pi-spin pi-spinner fs-2"></i>
          </div>
          <div v-else class="d-flex flex-column gap-3">
            <div v-for="m in activeMessages" :key="m.id" class="d-flex w-100" :class="isMe(m.sender_id) ? 'justify-content-end' : 'justify-content-start'">
              <div
                 class="p-3 shadow-sm"
                 :class="[
                   isMe(m.sender_id) ? 'bg-primary text-white text-end' : 'bg-white text-dark border',
                   isMe(m.sender_id) ? 'rounded-start rounded-top-end ms-4' : 'rounded-end rounded-top-start me-4'
                 ]"
                 style="max-width: 75%; white-space: pre-wrap; font-size: 0.95rem; line-height: 1.5;"
              >
                <div v-if="m.subject" class="fw-bold fs-6 mb-1 border-bottom border-light pb-1">{{ m.subject }}</div>
                {{ m.body }}
                <div class="small mt-2 text-end" :class="isMe(m.sender_id) ? 'text-white-50' : 'text-muted'" style="font-size: 0.7rem">
                  {{ formatTime(m.created_at) }}
                  <i v-if="isMe(m.sender_id)" class="pi ms-1" :class="m.read_at ? 'pi-check-circle text-info' : 'pi-check'"></i>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Chat Footer -->
        <div class="card-footer bg-white border-top p-3 z-1">
          <div class="mb-2" v-if="showSubject">
            <InputText v-model="formBody.subject" placeholder="Subject (Optional)" class="w-100 shadow-none border-0 px-0 fs-6 fw-bold" style="background: transparent;" />
          </div>
          <div class="d-flex">
            <Button icon="pi pi-envelope" text rounded severity="secondary" @click="showSubject = !showSubject" class="me-2" />
            <textarea
               v-model="formBody.body"
               class="form-control me-2 h-auto"
               style="resize: none;"
               rows="1"
               placeholder="Type a message..."
               @keydown.ctrl.enter="sendMessage"
            ></textarea>
            <Button icon="pi pi-send" rounded :loading="sending" @click="sendMessage" />
          </div>
        </div>
      </div>
    </div>

    <!-- New Message Dialog -->
    <Dialog v-model:visible="showNewModal" header="New Message" :modal="true" style="width: 500px">
      <div class="mb-3">
        <label class="form-label">To:</label>
        <select v-model="formNew.recipient_id" class="form-select">
          <option value="" disabled>Select User</option>
          <option v-for="u in users" :key="u.id" :value="u.id">{{ u.name }}</option>
        </select>
      </div>
      <div class="mb-3">
        <label class="form-label">Subject</label>
        <InputText v-model="formNew.subject" class="w-100" placeholder="Optional" />
      </div>
      <div class="mb-3">
        <label class="form-label">Message</label>
        <textarea v-model="formNew.body" class="form-control" rows="5"></textarea>
      </div>
      <template #footer>
         <Button label="Cancel" severity="secondary" @click="showNewModal = false" />
         <Button label="Send" icon="pi pi-send" :loading="sending" @click="sendNewMessage" />
      </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import InputText from 'primevue/inputtext'
import { api } from '../lib/api'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()

const threads = ref<any[]>([])
const users = ref<any[]>([])
const loadingThreads = ref(false)

const selectedUserId = ref<string | null>(null)
const activeThreadUser = ref<any>(null)
const activeMessages = ref<any[]>([])
const loadingMessages = ref(false)

const showNewModal = ref(false)
const showSubject = ref(false)
const sending = ref(false)
const chatBody = ref<any>(null)

const formBody = ref({ subject: '', body: '' })
const formNew = ref({ recipient_id: '', subject: '', body: '' })

const loadThreads = async () => {
  loadingThreads.value = true
  try {
    const res = await api.get('/api/messages/threads')
    threads.value = res.data.data.threads
    users.value = res.data.data.users
  } finally {
    loadingThreads.value = false
  }
}

const openThread = async (userId: string) => {
  selectedUserId.value = userId
  loadingMessages.value = true
  try {
    const res = await api.get(`/api/messages/threads/${userId}`)
    activeMessages.value = res.data.data.messages
    activeThreadUser.value = res.data.data.other_user
    // clear unread local
    const p = threads.value.find(x => x.user.id === userId)
    if (p) p.unread_count = 0
    scrollToBottom()
  } finally {
    loadingMessages.value = false
  }
}

const sendMessage = async () => {
  if (!formBody.value.body.trim() || !selectedUserId.value) return
  sending.value = true
  try {
    await api.post('/api/messages', {
      recipient_id: selectedUserId.value,
      subject: formBody.value.subject || null,
      body: formBody.value.body
    })
    formBody.value = { subject: '', body: '' }
    await openThread(selectedUserId.value)
    loadThreads() // refresh latest message on left sidebar
  } finally {
    sending.value = false
  }
}

const sendNewMessage = async () => {
  if (!formNew.value.recipient_id || !formNew.value.body.trim()) return
  sending.value = true
  try {
    await api.post('/api/messages', { ...formNew.value })
    showNewModal.value = false
    formNew.value = { recipient_id: '', subject: '', body: '' }
    await loadThreads()
    openThread(formNew.value.recipient_id)
  } finally {
    sending.value = false
  }
}

const isMe = (id: string) => String(id) === String(auth.me?.id)

const scrollToBottom = async () => {
  await nextTick()
  if (chatBody.value) {
    chatBody.value.scrollTop = chatBody.value.scrollHeight
  }
}

// Formatting
const getInitials = (name?: string) => {
  if (!name) return '?'
  const parts = name.trim().split(' ')
  if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

const formatDateObj = (dStr?: string) => {
  if (!dStr) return ''
  const d = new Date(dStr)
  if (new Date().toDateString() === d.toDateString()) {
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }
  return d.toLocaleDateString([], { month: 'short', day: 'numeric' })
}

const formatTime = (dStr?: string) => {
  if (!dStr) return ''
  return new Date(dStr).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

onMounted(() => {
  loadThreads()
})
</script>

<style scoped>
.message-layout {
  height: calc(100vh - 150px) !important;
}
textarea.form-control:focus {
  box-shadow: none;
  border-color: #6aabf1;
}
</style>
