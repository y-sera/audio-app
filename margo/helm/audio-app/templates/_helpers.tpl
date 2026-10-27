{{- define "audio-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "audio-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "audio-app.llmFullname" -}}
{{- printf "%s-llm" (include "audio-app.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "audio-app.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "audio-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "audio-app.appSelectorLabels" -}}
app.kubernetes.io/name: {{ include "audio-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: app
{{- end }}

{{- define "audio-app.llmSelectorLabels" -}}
app.kubernetes.io/name: {{ include "audio-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: llm
{{- end }}

{{- define "audio-app.openaiBaseUrl" -}}
{{- if .Values.app.openai.baseUrl }}
{{- .Values.app.openai.baseUrl }}
{{- else if .Values.llm.enabled }}
{{- printf "http://%s:%d/v1" (include "audio-app.llmFullname" .) (int .Values.llm.port) }}
{{- else }}
{{- fail "app.openai.baseUrl is required when llm.enabled is false" }}
{{- end }}
{{- end }}

{{- define "audio-app.openaiModel" -}}
{{- if .Values.app.openai.model }}
{{- .Values.app.openai.model }}
{{- else if .Values.llm.enabled }}
{{- .Values.llm.model.id }}
{{- else }}
{{- fail "app.openai.model is required when llm.enabled is false" }}
{{- end }}
{{- end }}
