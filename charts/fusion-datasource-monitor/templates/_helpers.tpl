{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "fusion-datasource-monitor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fusion-datasource-monitor.fullname" -}}
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

{{/*
Create a fully qualified host name for zookeeper.
*/}}
{{- define "fusion-datasource-monitor.zookeeperHost" -}}
{{- if .Values.zookeeperHost -}}
{{- .Values.zookeeperHost | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name "zookeeper" -}}
{{- printf "%s-%s-headless.%s:2181" .Release.Name $name .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Fusion app name label - defaults to the release namespace, same pattern as
collection-backups.customerId.
*/}}
{{- define "fusion-datasource-monitor.appName" -}}
{{- if .Values.appName -}}
{{- .Values.appName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{ include "fusion-datasource-monitor.namespace" . }}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fusion-datasource-monitor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "fusion-datasource-monitor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fusion-datasource-monitor.name" . }}
app.kubernetes.io/instance: {{ include "fusion-datasource-monitor.fullname" . }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "fusion-datasource-monitor.labels" -}}
helm.sh/chart: {{ include "fusion-datasource-monitor.chart" . }}
{{ include "fusion-datasource-monitor.selectorLabels" . }}
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
{{- define "fusion-datasource-monitor.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
  {{ default (include "fusion-datasource-monitor.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
  {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts.
*/}}
{{- define "fusion-datasource-monitor.namespace" -}}
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
