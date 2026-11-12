{{/*
Kiratech: data of the frontend ConfigMap. Defined once and used both for the ConfigMap and for the
checksum/config pod annotation, so adding a key here automatically rolls the pods when it changes.
*/}}
{{- define "onlineboutique.frontendConfig" -}}
ENV_PLATFORM: {{ .Values.frontend.platform | quote }}
CYMBAL_BRANDING: {{ .Values.frontend.cymbalBranding | quote }}
ENABLE_SINGLE_SHARED_SESSION: {{ .Values.frontend.singleSharedSession | quote }}
{{- end }}
