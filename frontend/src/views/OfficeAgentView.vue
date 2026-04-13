<template>
  <div class="row h-100">
    <!-- Left Column: Chat with Agent -->
    <div class="col-xl-8 mb-4">
      <div class="card h-100 shadow-sm border-0" style="min-height: 600px;">
        <div class="card-header bg-dark text-white d-flex justify-content-between align-items-center rounded-top">
          <div class="d-flex align-items-center">
            <div class="agent-avatar bg-black text-white p-2 rounded-circle me-3 border border-secondary shadow-lg">
              <i class="fas fa-robot fs-3"></i>
            </div>
            <div>
              <h4 class="card-title text-white mb-0">Office Agent Workspace</h4>
              <span class="small" :class="agentState === 'idle' ? 'text-white-50' : 'text-info fw-bold'">
                <i v-if="agentState !== 'idle'" class="pi pi-spin pi-cog me-1"></i>
                {{ stateText }}
              </span>
            </div>
          </div>
        </div>

        <div class="card-body bg-light p-4 overflow-auto" ref="chatContainer" style="max-height: 60vh;">
          <div class="text-center text-muted mb-4">
            <small>Session started at {{ new Date().toLocaleTimeString() }}</small>
          </div>

          <div v-for="(msg, idx) in conversation" :key="idx" class="d-flex w-100 mb-3" :class="msg.role === 'user' ? 'justify-content-end' : 'justify-content-start'">
            <div class="d-flex align-items-end" :class="msg.role === 'user' ? 'flex-row-reverse' : ''">
              <div v-if="msg.role === 'agent'" class="agent-sm-avatar bg-dark text-white rounded-circle p-1 me-2 shadow-sm d-flex align-items-center justify-content-center" style="width: 32px; height: 32px">
                <i class="fas fa-robot font-12"></i>
              </div>
              <div
                 class="p-3 shadow-sm"
                 :class="[
                   msg.role === 'user' ? 'bg-primary text-white text-end rounded-start rounded-top-end ms-5' : 'bg-white text-dark border rounded-end rounded-top-start me-5'
                 ]"
                 style="font-size: 0.95rem; line-height: 1.5; white-space: pre-wrap"
              >
                {{ msg.text }}
              </div>
            </div>
          </div>

          <!-- Pending typed streaming chunk -->
          <div v-if="pendingString" class="d-flex w-100 mb-3 justify-content-start">
            <div class="d-flex align-items-end">
              <div class="agent-sm-avatar bg-dark text-white rounded-circle p-1 me-2 shadow-sm d-flex align-items-center justify-content-center" style="width: 32px; height: 32px">
                <i class="fas fa-robot font-12"></i>
              </div>
              <div class="p-3 shadow-sm bg-white text-dark border rounded-end rounded-top-start me-5" style="font-size: 0.95rem; line-height: 1.5; white-space: pre-wrap">
                {{ pendingString }}<span class="blinking-cursor">▋</span>
              </div>
            </div>
          </div>

        </div>

        <div class="card-footer bg-white border-top p-3 rounded-bottom">
          <form @submit.prevent="submitPrompt" class="input-group">
            <InputText
              v-model="prompt"
              :disabled="agentState !== 'idle'"
              placeholder="Ask the agent to create or check timeboxing..."
              class="form-control"
            />
            <Button
              type="submit"
              icon="pi pi-send"
              severity="primary"
              :disabled="agentState !== 'idle' || !prompt.trim()"
            />
          </form>
          <div class="text-muted small mt-2">
            Ask to create a timebox: <span class="fst-italic text-primary cursor-pointer" @click="prompt = 'Tolong buatkan timebox baru priority Urgent'">"Tolong buatkan timebox baru priority Urgent"</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Right Column: Agent Live Activity Feed -->
    <div class="col-xl-4 mb-4">
      <div class="card h-100 shadow-sm border-0">
        <div class="card-header bg-white border-bottom">
          <h5 class="mb-0 fw-bold"><i class="pi pi-bolt text-warning me-2"></i>Live Activity</h5>
        </div>
        <div class="card-body p-0 overflow-auto" style="max-height: 60vh;">
          <div v-if="activities.length === 0" class="text-center py-5 text-muted">
            <i class="pi pi-spin pi-spinner mb-2 fs-2"></i>
            <p>Waiting for agent actions...</p>
          </div>
          <div class="list-group list-group-flush">
            <div v-for="act in activities" :key="act.at" class="list-group-item bg-transparent">
              <div class="d-flex w-100 justify-content-between mb-1">
                <small class="text-primary fw-bold">{{ formatTime(act.at) }}</small>
              </div>
              <div class="mb-0 fs-6">{{ act.message }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import { api } from '../lib/api'

type AgentState = 'idle' | 'listening' | 'thinking' | 'acting' | 'done'

const prompt = ref('')
const agentState = ref<AgentState>('idle')
const stateText = ref('Ready')

const conversation = ref<{role: 'user'|'agent', text: string}[]>([
  { role: 'agent', text: 'Halo! Saya siap membantu Anda mengatur Time Boxing dan navigasi sistem. Apa yang bisa saya kerjakan hari ini?' }
])
const pendingString = ref('')
const activities = ref<any[]>([])
const chatContainer = ref<any>(null)

let activityInterval: any = null

const scrollToBottom = async () => {
  await nextTick()
  if (chatContainer.value) {
    chatContainer.value.scrollTop = chatContainer.value.scrollHeight
  }
}

const formatTime = (iso: string) => {
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

const fetchActivity = async () => {
  try {
    const res = await api.get('/api/office-agent/activity')
    if (res.data && res.data.items) {
      activities.value = res.data.items
    }
  } catch (e) {
    console.error(e)
  }
}

const submitPrompt = async () => {
  const text = prompt.value.trim()
  if (!text || agentState.value !== 'idle') return

  conversation.value.push({ role: 'user', text })
  prompt.value = ''
  agentState.value = 'listening'
  stateText.value = 'Preparing instruction...'
  scrollToBottom()

  try {
    const res = await api.post('/api/office-agent/store-run', { prompt: text })
    const runId = res.data.data.run_id
    startStream(runId)
  } catch (e) {
    console.error('Failed to init agent run', e)
    agentState.value = 'idle'
    stateText.value = 'Ready'
  }
}

const startStream = (runId: string) => {
  const url = `${import.meta.env.VITE_API_BASE_URL || ''}/api/office-agent/stream-run/${runId}`
  const eventSource = new EventSource(url, { withCredentials: true })

  eventSource.addEventListener('status', (e: any) => {
    const data = JSON.parse(e.data)
    agentState.value = data.state
    stateText.value = data.state === 'listening' ? 'Listening...' : 
                      data.state === 'thinking'  ? 'Agent is thinking...' :
                      data.state === 'acting'    ? 'Operating & writing...' : 'Ready'
  })

  eventSource.addEventListener('message_chunk', async (e: any) => {
    const data = JSON.parse(e.data)
    pendingString.value += data.text
    scrollToBottom()
  })

  eventSource.addEventListener('tool_call', (e: any) => {
    const data = JSON.parse(e.data)
    activities.value.unshift({ at: data.at, message: `Tool Call: ${data.name} - ${data.ok ? 'Success' : 'Failed'}` })
    fetchActivity()
  })

  eventSource.addEventListener('telegram', (e: any) => {
    const data = JSON.parse(e.data)
    activities.value.unshift({ at: new Date().toISOString(), message: `Telegram: ${data.message}` })
  })

  eventSource.addEventListener('done', async () => {
    eventSource.close()
    if (pendingString.value) {
      conversation.value.push({ role: 'agent', text: pendingString.value })
      pendingString.value = ''
    }
    agentState.value = 'idle'
    stateText.value = 'Ready'
    scrollToBottom()
  })

  eventSource.onerror = (err) => {
    console.error('EventSource error:', err)
    eventSource.close()
    agentState.value = 'idle'
    stateText.value = 'Ready'
    if (pendingString.value) {
      conversation.value.push({ role: 'agent', text: pendingString.value })
      pendingString.value = ''
    }
  }
}

onMounted(() => {
  fetchActivity()
  activityInterval = setInterval(fetchActivity, 10000)
  scrollToBottom()
})
</script>

<style scoped>
.blinking-cursor {
  font-family: monospace;
  animation: bg-blink 1s ease-in-out infinite;
  color: #3b82f6;
}

@keyframes bg-blink {
  0% { opacity: 1; }
  50% { opacity: 0; }
  100% { opacity: 1; }
}

.cursor-pointer {
  cursor: pointer;
}
.cursor-pointer:hover {
  text-decoration: underline;
}
</style>
