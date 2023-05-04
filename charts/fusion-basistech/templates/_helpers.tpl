{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "fusion-basistech.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fusion-basistech.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "fusion-basistech.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "fusion-basistech.labels" -}}
helm.sh/chart: {{ include "fusion-basistech.chart" . }}
{{ include "fusion-basistech.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/revision: {{ .Release.Revision | quote }}
{{- end -}}

{{/*
Hook annotations
*/}}
{{- define "fusion-basistech.temporaryAnnotations" -}}
helm.sh/hook-weight: "-5"
helm.sh/hook-delete-policy: hook-succeeded,before-hook-creation

{{- end -}}

{{/*
Hook annotations
*/}}
{{- define "fusion-basistech.preInstallAnnotations" -}}
helm.sh/hook: pre-install,pre-upgrade
{{ include "fusion-basistech.temporaryAnnotations" . }}
{{- end -}}

{{/*
Hook annotations
*/}}
{{- define "fusion-basistech.roleHookAnnotations" -}}
helm.sh/hook: pre-install,pre-upgrade,post-delete
{{ include "fusion-basistech.temporaryAnnotations" . }}
{{- end -}}

{{/*
Hook annotations
*/}}
{{- define "fusion-basistech.postDeleteAnnotations" -}}
helm.sh/hook: post-delete
{{ include "fusion-basistech.temporaryAnnotations" . }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "fusion-basistech.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fusion-basistech.name" . }}
app.kubernetes.io/instance: {{ include "fusion-basistech.fullname" . }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "fusion-basistech.serviceAccountName" -}}
  {{ default (include "fusion-basistech.fullname" .) .Values.serviceAccount.name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "fusion-basistech.roleName" -}}
  {{ default (include "fusion-basistech.fullname" .) .Values.role.name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "fusion-basistech.roleBindingName" -}}
  {{ default (include "fusion-basistech.fullname" .) .Values.roleBinding.name }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fusion-basistech.filesBuilder" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-fb" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts.
*/}}
{{- define "fusion-basistech.namespace" -}}
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
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fusion-basistech.persistentVolume" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-pv" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fusion-basistech.persistentVolumeClaim" -}}
  {{- if and .Values.global .Values.global.basistechVolumeName -}}
    {{- .Values.global.basistechVolumeName | trunc 63 | trimSuffix "-" -}}
  {{- else if .Values.basistechVolumeName -}}
    {{- .Values.basistechVolumeName | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- $name := default .Chart.Name .Values.nameOverride -}}
    {{- if contains $name .Release.Name -}}
      {{- .Release.Name | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- printf "%s-%s-pvc" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fusion-basistech.temporaryPersistentVolumeClaim" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-tmp-pvc" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create pvc name for pvc storage.
*/}}
{{- define "fusion-basistech.volumeSnapshotName" -}}
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
Create pvc name for pvc storage.
*/}}
{{- define "fusion-basistech.volumeSnapshotClassName" -}}
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
Charts values.
*/}}
{{- define "fusion-basistech.repository" -}}
  {{- if .Values.rosette.repository -}}
    {{- .Values.rosette.repository -}}
  {{- else -}}
    {{-  (split "/" .Values.rex.repository) first  -}}
  {{- end -}}
{{- end -}}

{{/*
initContainers.
*/}}
{{- define "fusion-basistech.initContainers" -}}
  {{- $args := list -}}
  {{- $args = printf "{\"name\": \"root-rex-root\", \"image\": \"%s\",\"volumeMounts\": [{\"name\": \"basistech\",\"mountPath\": \"/roots-vol\"}]}" .Values.rex.image | append $args -}}
  {{- $args = printf "{\"name\": \"root-rbl\", \"image\": \"%s\",\"volumeMounts\": [{\"name\": \"basistech\",\"mountPath\": \"/roots-vol\"}]}" .Values.rbl.image | append $args -}}
  {{- range $.Values.languages -}}
    {{- $args = printf "{\"name\": \"%s\", \"image\": \"%s\",\"volumeMounts\": [{\"name\": \"basistech\",\"mountPath\": \"/roots-vol\"}]}" .name .image | append $args -}}
  {{- end -}}
  {{- join "," $args -}}
{{- end -}}