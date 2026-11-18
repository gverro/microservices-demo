{{/* Labels that tell who owns an environment and how critical it is (namespace and Application). */}}
{{- define "boutique-service.labels" -}}
app.kubernetes.io/part-of: online-boutique
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
boutique.kiratech.local/owner: {{ .Values.owner | quote }}
boutique.kiratech.local/tier: {{ .Values.tier | quote }}
boutique.kiratech.local/environment: {{ .Values.environment | quote }}
{{- end }}

{{/* Krateo sets global.gracefullyPaused when the Composition is paused: stop automatic sync too. */}}
{{- define "boutique-service.paused" -}}
{{- $global := .Values.global | default dict -}}
{{- if eq (toString (index $global "gracefullyPaused")) "true" }}true{{ end -}}
{{- end }}
