{{/*
Expand the name of the chart.
*/}}
{{- define "fusion-replication-check.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fusion-replication-check.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fusion-replication-check.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fusion-replication-check.labels" -}}
helm.sh/chart: {{ include "fusion-replication-check.chart" . }}
{{ include "fusion-replication-check.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fusion-replication-check.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fusion-replication-check.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts.
*/}}
{{- define "fusion-replication-check.namespace" -}}
  {{- if .Values.global -}}
    {{- if .Values.global.namespaceOverride -}}
      {{- .Values.global.namespaceOverride -}}
    {{- else -}}
      {{- .Release.Namespace -}}
    {{- end -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "fusion-replication-check.roleName" -}}
  {{ default (include "fusion-replication-check.fullname" .) .Values.role.name }}
{{- end -}}

{{- define "fusion-replication-check.clusterRoleName" -}}
  {{ default (include "fusion-replication-check.fullname" .) .Values.role.name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "fusion-replication-check.roleBindingName" -}}
  {{ default (include "fusion-replication-check.fullname" .) .Values.roleBinding.name }}
{{- end -}}

{{- define "fusion-replication-check.clusterRoleBindingName" -}}
  {{ default (include "fusion-replication-check.fullname" .) .Values.roleBinding.name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "fusion-replication-check.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fusion-replication-check.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
