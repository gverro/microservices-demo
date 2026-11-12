# Sicurezza: cosa è applicato e limiti residui

Ambito: sicurezza **minima** richiesta dalla challenge (§4.6): secret separati dal codice, ServiceAccount dedicati
con permessi minimi, limiti residui dichiarati. Ogni voce indica **come si verifica** (comando eseguito il 12/11/2026
su kind `v1.37.0`, ambienti `dev` e `prod`).

## 1. Misure applicate

| # | Misura | Dove | Verifica | Esito |
|---|---|---|---|---|
| 1 | **Secret fuori dal codice**: la password di Redis è generata casualmente (`openssl rand -hex 24`), mai scritta in chiaro; in Git c'è solo un `SealedSecret` cifrato, diverso per ambiente | `deploy/secrets/<env>/redis-auth.sealed.yaml` | `git grep -nI password -- deploy/` → solo `encryptedData` | ✅ |
| 2 | **Redis con password** (prima era aperto a qualunque pod) | `helm-chart/templates/cartservice.yaml` (`--requirepass`) | `kubectl exec -n prod deploy/redis-cart -- redis-cli ping` → `NOAUTH Authentication required` | ✅ |
| 3 | La password arriva ai container solo come variabile da `secretKeyRef`: nel manifest non compare | idem | `kubectl get deploy cartservice -n prod -o yaml` → `$(REDIS_PASSWORD)` | ✅ |
| 4 | **Un ServiceAccount per servizio**, nessun permesso RBAC sulle risorse | chart upstream | `kubectl auth can-i get pods --as=system:serviceaccount:dev:frontend -n dev` → `no` (anche `get secrets`, `create deployments`) | ✅ |
| 5 | **Token dell'API non montato** (nessun servizio usa l'API di Kubernetes) | `serviceAccounts.automountToken: false` | `kubectl exec -n dev deploy/redis-cart -- ls /var/run/secrets/kubernetes.io/serviceaccount` → `No such file or directory` | ✅ |
| 6 | **RBAC per gli operatori L2**: Role `ops-readonly` (pod, log, eventi, deployment, ingress, policy in lettura) legato al gruppo `boutique-operators`; niente Secret, niente `exec`, nessuna scrittura | `helm-chart/templates/rbac.yaml` | `kubectl auth can-i … --as=alice --as-group=boutique-operators -n dev`: `get pods` yes, `get pods/log` yes, `get secrets` no, `create pods/exec` no, `delete pods` no | ✅ |
| 7 | **NetworkPolicy**: deny-all di default più una regola per servizio (es. Redis accetta solo da cartservice, il frontend solo da Traefik e dal loadgenerator) | `networkPolicies.create: true` | pod di test nel namespace `default`: `nc` verso `redis-cart` e `frontend` di dev → bloccato; controllo positivo verso kube-dns e Traefik → aperto | ✅ |
| 8 | **securityContext restrittivo** (upstream): non root, filesystem in sola lettura, capability rimosse, niente escalation; in più **seccomp `RuntimeDefault`** | `seccompProfile.enable: true` | `kubectl get pod -n dev -l app=frontend -o jsonpath='{..seccompProfile.type}'` → `RuntimeDefault` | ✅ |
| 9 | **Immagine del frontend riproducibile e non root anche fuori da Kubernetes**: base `distroless/static:nonroot` fissata per digest | `src/frontend/Dockerfile` | `docker inspect -f '{{.Config.User}}' frontend:v0.10.7-kt.1` → `65532` | ✅ |
| 10 | **Versioni fissate** di chart e tool di piattaforma (Traefik 42.3.2, Sealed Secrets 2.22.0, kubeseal 0.41.2 con checksum verificato) | `scripts/install.sh` | lettura dello script | ✅ |
| 11 | **Esposizione solo locale**: le porte 80/443 del nodo sono pubblicate su `127.0.0.1`, non sulla rete del PC | `kind/cluster.yaml` | `docker port boutique-control-plane` → `127.0.0.1:80`, `127.0.0.1:443` | ✅ |

