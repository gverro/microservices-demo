# Sicurezza: cosa è applicato e limiti residui

Ambito: sicurezza **minima** richiesta dalla challenge (§4.6): secret separati dal codice, ServiceAccount dedicati
con permessi minimi, limiti residui dichiarati. Ogni voce indica **come si verifica** (comando eseguito il 12/11/2026
su kind `v1.37.0`, ambienti `dev` e `prod`).

## 1. Misure applicate

| # | Misura | Dove | Verifica | Esito |
|---|---|---|---|---|
| 1 | **Secret fuori dal codice**: la password di Redis è generata casualmente (`openssl rand -hex 24`), mai scritta in chiaro; in Git c'è solo un `SealedSecret` cifrato, diverso per ambiente | `deploy/secrets/<env>/redis-auth.sealed.yaml` | `git grep -nI password -- deploy/` → solo `encryptedData` e nomi di chiave (`secretKey: password`) | ✅ |
| 2 | **Redis con password** (prima era aperto a qualunque pod) | `helm-chart/templates/cartservice.yaml` (`--requirepass`) | `kubectl exec -n prod deploy/redis-cart -- redis-cli ping` → `NOAUTH Authentication required` | ✅ |
| 3 | La password arriva ai container solo come variabile da `secretKeyRef`: nel manifest non compare | idem | `kubectl get deploy cartservice -n prod -o yaml` → `$(REDIS_PASSWORD)` | ✅ |
| 4 | **Un ServiceAccount per servizio**, nessun permesso RBAC sulle risorse | chart upstream | `kubectl auth can-i get pods --as=system:serviceaccount:dev:frontend -n dev` → `no` (anche `get secrets`, `create deployments`) | ✅ |
| 5 | **Token dell'API non montato** (nessun servizio usa l'API di Kubernetes) | `serviceAccounts.automountToken: false` | `kubectl exec -n dev deploy/redis-cart -- ls /var/run/secrets/kubernetes.io/serviceaccount` → `No such file or directory` | ✅ |
| 6 | **RBAC per gli operatori L2**: Role `ops-readonly` (pod, log, eventi, deployment, ingress, policy in lettura) legato al gruppo `boutique-operators`; niente Secret, niente `exec`, nessuna scrittura | `helm-chart/templates/rbac.yaml` | `kubectl auth can-i … --as=alice --as-group=boutique-operators -n dev`: `get pods` yes, `get pods/log` yes, `get secrets` no, `create pods/exec` no, `delete pods` no | ✅ |
| 7 | **NetworkPolicy**: deny-all di default più una regola per servizio (es. Redis accetta solo da cartservice, il frontend solo da Traefik e dal loadgenerator) | `networkPolicies.create: true` | pod di test nel namespace `default`: `nc` verso `redis-cart` e `frontend` di dev → bloccato; controllo positivo verso kube-dns e Traefik → aperto | ✅ |
| 8 | **securityContext restrittivo** (upstream): non root, filesystem in sola lettura, capability rimosse, niente escalation; in più **seccomp `RuntimeDefault`** | `seccompProfile.enable: true` | `kubectl get pod -n dev -l app=frontend -o jsonpath='{..seccompProfile.type}'` → `RuntimeDefault` | ✅ |
| 9 | **Immagine del frontend riproducibile e non root anche fuori da Kubernetes**: base `distroless/static:nonroot` fissata per digest | `src/frontend/Dockerfile` | `docker inspect -f '{{.Config.User}}' frontend:v0.10.7-kt.1` → `65532` | ✅ |
| 10 | **Versioni fissate** di chart e tool di piattaforma (Traefik 42.3.2, Sealed Secrets 2.22.0); kubeseal 0.41.2 installato con verifica `sha256sum` del file ufficiale | `scripts/install.sh`, README | `kubeseal --version` → `0.41.2`; `sha256sum -c` → `OK` | ✅ |
| 11 | **Esposizione solo locale**: le porte 80/443 del nodo sono pubblicate su `127.0.0.1`, non sulla rete del PC | `kind/cluster.yaml` | `docker port boutique-control-plane` → `127.0.0.1:80`, `127.0.0.1:443` | ✅ |
| 12 | **Rinnovo automatico della chiave disattivato** (`keyrenewperiod=0`, default 30 giorni): un solo backup resta valido | `scripts/install.sh` | args del controller → `--key-renew-period 0` | ✅ |

## 2. Come funziona Sealed Secrets (in breve)
1. Il controller nel cluster genera una coppia di chiavi; la **pubblica** la può usare chiunque per cifrare.
2. `kubeseal` cifra un Secret con la chiave pubblica → `SealedSecret`, che si può committare (legato a nome e namespace).
3. Nel cluster il controller lo decifra con la chiave **privata** e crea il `Secret` vero, che i pod leggono.

