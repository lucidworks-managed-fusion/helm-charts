{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "collection-backups.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "collection-backups.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "zookeeper.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully uqalified Host name for zookeeper
*/}}
{{- define "collection-backups.zookeeperHost" -}}
{{- if .Values.zookeeperHost -}}
{{- .Values.zookeeperHost | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name "zookeeper" -}}
{{- printf "%s-%s-headless.%s:2181" .Release.Name $name .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully uqalified Host name for zookeeper
*/}}
{{- define "collection-backups.customerId" -}}
{{- if .Values.customerId -}}
{{- .Values.customerId | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{ include "collection-backups.namespace" . }}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "collection-backups.secretName" -}}
{{- if .Values.secretName -}}
{{- .Values.secretName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-sa" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "collection-backups.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "collection-backups.selectorLabels" -}}
app.kubernetes.io/name: {{ include "collection-backups.name" . }}
app.kubernetes.io/instance: {{ include "collection-backups.fullname" . }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "collection-backups.labels" -}}
helm.sh/chart: {{ include "collection-backups.chart" . }}
{{ include "collection-backups.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/revision: {{ .Release.Revision | quote }}
release: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "collection-backups.serviceAccountName" -}}
  {{ default (include "collection-backups.fullname" .) .Values.serviceAccount.name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "collection-backups.roleName" -}}
  {{ default (include "collection-backups.fullname" .) .Values.role.name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "collection-backups.roleBindingName" -}}
  {{ default (include "collection-backups.fullname" .) .Values.roleBinding.name }}
{{- end -}}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts.
*/}}
{{- define "collection-backups.namespace" -}}
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
Calculating the schedule
*/}}