## 2. Come funziona Sealed Secrets (in breve)
1. Il controller nel cluster genera una coppia di chiavi; la **pubblica** la può usare chiunque per cifrare.
2. `kubeseal` cifra un Secret con la chiave pubblica → `SealedSecret`, che si può committare (legato a nome e namespace).
3. Nel cluster il controller lo decifra con la chiave **privata** e crea il `Secret` vero, che i pod leggono.

Per **ruotare** la password: si rigenera il SealedSecret con lo stesso comando, si committa, si applica, poi si
riavviano Redis e cartservice (`kubectl rollout restart deploy/redis-cart deploy/cartservice -n <env>`), perché le
variabili d'ambiente si leggono solo all'avvio.

```bash
openssl rand -hex 24 | tr -d '\n' \
  | kubectl create secret generic redis-auth -n dev --from-file=password=/dev/stdin --dry-run=client -o yaml \
  | kubeseal --format yaml > deploy/secrets/dev/redis-auth.sealed.yaml
```

## 3. Limiti residui (dichiarati)

| # | Limite | Rischio | Perché è accettato qui | Cosa si farebbe in produzione |
|---|---|---|---|---|
| L1 | **dev e prod nello stesso cluster** (due namespace) | Un problema del nodo o un errore di un admin colpisce entrambi | Ammesso dal PDF (§2.3), RAM limitata | Cluster separati, almeno per prod |
| L2 | **Chiave privata di Sealed Secrets** = "secret dei secret". Se il cluster viene ricreato senza un backup della chiave, i SealedSecret in Git non si decifrano più; chi ha il backup può decifrare tutto | Perdita di accesso ai secret, oppure loro esposizione | Il backup (`scripts/backup-sealing-key.sh`) sta fuori da Git, con permessi `600`, ed è fatto a mano dall'utente | Chiave in un KMS/HSM o gestore di secret esterno (Vault, cloud KMS) con External Secrets |
| L3 | La password di Redis è visibile come argomento del processo **dentro** il container Redis (`--requirepass`) e nella variabile `REDIS_ADDR` di cartservice | Chi ottiene una shell in quei container la legge | Nessuno ha `exec` tranne l'admin del cluster; l'immagine upstream non supporta un file di password senza un file di configurazione dedicato | File di configurazione montato da Secret, o ACL di Redis con utenti dedicati |
| L4 | **Traffico non cifrato** tra i servizi (gRPC in chiaro) e verso Redis; Ingress solo HTTP | Intercettazione dentro la rete del cluster | Cluster locale, nessun dato reale; NetworkPolicy limitano chi parla con chi | mTLS con service mesh (Istio/Linkerd), TLS sull'Ingress (cert-manager), TLS di Redis |
| L5 | **Immagini upstream per tag** (`v0.10.7`) e non per digest; non firmate né verificate | Un tag sovrascritto nel registry cambierebbe l'immagine | Il registry di Google è pubblico e i tag di release non vengono riscritti (prassi, non garanzia) | Digest, firma (cosign) e verifica all'ammissione (policy controller) |
| L6 | **Nessuna scansione di vulnerabilità** ancora | CVE note nelle immagini | Prevista in CI (fase CI/CD) | Scansione in CI + blocco sulle CVE critiche |
| L7 | **Root filesystem dei pod di piattaforma** (Traefik, Sealed Secrets) con le impostazioni di default dei loro chart; Traefik usa `hostPort` | Superficie maggiore sul nodo | Componenti ufficiali, versione fissata; `hostPort` legato a `127.0.0.1` tramite kind | Ingress controller dietro un vero LoadBalancer, Pod Security Admission `restricted` |
| L8 | **Pod Security Admission non attivo** sui namespace | Un manifest con privilegi passerebbe | I nostri manifest rispettano già il profilo, ma nulla lo impone | Label `pod-security.kubernetes.io/enforce: restricted` sui namespace |
| L9 | Le NetworkPolicy permettono a ogni pod **qualunque uscita** (`egress: {}`, come l'upstream) | Un pod compromesso può contattare l'esterno | Mantiene l'upstream invariato e il DNS funzionante | Egress solo verso DNS e servizi necessari |
| L10 | I permessi di discovery di default (`/api`, `/version`, …) restano a ogni identità autenticata | Minimo: sola lettura di metadati dell'API | Comportamento standard di Kubernetes | Invariato (comportamento atteso) |
