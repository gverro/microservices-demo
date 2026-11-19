# Demo in 11 passi (§7 della challenge)

Guida per eseguire la demo dal vivo con comandi da copiare e incollare. Tutti i comandi si lanciano nel terminale (WSL Ubuntu)
**dalla radice del repo**; nessun comando richiede di sostituire parti. Prerequisiti e installazione: [README](../README.md#avvio-rapido-locale-kind).

```bash
cd ~/projects/microservices-demo    # o la cartella in cui hai clonato il repo
```

| # | Passo richiesto | Sezione | Durata indicativa |
|---|---|---|---|
| 1 | Clonare il repo e spiegare la struttura | [§1](#passo-1--clonare-il-repo-e-spiegare-la-struttura) | 2 min |
| 2 | Build dell'immagine applicativa | [§2](#passo-2--build-dellimmagine-applicativa) | 2 min |
| 3 | Installazione su Kubernetes | [§3-4](#passi-3-4--installazione-e-stato) | 2 min (rilancio idempotente; da zero 12-23 min, fatto prima) |
| 4 | Verifica di pod, service, ingress e configurazioni | [§3-4](#passi-3-4--installazione-e-stato) | 2 min |
| 5 | Invocare gli endpoint principali | [§5](#passo-5--invocare-gli-endpoint-principali) | 1 min |
| 6 | Health check, readiness, log e metriche | [§6](#passo-6--health-check-readiness-log-e-metriche) | 3 min |
| 7 | Aggiornamento applicativo e rollout | [§7](#passo-7--aggiornamento-applicativo-e-rollout) | 4 min (CI ~1 min) |
| 8 | Failure scenario e troubleshooting | [§8](#passo-8--guasto-e-troubleshooting) | 3 min |
| 9 | Rollback | [§9](#passo-9--rollback) | 3 min |
| 10 | Valutazione Krateo | [§10](#passo-10--krateo-un-team-chiede-un-ambiente) | 3 min |
| 11 | Esempio concreto di uso dell'AI | [§11](#passo-11--un-caso-concreto-di-uso-dellai) | 3 min |

Le durate sono stime per una demo di circa 25-30 minuti; i tempi reali delle prove sono nella tabella in fondo.

## Prima della demo

### Dopo un riavvio del PC (o di WSL / Docker)
Il cluster riparte da solo con Docker, ma i pod impiegano **2-3 minuti** a tornare pronti.
In quei minuti il browser può mostrare `404 page not found`. È Traefik che risponde prima di aver letto gli Ingress:
non è un guasto, basta aspettare. Prima di aprire il browser:
```bash
# 1. Aspetta che TUTTI i pod siano pronti (ritorna da solo; massimo 5 minuti)
kubectl wait --for=condition=Ready pod --all -A --timeout=300s

# 2. I quattro indirizzi devono rispondere 200 (Grafana risponde 302 → pagina di login: va bene)
for h in boutique.localhost dev.boutique.localhost argocd.localhost grafana.localhost; do printf '%s ' "$h"; curl -s -o /dev/null -w '%{http_code}\n' "http://$h/"; done
```
Dopo un riavvio `kubectl get events` mostra per circa un'ora eventi `Unhealthy` del boot (il nodo era saturo): sono attesi.
La prova che le probe non hanno ucciso nulla è la colonna RESTARTS (1 = il riavvio stesso) e `kubectl get events -A --field-selector reason=Killing` vuoto.
Se possibile, riavviare il PC almeno un'ora prima della demo.
Se un indirizzo risponde ancora 404 o 000 dopo 5 minuti: `kubectl get pods -A | grep -v Running` mostra cosa non è partito.
Se non risponde nemmeno `kubectl` (connection refused), il cluster è fermo. In WSL: `docker ps` deve mostrare `boutique-control-plane`;
se manca, `docker start boutique-control-plane`; se `docker ps` stesso dà errore, Docker non è avviato: `sudo service docker start`.

Altre verifiche da fare prima (una volta, ~5 minuti):
```bash
./scripts/smoke-test.sh dev && ./scripts/smoke-test.sh prod     # RESULT: OK per entrambi
./scripts/krateo-poc.sh                                            # serve al passo 10: finisce con "boutique-service True True"
docker build -t frontend:local src/frontend                        # mette in cache la build del passo 2
```

### Accessi
| Cosa | Indirizzo | Utente / password |
|---|---|---|
| Negozio dev | http://dev.boutique.localhost | nessuno |
| Negozio prod | http://boutique.localhost | nessuno |
| Argo CD (UI) | http://argocd.localhost | admin / password stampata da ./scripts/argocd-password.sh |
| Grafana | http://grafana.localhost | admin / password stampata da ./scripts/grafana-password.sh |
| Prometheus (UI) | http://localhost:9090 dopo il port-forward del passo 6 | nessuno (non esposto dall'Ingress) |
| Pipeline CI | https://github.com/gverro/microservices-demo/actions | account GitHub gverro |
| Immagine del frontend | https://github.com/gverro?tab=packages | pubblica |

Password di Argo CD (la stampa a schermo, non la salva da nessuna parte):
```bash
./scripts/argocd-password.sh
```
Copia **solo** la riga stampata, senza spazi prima o dopo e senza andare a capo.
Se il login dice "Invalid username or password", lancia di nuovo lo script e ricopia la password con calma: l'utente è `admin`, tutto minuscolo.

## Passo 1 — Clonare il repo e spiegare la struttura
```bash
D=$(mktemp -d) && git clone https://github.com/gverro/microservices-demo.git "$D/microservices-demo"
ls -A "$D/microservices-demo"     # stessi file del repo installato, .github compresa
```
Il tour si fa sul repo già installato (stesso contenuto di `main`):

| Cartella | Cosa contiene | Da dove viene |
|---|---|---|
| `src/` | codice degli 11 microservizi (Go, C#, Node.js, Python, Java) | upstream; modificato solo il frontend (metriche) e una riga del suo Dockerfile |
| `helm-chart/` | chart Helm upstream con opzioni aggiunte, spente di default | upstream + modifiche ([CHANGES](CHANGES.md)) |
| `deploy/` | values per ambiente, piattaforma (Traefik, Argo CD, monitoring), SealedSecret, Application di Argo CD, golden path Krateo | aggiunto |
| `scripts/` | installazione, secret, smoke test, guasti, PoC Krateo | aggiunto |
| `.github/workflows/ci.yaml` | pipeline CI | aggiunto (workflow upstream rimossi) |
| `docs/` | architettura, decisioni, sicurezza, runbook, Krateo, uso dell'AI, questa demo | aggiunto |
| `kind/` | configurazione del cluster locale | aggiunto |

```bash
git log --oneline --merges -8      # le PR della challenge, una per passo
```

## Passo 2 — Build dell'immagine applicativa
Si ricompila solo il frontend (l'unico servizio modificato, D-05); gli altri usano le immagini upstream `v0.10.7`.
```bash
docker build -t frontend:local src/frontend      # base distroless fissata per digest
docker run --rm -d --name fe-local -p 127.0.0.1:8081:8080 \
  -e PRODUCT_CATALOG_SERVICE_ADDR=x:1 -e CURRENCY_SERVICE_ADDR=x:1 -e CART_SERVICE_ADDR=x:1 \
  -e RECOMMENDATION_SERVICE_ADDR=x:1 -e CHECKOUT_SERVICE_ADDR=x:1 -e SHIPPING_SERVICE_ADDR=x:1 \
  -e AD_SERVICE_ADDR=x:1 -e SHOPPING_ASSISTANT_SERVICE_ADDR=x:1 frontend:local
sleep 2; curl -s localhost:8081/_healthz; echo      # "ok": l'immagine parte anche senza backend
docker stop fe-local                       # --rm: il container si rimuove da solo
grep -n 'image:' deploy/values-common.yaml  # il tag pubblicato dalla CI su GHCR e usato da dev e prod
```
Da dire: in cluster non gira questa build locale ma l'immagine `ghcr.io/gverro/microservices-demo/frontend:<tag>` costruita, scansionata (Trivy)
e pubblicata dalla CI solo da `main` e solo se il tag non esiste (tag immutabili).

## Passi 3-4 — Installazione e stato
```bash
# 0. Sono sul cluster giusto? Deve rispondere: kind-boutique
kubectl config current-context

# 1. Installa (o riallinea) tutta la piattaforma: kind, Traefik, Sealed Secrets, Argo CD, Applications. 12-23 minuti da zero, ~35 s se esiste già.
#    Se prod aspetta una promozione stampa "WARNING: prod: boutique-prod is OutOfSync: a promotion is pending": è normale (vedi §7b).
#    Dalla F4 le probe hanno una startupProbe: durante l'avvio si vedono eventi "Startup probe failed", ma nessun riavvio.
#    Se si ferma subito dopo "installing ..." con "etcdserver: request timed out": etcd lento su WSL, rilanciare lo stesso comando.
./scripts/install.sh

# 2. Stato delle due Application: atteso dev Synced/Healthy, prod Synced/Healthy
kubectl get applications -n argocd

# 3. Pod, service, ingress, configmap di dev (poi ripetere con -n prod)
kubectl get pods,svc,ingress,cm -n dev
```
Nella UI di Argo CD: due riquadri, `boutique-dev` e `boutique-prod`. Verde = Synced/Healthy; giallo = OutOfSync.
Cliccando un riquadro si vede l'albero delle risorse (Deployment → ReplicaSet → Pod).

## Passo 5 — Invocare gli endpoint principali
Passando dall'Ingress (Traefik), come farebbe un utente: home, pagina prodotto, aggiunta al carrello, carrello.
```bash
J=$(mktemp)    # file temporaneo per il cookie di sessione (il negozio non ha login: la sessione è un cookie)
curl -s -c "$J" -o /dev/null -w 'home      %{http_code}\n' http://dev.boutique.localhost/
curl -s -b "$J" -o /dev/null -w 'prodotto  %{http_code}\n' http://dev.boutique.localhost/product/OLJCESPC7Z
curl -s -b "$J" -c "$J" -o /dev/null -w 'aggiunta  %{http_code}\n' -d 'product_id=OLJCESPC7Z&quantity=1' http://dev.boutique.localhost/cart
curl -s -b "$J" http://dev.boutique.localhost/cart | grep -o -i -m1 sunglasses     # il prodotto è nel carrello (Redis)
curl -s -o /dev/null -w 'healthz   %{http_code}\n' http://dev.boutique.localhost/_healthz
```
Atteso: `200`, `200`, `302` (redirect al carrello), `sunglasses`, `200`. Nel browser: http://dev.boutique.localhost → prodotto → Add to cart → Place order.

## Passo 6 — Health check, readiness, log e metriche
```bash
# 1. Probe: ogni servizio ha startup, readiness e liveness (righe "Startup:", "Liveness:", "Readiness:")
kubectl describe deploy emailservice -n dev | grep -E "Startup|Liveness|Readiness"

# 2. Nessun riavvio causato dalle probe: colonna RESTARTS a 0 (o 1 dopo un riavvio del PC) e nessun "Killing"
kubectl get pods -n prod
kubectl get events -n prod --field-selector reason=Killing

# 3. Log strutturati: ogni riga è JSON; qui solo gli ordini, con l'id della richiesta
kubectl logs -n dev deploy/frontend --tail=500 | jq -c 'select(.message=="order placed") | {timestamp, "http.req.id", order}'

# 4. Le metriche NON escono dal sito: deve rispondere 404
curl -s -o /dev/null -w '%{http_code}\n' http://dev.boutique.localhost/metrics

# 5. Le metriche dal pod (porta 9090, solo dentro il cluster): in un secondo terminale, poi Ctrl+C
kubectl port-forward -n dev deploy/frontend 9091:9090
curl -s localhost:9091/metrics | grep -E '^frontend_(http_requests_total|orders_placed_total)'

# 6. Prometheus: UI su http://localhost:9090 (Status → Targets: "frontend" up in dev e prod). Ctrl+C per chiudere
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
#    Query da incollare nella UI (Graph):
#    sum by (route) (rate(frontend_http_requests_total{namespace="dev", route!="/_healthz"}[5m]))

# 7. Grafana: http://grafana.localhost → Dashboards → "Online Boutique - Frontend", in alto "Ambiente" = dev o prod
./scripts/grafana-password.sh
```
In prod non c'è il loadgenerator: per vedere dati nella dashboard di prod basta navigare un po' su http://boutique.localhost
e fare un ordine.

## Passo 7 — Aggiornamento applicativo e rollout

### 7a. Aggiornamento via Git: dev si aggiorna da solo
Cosa cambio: il banner in alto nel negozio (`frontend.platform` in `deploy/values-common.yaml`, valori ammessi: `local`, `onprem`, `aws`, `azure`, `gcp`, `alibaba`).
```bash
# 1. Prima: cosa mostra ora il banner (in dev e in prod)
kubectl get cm frontend-config -n dev  -o jsonpath='{.data.ENV_PLATFORM}{"\n"}'
kubectl get cm frontend-config -n prod -o jsonpath='{.data.ENV_PLATFORM}{"\n"}'

# 2. Ramo nuovo, modifica di UNA riga, commit e push (esempio: da onprem ad azure)
git switch main
git pull --ff-only
git switch -c demo/banner-azure
sed -i 's/^  platform: onprem /  platform: azure  /' deploy/values-common.yaml
git diff
git commit -am "feat(deploy): show the Azure banner (demo)"
git push -u origin demo/banner-azure

# 3. Pull request e merge (la CI parte da sola; merge quando è verde)
gh pr create -R gverro/microservices-demo --base main --head demo/banner-azure --title "Demo: Azure banner" --body "GitOps demo"
gh pr checks demo/banner-azure -R gverro/microservices-demo --watch
gh pr merge demo/banner-azure -R gverro/microservices-demo --merge --delete-branch

# 4. Guardare Argo CD applicarlo (entro ~3 minuti; nella UI "Refresh" lo fa subito)
kubectl get applications -n argocd -w          # Ctrl+C per uscire
kubectl rollout status deploy/frontend -n dev  # attende il nuovo pod
```
Verifica: ricaricare http://dev.boutique.localhost → banner nuovo. http://boutique.localhost → banner vecchio, e `boutique-prod` è **OutOfSync**: prod aspetta la promozione.

### 7b. Promozione in prod (sync manuale)
Dalla UI: http://argocd.localhost → riquadro `boutique-prod` → pulsante **SYNC** in alto → **SYNCHRONIZE**.
Prima, per far vedere cosa cambierà: pulsante **APP DIFF** (differenze tra Git e cluster).

Oppure da terminale:
```bash
kubectl patch application boutique-prod -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"gabriele"},"sync":{}}}'
kubectl get application boutique-prod -n argocd -w     # attendere Synced / Healthy, poi Ctrl+C
kubectl rollout status deploy/frontend -n prod
```
Verifica: ricaricare http://boutique.localhost → banner nuovo.

### 7c. Drift: Argo CD annulla le modifiche fatte a mano (dev) o le segnala (prod) — facoltativo
```bash
# dev ha selfHeal: cambio a mano la configurazione, Argo CD la rimette com'è in Git in pochi secondi
kubectl patch cm frontend-config -n dev --type merge -p '{"data":{"ENV_PLATFORM":"aws"}}'
kubectl get cm frontend-config -n dev -o jsonpath='{.data.ENV_PLATFORM}{"\n"}'   # dopo 2-3 secondi: di nuovo il valore di Git

# prod non ha selfHeal: la modifica resta, ma Argo CD la mostra come OutOfSync (nella UI: risorsa gialla, scheda DIFF)
kubectl scale deploy/frontend -n prod --replicas=3
kubectl get application boutique-prod -n argocd     # OutOfSync; la Sync di §7b la riporta a 2 repliche
```

### 7d. Pipeline CI
```bash
gh run list -R gverro/microservices-demo -w ci --limit 5     # ultimi run: completed success
gh run view --web -R gverro/microservices-demo                # apre l'ultimo run nel browser
```
Run di riferimento: verde https://github.com/gverro/microservices-demo/actions/runs/43267250772 ·
rosso voluto (manifest rotto) https://github.com/gverro/microservices-demo/actions/runs/43269182026

## Passo 8 — Guasto e troubleshooting
Guasto consigliato dal vivo: **Service senza endpoint** (pod tutti verdi, sito rotto). Alternative: `bad-image`, `bad-config`, `netpol` (`scripts/fault.sh list`).
```bash
# 0. Punto di partenza sano
./scripts/smoke-test.sh dev

# 1. Guasto (sospende la sync automatica di dev, poi cambia il selettore del Service cartservice)
./scripts/fault.sh no-endpoints inject

# 2. Sintomo: lo smoke test lo trova subito; il sito può rispondere ancora 200 per le connessioni gRPC già aperte
./scripts/smoke-test.sh dev
kubectl rollout restart deploy/frontend -n dev && kubectl rollout status deploy/frontend -n dev
# la prima risposta può essere ancora 200 (pod vecchio nei 5 s di preStop), poi 500: la prima dopo ~20 s, le altre subito
for i in 1 2 3; do curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' --max-time 30 http://dev.boutique.localhost/; done

# 3. Diagnosi dal basso verso l'alto (`docs/RUNBOOK.md` §2)
kubectl get pods -n dev -l app=cartservice                                    # Running 1/1: i pod stanno bene
kubectl get endpointslices -n dev -l kubernetes.io/service-name=cartservice   # ENDPOINTS <unset>: il Service è vuoto
kubectl get svc cartservice -n dev -o wide                                    # SELECTOR app=cart-service
kubectl get pods -n dev -l app=cartservice --show-labels                      # i pod hanno app=cartservice → selettore sbagliato
kubectl logs -n dev -l app=frontend -c server --tail=200 | jq -c 'select(.severity=="error") | {error, path: ."http.req.path"}' | tail -2

# 4. Rimedio: ridare il controllo a Git (Argo CD rimette il selettore giusto), poi verifica
./scripts/fault.sh restore
kubectl get endpointslices -n dev -l kubernetes.io/service-name=cartservice   # di nuovo un indirizzo
kubectl rollout status deploy/frontend -n dev && ./scripts/smoke-test.sh dev   # RESULT: OK
```
Cosa dire: "pod verdi non vuol dire servizio funzionante: il Service senza endpoint non porta traffico a nessuno. Con lo stesso `i/o timeout`
ma endpoint presenti avrei guardato le NetworkPolicy." Se lo smoke test dà un FAIL HTTP subito dopo il rollout, rilanciarlo: per qualche secondo
risponde ancora il pod che termina.

## Passo 9 — Rollback
Si annulla il cambio del banner fatto al passo 7 (§7a, "Azure banner"). Dev con `git revert`, prod con il rollback di emergenza dalla history.
```bash
# 1. dev: revert del commit (non del merge) e PR
git switch main
git pull --ff-only
git log --oneline --no-merges -1 --grep "Azure banner"
git switch -c demo/revert-banner
git revert --no-edit "$(git log --format=%H --no-merges -1 --grep 'Azure banner')"
git push -u origin demo/revert-banner
gh pr create -R gverro/microservices-demo --base main --head demo/revert-banner --title "Demo: revert the Azure banner" --body "Rollback demo"
gh pr checks demo/revert-banner -R gverro/microservices-demo --watch
gh pr merge demo/revert-banner -R gverro/microservices-demo --merge --delete-branch

# 2. Nella UI di Argo CD premere REFRESH su boutique-dev (senza, il polling arriva entro ~3 min), poi:
kubectl get cm frontend-config -n dev -o jsonpath='{.data.ENV_PLATFORM}{"\n"}'   # onprem
./scripts/smoke-test.sh dev
```
Prod (se al passo 7 è stato promosso): rollback di emergenza dalla UI, **prima** di promuovere il revert.
```bash
# 3. Quali voci ci sono nella history di prod e quale revisione contengono
kubectl get application boutique-prod -n argocd -o json | jq -c '.status.history[] | {id, rev:.revisions[0][0:8], deployedAt, by:.initiatedBy.username}'
```
UI: http://argocd.localhost → `boutique-prod` → **HISTORY AND ROLLBACK** → voce precedente alla promozione → menu ⋮ → **Rollback** → OK.
```bash
# 4. Verifica: banner di prima, prod OutOfSync (cluster indietro rispetto a main) ma Healthy
kubectl rollout status deploy/frontend -n prod
kubectl get cm frontend-config -n prod -o jsonpath='{.data.ENV_PLATFORM}{"\n"}'   # onprem
kubectl get application boutique-prod -n argocd
./scripts/smoke-test.sh prod                         # OK con WARN sync=OutOfSync
```
Dopo il merge del revert prod torna **Synced** da solo, senza nuova sync: Git e cluster coincidono di nuovo.

Perché non `kubectl rollout undo` (da dire, o mostrare in dev con un guasto attivo): in dev `selfHeal` lo annulla in ~8 s (provato il 17/11, runbook §4.4);
in prod crea un drift che il prossimo sync cancella. Il rollback che tiene è in Git.

## Passo 10 — Krateo: un team chiede un ambiente
Prima del colloquio (una volta, ~4 minuti): `./scripts/krateo-poc.sh` deve finire con `boutique-service True True`.
Se si ferma su "fs.inotify.max_user_instances is 128": lanciare i due comandi `sudo` che stampa (D-32).
Aprire `docs/KRATEO.md` §5 (diagramma) mentre si eseguono i comandi.
```bash
kubectl config current-context                                   # kind-boutique

# 1. La piattaforma ha messo a catalogo un "servizio": Kubernetes ha un tipo nuovo, generato dallo schema del chart
kubectl get compositiondefinition -n boutique-catalog            # boutique-service  True  True
kubectl explain boutiqueservice.spec                             # i soli campi che un team può scegliere

# 2. Una richiesta sbagliata viene rifiutata dall'API server (dry-run: non crea nulla)
sed -e 's/tier: standard/tier: gold/' -e 's/namespace: team-a$/namespace: dev/' deploy/krateo/examples/team-a.yaml \
  | kubectl apply --dry-run=server -f -                          # "is invalid": Unsupported value "gold", namespace should match '^team-…'

# 3. La richiesta giusta: ~20 righe
cat deploy/krateo/examples/team-a.yaml
kubectl apply -f deploy/krateo/examples/team-a.yaml

# 4. Krateo crea namespace e Application; da lì è Argo CD (come dev e prod). Healthy in ~1 minuto
kubectl get boutiqueservice -n boutique-catalog                  # READY True
kubectl get ns team-a --show-labels | tr ',' '\n' | grep -E 'owner|tier'
kubectl get application boutique-team-a -n argocd -w             # Ctrl+C quando è Synced / Healthy
curl -s -o /dev/null -w '%{http_code}\n' http://team-a.boutique.localhost/   # 200 (anche nel browser)

# 5. Il team restituisce l'ambiente: sparisce tutto in ~20 s
kubectl delete boutiqueservice team-a -n boutique-catalog
kubectl get ns team-a                                            # NotFound (dopo qualche secondo)
```
Da dire: Krateo possiede la **richiesta** (namespace e Application), Argo CD possiede l'**app**; lo schema è il modulo del portale,
che qui non è installato perché la piattaforma completa chiede 12 vCPU / 16 GiB. Rischio da citare: il core-provider ha di fatto permessi da cluster-admin.

## Passo 11 — Un caso concreto di uso dell'AI
Caso: **Argo CD non raggiunge GitHub** (voce AI-019), scheda completa in [AI_USAGE §4](AI_USAGE.md#4-caso-esemplare-passo-11-della-demo-argo-cd-non-raggiunge-github).
Schema da raccontare: input → ragionamento → output → verifica → valore.
```bash
# Lo stesso nome, risolto da due pod di Argo CD: senza correzione (ndots:5) e con la correzione (ndots:1, deploy/platform/argocd-values.yaml)
kubectl exec -n argocd deploy/argocd-server -c server -- getent hosts github.com             # sulla rete di casa: 127.0.0.1 github.com.<dominio del router>
kubectl exec -n argocd deploy/argocd-repo-server -c repo-server -- getent hosts github.com   # IP vero di GitHub
kubectl exec -n argocd deploy/argocd-repo-server -c repo-server -- cat /etc/resolv.conf      # search ereditati dalla rete + options ndots:1
grep -n -B4 -A3 'ndots' deploy/platform/argocd-values.yaml                                    # la correzione, con il perché nel commento
```
Da dire: "L'AI ha letto `127.0.0.1` come un problema di DNS e non di rete, ha confrontato il DNS del cluster con il `resolv.conf` del pod e trovato i domini
di ricerca del router ereditati fino al pod. Ho scelto la correzione dentro il repo (riproducibile) invece che su Docker o WSL. Lo stesso sintomo è tornato con Krateo
e l'abbiamo riconosciuto in pochi minuti." Poi una frase di governance: cosa l'AI **non** può fare da sola (sudo, merge, prod, password) e gli errori fermati ([AI_USAGE §5](AI_USAGE.md#5-errori-dellai-e-chi-li-ha-fermati)).
Su un'altra rete il primo comando può restituire l'IP giusto: il guasto dipende dal router, la correzione no.

## Piano B
- **Cluster pronto prima**: riavviare il PC almeno un'ora prima, poi [Prima della demo](#prima-della-demo); non reinstallare da zero il giorno della demo.
- **Un passo si blocca**: lasciarlo, spiegare cosa ci si aspettava e mostrare l'esito registrato nel [runbook](RUNBOOK.md) o nell'[uso dell'AI](AI_USAGE.md); riprendere dal passo successivo.
- **Rete o GitHub non disponibili** (passi 7 e 9): mostrare le PR già fatte (`gh pr list -R gverro/microservices-demo --state merged --limit 20`) e il rollback del runbook §4.
- **RAM al limite al passo 10**: `docker stats --no-stream`; se il nodo supera ~8,5 GiB, mostrare `docs/KRATEO.md` §5 e la richiesta `deploy/krateo/examples/team-a.yaml` senza applicarla.
- **Video**: registrazione di una prova completa, da usare solo se il PC non collabora.

## Prove della demo
| Prova | Data | Durata | Passi riusciti | Inciampi e correzioni |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