Per **ruotare** la password: `./scripts/seal-secrets.sh <env>` (nuova password casuale, mai stampata), commit del file,
`kubectl apply -f deploy/secrets/<env>/`, poi riavvio di Redis e cartservice
(`kubectl rollout restart deploy/redis-cart deploy/cartservice -n <env>`), perché le variabili d'ambiente si leggono solo all'avvio.

**Cluster nuovo.** `install.sh` controlla per ogni ambiente se il SealedSecret in Git si decifra con la chiave del cluster
(`kubeseal --validate`). Se c'è un backup della chiave (`~/.config/kiratech-boutique/`, fatto con `scripts/backup-sealing-key.sh`)
lo ripristina prima di installare il controller; altrimenti cifra nuove password per quel cluster e lo segnala.

## 3. Limiti residui (dichiarati)

| # | Limite | Rischio | Perché è accettato qui | Cosa si farebbe in produzione |
|---|---|---|---|---|
| L1 | **dev e prod nello stesso cluster** (due namespace) | Un problema del nodo o un errore di un admin colpisce entrambi | Ammesso dal PDF (§2.3), RAM limitata | Cluster separati, almeno per prod |
| L2 | **Chiave privata di Sealed Secrets** = "secret dei secret". Senza backup, un cluster ricreato non decifra i SealedSecret in Git (install.sh allora genera nuove password); chi ha il backup può decifrare tutto. Il rinnovo automatico è disattivato per semplicità | Perdita di accesso ai secret, oppure loro esposizione; chiave mai ruotata | Il backup (`scripts/backup-sealing-key.sh`) sta fuori da Git, con permessi `600`, ed è fatto a mano dall'utente; ambiente locale di breve durata | Chiave in un KMS/HSM o gestore di secret esterno (Vault, cloud KMS) con External Secrets |
| L3 | La password di Redis è visibile come argomento del processo **dentro** il container Redis (`--requirepass`) e nella variabile `REDIS_ADDR` di cartservice | Chi ottiene una shell in quei container la legge | Nessuno ha `exec` tranne l'admin del cluster; l'immagine upstream non supporta un file di password senza un file di configurazione dedicato | File di configurazione montato da Secret, o ACL di Redis con utenti dedicati |
| L4 | **Traffico non cifrato** tra i servizi (gRPC in chiaro) e verso Redis; Ingress solo HTTP | Intercettazione dentro la rete del cluster | Cluster locale, nessun dato reale; NetworkPolicy limitano chi parla con chi | mTLS con service mesh (Istio/Linkerd), TLS sull'Ingress (cert-manager), TLS di Redis |
| L5 | **Immagini upstream per tag** (`v0.10.7`) e non per digest; non firmate né verificate | Un tag sovrascritto nel registry cambierebbe l'immagine | Il registry di Google è pubblico e i tag di release non vengono riscritti (prassi, non garanzia) | Digest, firma (cosign) e verifica all'ammissione (policy controller) |
| L6 | **Nessuna scansione di vulnerabilità** ancora | CVE note nelle immagini | Prevista in CI (fase CI/CD) | Scansione in CI + blocco sulle CVE critiche |
| L7 | **Componenti di piattaforma con i default dei loro chart** (Traefik, Sealed Secrets), non rivisti voce per voce; Traefik usa `hostPort` sul nodo. Nota: entrambi girano già non root e con filesystem in sola lettura (verificato con `kubectl get pod -o jsonpath`) | Superficie sul nodo dovuta a `hostPort` | Componenti ufficiali, versione fissata; la porta del nodo è pubblicata solo su `127.0.0.1` | Ingress controller dietro un vero LoadBalancer, Pod Security Admission `restricted` |
| L8 | **Pod Security Admission non attivo** sui namespace | Un manifest con privilegi passerebbe | I nostri manifest rispettano già il profilo, ma nulla lo impone | Label `pod-security.kubernetes.io/enforce: restricted` sui namespace |
| L9 | Le NetworkPolicy permettono a ogni pod **qualunque uscita** (`egress: {}`, come l'upstream) | Un pod compromesso può contattare l'esterno | Mantiene l'upstream invariato e il DNS funzionante | Egress solo verso DNS e servizi necessari |
| L11 | Il gruppo `boutique-operators` del Role `ops-readonly` non corrisponde a utenti reali su kind (si dimostra con `--as-group`) | Nessuno: il permesso è solo dichiarato | Su kind l'utente è l'admin del certificato creato da kind | Gruppo da un certificato client (`O=boutique-operators`) o da OIDC (es. gruppi del provider d'identità) |
| L12 | dev ha **una sola replica** del frontend: a ogni aggiornamento c'è un breve disservizio | Indisponibilità di pochi secondi in dev | Risparmio di RAM; prod ha 2 repliche + `preStop` (0 errori su 399 richieste durante un rollout) | Almeno 2 repliche e PodDisruptionBudget |
| L10 | I permessi di discovery di default (`/api`, `/version`, …) restano a ogni identità autenticata | Minimo: sola lettura di metadati dell'API | Comportamento standard di Kubernetes | Invariato (comportamento atteso) |
