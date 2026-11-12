# Modifiche rispetto all'upstream

Base: `GoogleCloudPlatform/microservices-demo` `main` al commit `c7cb6d5b` (contenuto identico al tag `v0.10.7`
tranne due file di workflow CI). Regola: si modifica l'upstream solo se serve a un requisito della challenge
(il § indica la sezione del documento della challenge).

| # | File | Tipo | Motivo | § challenge |
|---|---|---|---|---|
| 1 | `kind/cluster.yaml` | Aggiunto (F1), modificato (F2) | Cluster kind a nodo singolo, node image fissata per digest; in F2 porte 80/443 pubblicate su `127.0.0.1` e label `ingress-ready` per l'Ingress; lease di leader election più lunghi per controller-manager e scheduler (60s/40s/5s) contro i restart causati dalla lentezza di etcd su WSL2 durante i pull delle immagini | §2.4 cluster locale, §4.3 |
| 2 | `scripts/cluster-up.sh` | Aggiunto | Creazione idempotente del cluster, ripartenza dopo un riavvio di WSL/Docker; in F2 si ferma se il cluster non ha le porte 80/443 | §2.4, §8 script |
| 3 | `docs/ARCHITECTURE.md` | Aggiunto | Architettura, flussi, mappatura dei componenti | §3, §4.1 |
| 4 | `docs/DECISIONS.md` | Aggiunto | Scelte di progetto e alternative | §10 motivare le scelte |
| 5 | `docs/CHANGES.md` | Aggiunto | Questo file | §4.1 modifiche documentate |
| 6 | `README.md` | Modificato (sezione iniziale) | Dominio, motivazione della scelta, parti usate | §2.2, §8 |
| 7 | GitHub Actions del fork; `.github/workflows/` | Workflow upstream **rimossi** (9 file + README), Actions riattivato con un solo workflow nostro (#19) | I workflow upstream richiedono Google Cloud (GKE, credenziali GCP, runner dedicati) e sul fork potrebbero solo fallire | §4.4 |
| 8 | `src/frontend/Dockerfile` | Modificato (1 riga) | Immagine finale `gcr.io/distroless/static` senza tag → `static:nonroot` **fissata per digest**: build riproducibile e utente non root anche con `docker run` | §4.2 build riproducibile |
| 9 | `helm-chart/templates/*.yaml` (13 ServiceAccount) | Modificato | `automountServiceAccountToken` configurabile (`serviceAccounts.automountToken`, default `true` = upstream) | §4.6 privilegi minimi |
| 10 | `helm-chart/templates/frontend.yaml`, `_frontend-config.tpl` | Modificato / aggiunto | Opzioni nuove, tutte disattivate di default: immagine del solo frontend (`frontend.image`), `replicas`, ConfigMap per le impostazioni non sensibili (dati definiti una volta, usati anche per l'annotation `checksum/config`), risorsa `Ingress`, regola NetworkPolicy per il namespace dell'Ingress controller, hook `preStop` (`preStopSleepSeconds`) per rolling update senza errori | §4.3 Ingress/ConfigMap, §2.3 ambienti |
| 11 | `helm-chart/templates/cartservice.yaml` | Modificato | `cartDatabase.inClusterRedis.auth`: Redis con `--requirepass` e cartservice con `REDIS_ADDR=host:port,password=$(REDIS_PASSWORD)`, password da Secret. **Nessuna modifica al codice C#**: la stringa è già una connection string di StackExchange.Redis (`src/cartservice/src/Startup.cs`) | §4.6 secret |
| 12 | `helm-chart/templates/rbac.yaml` | Aggiunto | Role `ops-readonly` + RoleBinding per gli operatori L2 (default disattivato) | §4.3 RBAC, §4.6 |
| 13 | `helm-chart/values.yaml` | Modificato | Valori di default delle opzioni sopra; con i default il chart produce gli stessi manifest dell'upstream (verificato con `helm template` + `diff`: cambia solo `automountServiceAccountToken: true` esplicito, già default di Kubernetes) | §4.1 modifiche mirate |
| 14 | `deploy/values-common.yaml`, `values-dev.yaml`, `values-prod.yaml` | Aggiunti | Configurazione comune e per ambiente (stesso chart, stessa immagine) | §2.3, §4.3 |
| 15 | `deploy/platform/traefik-values.yaml` | Aggiunto | Ingress controller Traefik su `hostPort` 80/443 | §4.3 |
| 16 | `deploy/secrets/{dev,prod}/redis-auth.sealed.yaml` | Aggiunti | Password di Redis cifrata (Sealed Secrets), diversa per ambiente | §4.6 |
| 17 | `scripts/install.sh`, `scripts/seal-secrets.sh`, `scripts/backup-sealing-key.sh` | Aggiunti | Installazione completa con un comando (idempotente; ricifra le password se i file in Git non si decifrano col cluster); generazione e cifratura delle password; backup manuale della chiave di Sealed Secrets fuori da Git | §2.4, §8 script |
| 18 | `docs/SECURITY.md` | Aggiunto | Misure applicate, verifiche e limiti residui | §4.6 |
| 19 | `.github/workflows/ci.yaml` | Aggiunto | Pipeline: shellcheck, `helm lint`, `helm template` per ambiente → `kubeconform -strict` (SealedSecret compresi), `go vet` e `go test` del frontend, build dell'immagine, scansione Trivy (CVE critiche correggibili bloccano), push su GHCR solo da `main` senza sovrascrivere un tag. Action fissate per SHA, token in sola lettura tranne `packages: write` nel job di build. `go vet` gira con `-copylocks=false`: il codice upstream passa per valore i messaggi protobuf `Money` (72 punti), correggerlo vorrebbe dire riscrivere gli handler | §4.4 |
| 20 | `deploy/values-common.yaml`, `scripts/install.sh` | Modificato | L'immagine del frontend è `ghcr.io/gverro/microservices-demo/frontend:<tag>`, pubblicata dalla CI; `install.sh` la costruisce e la carica in kind solo se manca in locale (installazione offline, piano B della demo) | §4.2, §4.4 |

Codice applicativo (`src/`): **nessuna modifica** al codice; solo una riga del Dockerfile del frontend (#8).
Tutte le modifiche al chart sono **opzioni disattivate di default**: chi usa il chart come l'upstream ottiene lo stesso risultato.
