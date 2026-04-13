<template>
  <div class="row">
    <div class="col-xl-12">
      <div class="card">
        <div class="card-header d-flex align-items-center justify-content-between">
          <div>
            <h4 class="card-title mb-0">Compliance Survey</h4>
            <div class="text-muted text-sm">
              {{ templateName }} — {{ surveyYear }} Q{{ surveyQuarter }} — {{ surveyStatus }}
            </div>
          </div>
          <div class="d-flex gap-2">
            <Button label="Submit" :disabled="submitting || surveyStatus === 'Submitted'" :loading="submitting" @click="submit" />
            <Button label="Refresh" severity="secondary" :loading="loading" @click="load" />
          </div>
        </div>
        <div class="card-body">
          <div v-if="scoreTotal != null" class="alert alert-info">
            Total Score: <strong>{{ scoreTotal.toFixed(2) }}</strong>
          </div>

          <div v-if="error" class="alert alert-danger">{{ error }}</div>

          <div v-for="section in sections" :key="section.id" class="mb-4">
            <div class="d-flex justify-content-between align-items-center mb-2">
              <h5 class="mb-0">{{ section.name }}</h5>
              <div v-if="scoreByCategory?.[section.name] != null" class="text-muted">
                Score: {{ Number(scoreByCategory[section.name]).toFixed(2) }}
              </div>
            </div>

            <div class="table-responsive">
              <table class="table table-striped">
                <thead>
                  <tr>
                    <th style="width: 55%">Question</th>
                    <th style="width: 30%">Answer</th>
                    <th style="width: 15%">Note</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="q in section.questions" :key="q.id">
                    <td>
                      <div class="fw-semibold">{{ q.question_text }}</div>
                      <div v-if="q.module" class="text-muted text-sm">{{ q.module }}</div>
                    </td>
                    <td>
                      <Dropdown
                        v-model="answerByQuestion[q.id]"
                        :options="q.options.map((o) => ({ label: o.label, value: o.id }))"
                        optionLabel="label"
                        optionValue="value"
                        class="w-100"
                        placeholder="Select"
                        @change="onSelect(q.id)"
                      />
                    </td>
                    <td>
                      <InputText v-model="noteByQuestion[q.id]" class="w-100" @blur="onNoteBlur(q.id)" />
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import Button from 'primevue/button'
import Dropdown from 'primevue/dropdown'
import InputText from 'primevue/inputtext'
import { api } from '../lib/api'

type Option = { id: string; label: string; score_value: number }
type Question = { id: string; module: string | null; question_text: string; answer_type: string; required: boolean; weight: number; options: Option[]; answer: any }
type Section = { id: string; name: string; weight: number; questions: Question[] }

const route = useRoute()
const surveyId = computed(() => String(route.params.id))

const loading = ref(false)
const submitting = ref(false)
const error = ref<string | null>(null)

const templateName = ref<string>('')
const surveyYear = ref<number>(0)
const surveyQuarter = ref<number>(0)
const surveyStatus = ref<string>('')
const scoreTotal = ref<number | null>(null)
const scoreByCategory = ref<Record<string, number> | null>(null)

const sections = ref<Section[]>([])

const answerByQuestion = ref<Record<string, string | null>>({})
const noteByQuestion = ref<Record<string, string>>({})

const hydrate = (payload: any) => {
  templateName.value = payload.template?.name || ''
  surveyYear.value = payload.survey?.year || 0
  surveyQuarter.value = payload.survey?.quarter || 0
  surveyStatus.value = payload.survey?.status || ''
  scoreTotal.value = payload.survey?.score_total ?? null
  scoreByCategory.value = payload.survey?.score_by_category ?? null
  sections.value = payload.sections || []

  const a: Record<string, string | null> = {}
  const n: Record<string, string> = {}
  for (const s of sections.value) {
    for (const q of s.questions) {
      a[q.id] = q.answer?.selected_option_id || null
      n[q.id] = q.answer?.note || ''
    }
  }
  answerByQuestion.value = a
  noteByQuestion.value = n
}

const load = async () => {
  loading.value = true
  error.value = null
  try {
    const res = await api.get(`/api/compliance/surveys/${surveyId.value}`)
    hydrate(res.data)
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to load survey'
  } finally {
    loading.value = false
  }
}

const saveAnswer = async (questionId: string) => {
  await api.post(`/api/compliance/surveys/${surveyId.value}/answers`, {
    question_id: questionId,
    selected_option_id: answerByQuestion.value[questionId],
    note: noteByQuestion.value[questionId] || null
  })
}

const onSelect = async (questionId: string) => {
  try {
    await saveAnswer(questionId)
    await load()
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to save answer'
  }
}

const onNoteBlur = async (questionId: string) => {
  try {
    await saveAnswer(questionId)
  } catch (e: any) {
    error.value = e?.response?.data?.detail || 'Failed to save note'
  }
}

const submit = async () => {
  submitting.value = true
  error.value = null
  try {
    await api.post(`/api/compliance/surveys/${surveyId.value}/submit`)
    await load()
  } catch (e: any) {
    const detail = e?.response?.data?.detail
    error.value = typeof detail === 'string' ? detail : 'Submit failed'
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  void load()
})
</script>

