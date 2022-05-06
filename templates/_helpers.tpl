{{/*
These components do not scale and there is currently no
need for them to scale with the amount of compile brokers,
so this is the static value that will always be the same,
except when manually tuned.
*/}}
{{- define "_sizing.nonScalingComponents.vCores" -}}
{{- $storageCpu := .Values.storage.resources.limits.cpu -}}
{{- $dbCpu := .Values.db.resources.requests.cpu -}}
{{- $storageReplicas := .Values.storage.replicas -}}
{{- $dbReplicas := .Values.db.replicas -}}
{{- add (mul $storageCpu $storageReplicas) (mul $dbCpu $dbReplicas) -}}
{{- end -}}

{{- define "_sizing.broker.vCores" -}}
{{- .Values.compileBroker.resources.requests.cpu -}}
{{- end -}}

{{- define "_sizing.cache.vCores" -}}
{{- .Values.cache.resources.requests.cpu -}}
{{- end -}}

{{- define "_sizing.gateway.vCores" -}}
{{- .Values.gateway.resources.requests.cpu -}}
{{- end -}}

{{- define "sizing.compileBroker.replicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.compileBroker.replicas -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.vCores "type" "brokers") -}}
{{- end -}}
{{- end -}}

{{- define "sizing.gateway.replicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.gateway.replicas -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.vCores "type" "gateways") -}}
{{- end -}}
{{- end -}}

{{- define "sizing.cache.replicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.cache.replicas -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.vCores "type" "caches") -}}
{{- end -}}
{{- end -}}

{{- define "sizing.compileBroker.minReplicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.compileBroker.autoscaler.min -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.minVCores "type" "brokers") -}}
{{- end -}}
{{- end -}}

{{- define "sizing.compileBroker.maxReplicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.compileBroker.autoscaler.max -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.maxVCores "type" "brokers") -}}
{{- end -}}
{{- end -}}

{{- define "sizing.gateway.minReplicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.gateway.autoscaler.min -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.minVCores "type" "gateways") -}}
{{- end -}}
{{- end -}}

{{- define "sizing.gateway.maxReplicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.gateway.autoscaler.max -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.maxVCores "type" "gateways") -}}
{{- end -}}
{{- end -}}

{{- define "sizing.cache.minReplicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.cache.autoscaler.min -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.minVCores "type" "caches") -}}
{{- end -}}
{{- end -}}

{{- define "sizing.cache.maxReplicas" -}}
{{- if .Values.simpleSizing.disabled -}}
{{- .Values.cache.autoscaler.max -}}
{{- else -}}
{{- include "_calculateReplicas" (dict "Values" .Values "inputCapacity" .Values.simpleSizing.maxVCores "type" "caches") -}}
{{- end -}}
{{- end -}}

{{/*
Calculates a suitable amount of replicas for the compile brokers, gateways or caches,
based on "type" input argument as returning a map from the template does not work.

Since there is no suitable way of doing condition-driven loops in the templates,
variables cannot be re-defined and are strictly scope-bound,
the formula uses recursion instead.

Expected input argumens in received context:
Values - passed in values from the root context
brokers - current iterated number of compile brokers, optional, defaults to 1
inputCapacity - amount of vCores that we need to fit into
type - one of "gateways", "caches" and "brokers" - indicates which replica amount to return
*/}}
{{- define "_calculateReplicas" -}}
{{- $brokers := max 1 (default 1 .brokers) -}}
{{- $caches := ceil (divf $brokers .Values.simpleSizing.relationships.brokersPerCache) -}}
{{- $gateways := ceil (divf $brokers .Values.simpleSizing.relationships.brokersPerGateway) -}}
{{- $brokerVCores := mul $brokers (include "_sizing.broker.vCores" .) -}}
{{- $cacheVCores := mul $caches (include "_sizing.cache.vCores" .) -}}
{{- $gatewayVCores := mul $gateways (include "_sizing.gateway.vCores" .) -}}
{{- $totalVCores := add $brokerVCores $cacheVCores $gatewayVCores (include "_sizing.nonScalingComponents.vCores" .) -}}
{{- if lt $totalVCores (.inputCapacity | int) -}}
{{- $newBrokers := add 1 $brokers -}}
{{- include "_calculateReplicas" (dict "Values" .Values "brokers" $newBrokers "type" .type "inputCapacity" .inputCapacity) -}}
{{- else -}}
{{/* If we no longer fit inside the alotted capacity, decrease compile brokers, so that we fit in. */}}
{{- $diff := sub $totalVCores .inputCapacity -}}
{{- $toSubtract := ceil (divf $diff (include "_sizing.broker.vCores" .)) -}}
{{- $updatedBrokers := max 0 (sub $brokers $toSubtract) -}}
{{- if eq .type "brokers" -}}
{{- $updatedBrokers -}}
{{- else if eq .type "caches" -}}
{{- $caches -}}
{{- else if eq .type "gateways" -}}
{{- $gateways -}}
{{- else -}}
{{- -1 -}}
{{- end -}}
{{- end -}}
{{- end -}}