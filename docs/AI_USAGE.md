# Uso dell'AI nella challenge

Questo documento risponde ai §6 e §8 della challenge: quali strumenti di AI ho usato, per quali problemi, con quale approccio,
cosa ho accettato, modificato o scartato, come l'ho verificato, quali limiti ho trovato e che valore ne è venuto.
È la sintesi del **registro completo** ([`ai-log/AI_USAGE_LOG.md`](ai-log/AI_USAGE_LOG.md)), scritto durante il lavoro, una voce
per ogni contributo significativo (AI-001 … AI-0xx). Ogni affermazione qui sotto rimanda a una voce che contiene i dettagli.

Regola di fondo: **l'AI propone ed esegue, io approvo le scelte e le azioni rischiose, e niente viene dichiarato "funziona" senza
un comando che lo dimostri**. Il registro riporta anche gli errori dell'AI, perché sono la prova che i controlli funzionano.

## 1. In sintesi

| | |
|---|---|
| Strumento | **Claude Code** (CLI, modello Claude Opus 5.5) in WSL2, unico strumento AI usato. Accesso al web solo per leggere documentazione ufficiale e API di GitHub |
| Periodo | 10/11/2026 – consegna; registro con una voce per contributo |
| Ambiti coperti (§6) | analisi, implementazione, operations e troubleshooting, documentazione e demo, governance: tutti con più voci (tabella §3) |
| Casi di troubleshooting | 10, dal Docker installato via snap (AI-003) al DNS del router che risponde `127.0.0.1` (AI-019, AI-029, AI-033) |
| Revisioni indipendenti | 8 giri su 7 fasi, a ogni chiusura (subagent `revisore` in sola lettura, contesto separato); la F3 ne ha avuti due |
| Errori dell'AI registrati | 25, ognuno fermato da me, da uno strumento (shellcheck, test, CI) o da una prova reale (elenco al §5) |
| Azioni lasciate all'umano | comandi `sudo`, merge su `main`, promozione e rollback di prod, cancellazione del cluster, password e chiavi |

## 2. Strumenti e configurazione

Claude Code lavora nel terminale: legge file, lancia comandi e scrive codice, con permessi configurati per comando.
La configurazione sta nella mia workspace di lavoro, fuori da questo repo, perché contiene percorsi e preferenze personali. Ne riporto qui il contenuto rilevante.

| Componente | Cosa fa | Perché |
|---|---|---|
| `CLAUDE.md` (istruzioni di progetto) | Regole non negoziabili: verità e verifica (VERIFICATO / DA VERIFICARE / IPOTESI), nessun secret in Git o nei prompt, contesto `kind-*` controllato prima di ogni `apply`/`install`, nessun comando distruttivo senza conferma, modifiche minime all'upstream, registro AI, una fase alla volta | Le regole valgono a ogni sessione, senza doverle ripetere |
| Permessi (`settings.json`) | **allow**: solo lettura e validatori (`kubectl get/describe/logs`, `helm lint/template`, `kubeconform`, `shellcheck`, `git status/diff/log`). **ask**: tutto ciò che cambia lo stato (`kubectl apply/delete/patch/scale`, `helm install/upgrade/rollback`, `kind create/delete`, `git commit/push`, `rm`). **deny**: `sudo`, `git push --force`, lettura di `.env`, `*.key`, `*.pem` | Ciò che può fare danni passa sempre da una mia conferma |
| Skill (procedure ripetibili) | `/avvia-fase` e `/chiudi-fase` (contesto, criteri, piano, verifiche, revisione), `/troubleshoot` (sintomo → ipotesi → evidenze → causa → rimedio → verifica), `/log-ai`, `/spiega` | Lo stesso metodo in ogni fase: piano approvato prima del codice, criteri rieseguiti prima di chiudere |
| Subagent `revisore` | Revisione in sola lettura con un contesto separato, rispetto ai requisiti: correttezza, sicurezza, riproducibilità, semplicità, documentazione | Chi ha scritto il codice non vede i propri errori. Il revisore è anch'esso un modello, quindi i suoi rilievi vengono verificati prima di correggere |
| Memoria persistente | Regole nate da errori: niente `rm` su percorsi con variabili (AI-005, AI-009, AI-013), `--repo` del fork su ogni `gh` (AI-030), `git -C` invece di `cd` | Lo stesso errore non si ripete nella sessione successiva |
| Classifier di Claude Code | Blocco automatico di azioni rischiose: export della chiave di Sealed Secrets (AI-014), merge senza review (AI-018, AI-024) | Un secondo recinto, indipendente dai permessi. Non è mai stato aggirato: l'azione è tornata a me |

Ciclo di ogni fase: contesto e stato reale, letti con comandi in sola lettura → criteri di accettazione verificabili → piano con alternative →
**mia approvazione** → esecuzione → verifica con comandi → revisione indipendente → correzioni in PR con CI verde → chiusura.

Prompt e approccio, con esempi presi dal registro:
- **Richieste aperte, con vincoli espliciti**: "analizza il documento nella cartella; capire se vale la pena proseguire e se va bene l'AI" (AI-001);
  "struttura come un libro/guida, ordine per rifarlo a mano, diagrammi" (AI-016).
- **Procedure al posto dei prompt ripetuti**: `/avvia-fase <n>` (piano con criteri prima del codice), `/troubleshoot <sintomo>` (diagnosi in sola lettura),
  `/chiudi-fase <n>` (criteri rieseguiti più revisione). Il prompt diventa un metodo fisso e la sua qualità non dipende da come lo scrivo quel giorno.
- **Correzioni dirette sui comandi**: "attenzione con i comandi di rm" (AI-013). Diventano regole nella memoria persistente.
- **Criteri che chiedono la prova**: ogni piano contiene il comando di verifica di ogni passo, e la chiusura di fase li riesegue. È così che l'AI stessa ha
  ritirato due dichiarazioni premature (AI-027, AI-033).

## 3. Casi d'uso per ambito (§6.1 – §6.5)

### 3.1 Analisi iniziale
| Voce | Problema | Cosa ha fatto l'AI | Come è stato validato |
|---|---|---|---|
| AI-001 | Capire richieste, pesi e scadenza della challenge | Sintesi del PDF, matrice dei requisiti R-01..R-26 | Matrice confrontata sezione per sezione con il PDF (AI-004) |
| AI-007 | Architettura di Online Boutique (11 servizi, 5 linguaggi) | Mappa di servizi, porte, protocolli e flussi → `ARCHITECTURE.md` | Porte confrontate con `kubectl get svc`; flussi riletti sul codice (`frontend/handlers.go`, `checkoutservice/main.go`) |
| AI-011 | Come esporre il frontend su kind in WSL2 | Lettura delle fonti ufficiali; segnalato il ritiro di ingress-nginx; trovati 3 punti non ovvi (distroless senza digest, `REDIS_ADDR` con password senza toccare il C#, porte effimere di cloud-provider-kind) | Citazioni delle fonti nel diario; ipotesi marcate e poi provate |
| AI-032 | Krateo è fattibile su 10 GB? | Requisiti ufficiali (12 vCPU / 16 GiB) confrontati con le misure reali (un ambiente ~0,5 GiB, non 2-3 GB come stimato); render del chart prima di installarlo | Misure da Prometheus; il render ha mostrato il rischio "core-provider ≈ cluster-admin" |

**Compreso grazie all'AI**: la struttura del repo e dei servizi, i flussi di chiamata, i rischi di deploy su WSL2 (I/O del disco, DNS, inotify).
**Validato a parte**: ogni dato architetturale è legato a un file o a un comando. Due affermazioni sono state smentite dal codice:
i flussi scritti a memoria (corretti) e la frase del README upstream sui "tassi di cambio reali" (`currencyservice` legge un JSON statico, AI-007).

### 3.2 Implementazione
| Voce | Cosa | Dove l'AI ha accelerato | Dove è stato necessario correggere, semplificare o riscrivere |
|---|---|---|---|
| AI-007, AI-012 | Cluster kind e `install.sh` idempotente | Script, configurazione di kind, lease del control plane | shellcheck SC2155 corretto. Lo script falliva con il nodo fermo dopo un riavvio (trovato dal revisore, AI-010) |
| AI-015 | Chart dev/prod, Sealed Secrets, RBAC, NetworkPolicy | Opzioni del chart spente di default (render identico all'upstream) | Percorso "clone senza chiave" in un vicolo cieco (revisore). Misurando un rollout: prod **non** era senza disservizio (3 errori su 417) → `preStop` → 0 su 399 |
| AI-018 | Pipeline CI (lint, kubeconform, test, build, Trivy, GHCR) | Workflow completo, prova negativa con un manifest rotto (run rosso voluto) | Actions fissate per SHA dopo l'incidente di `trivy-action` trovato con la ricerca sulle versioni; due scelte rimesse a me (`-copylocks=false`, soglia di Trivy) |
| AI-024 | Metriche del frontend in Go + test, ServiceMonitor, dashboard | `metrics.go` con test, porta separata | Il test ha trovato un errore dell'AI (3 serie attese invece di 4) |
| AI-029, AI-030 | `smoke-test.sh`, `fault.sh`, rollback | 4 guasti ripetibili nonostante `selfHeal` | 9 errori di progetto corretti dalle prove (§5), tra cui una NetworkPolicy "in più" che non può bloccare nulla, perché le policy si sommano |
| AI-032, AI-034 | Golden path Krateo (chart con `values.schema.json`) | Chart, schema, CI che lo pubblica | Il revisore ha trovato due difetti reali (un team poteva prendersi l'host di dev; prod a 1 replica) → chart 0.1.1 |

### 3.3 Operations e troubleshooting
Il caso più completo è descritto al §4. Gli altri, tutti con evidenze nel registro:

| Voce | Sintomo | Causa trovata | Rimedio |
|---|---|---|---|
| AI-003 | `group 'docker' does not exist` | Docker installato come snap | Docker Engine ufficiale |
| AI-008 | `git clone` fallito su `/mnt/c` (`chmod … Operation not permitted`) | mount drvfs senza `metadata` | Repo nel filesystem Linux + symlink (D-14) |
| AI-012 | Restart di servizi e del control plane all'installazione | I/O del disco WSL2 → etcd lento → lease perso e probe in timeout (ipotesi NetworkPolicy scartata con i dati) | Lease più lunghi; confermato da un'installazione da zero con 0 restart |
| AI-020 | `404 page not found` nel browser dopo il riavvio del PC | Traefik ripartito ma non ancora pronto (liveness fallita, 2 restart): non era un guasto | Nessun intervento; sezione "Dopo un riavvio" nella checklist della demo |
| AI-023 | Exit 137 dopo il riavvio del PC | **Riprodotto** con `docker restart` del nodo: liveness con timeout di 1 s su CPU contesa, nessuna startupProbe | `startupProbe` opzionale nel chart (D-29); due avvii a freddo senza kill |
| AI-025 | Grafana 503, nodo al 615% di CPU | Limite di memoria scelto dall'AI troppo basso: la page cache conta nel limite (≈1 TB letto in 1 h, refault nei cgroup) | Limite fissato dopo una misura reale |
| AI-029 | `connection refused` su `127.0.0.1` invece di un errore DNS | Stessa causa di AI-019, vista da un altro servizio | Documentata nel runbook |
| AI-033 | CompositionDefinition di Krateo mai Ready | (1) `too many open files`: inotify a 128; (2) `dial tcp 127.0.0.1:443` verso ghcr.io: ancora il DNS | sysctl (D-32) lanciato da me; MutatingAdmissionPolicy `ndots:1` (D-33) |
| AI-035 | Script dichiarato pronto con `READY False` | `kubectl wait` leggeva il Ready della versione precedente | Attesa del controller della nuova versione |

Metodo comune: prima le evidenze in sola lettura (eventi, `describe`, log `--previous`, cgroup, `resolv.conf`), poi l'ipotesi, poi la prova che la conferma o la scarta.
Niente riavvii "per vedere se passa".

### 3.4 Documentazione e demo
- `README`, `ARCHITECTURE`, `SECURITY`, `RUNBOOK`, `KRATEO`, `CHANGES`, `DECISIONS` scritti con l'AI. **Ogni comando dei documenti è stato eseguito**
  e l'output reale è stato riportato (AI-020, AI-030). Quando un comando è stato ricostruito dalla documentazione e non eseguito, è indicato.
- Checklist della demo con comandi copia-incolla, provati durante le fasi (AI-020, AI-026, AI-030). Il passo §H è stato corretto dopo una prova:
  la `curl` colpiva il pod nei 5 s di `preStop`.
- Le revisioni hanno trovato documentazione non allineata al codice: una frase falsa nel README (AI-021), un criterio scritto meglio di quanto
  fosse dimostrato (AI-027), un runbook che diceva "ogni comando eseguito" senza che lo fosse tutto (AI-031). Tutto corretto prima della chiusura delle fasi.

### 3.5 Governance personale
| Controllo richiesto (§6.5) | Come l'ho applicato | Prova |
|---|---|---|
| Verificare gli output | Etichette VERIFICATO / DA VERIFICARE / IPOTESI; ogni "funziona" accompagnato da un comando; revisione indipendente a ogni fase | AI-027: "verified" scritto in una PR prima della prova → accortomi, prova eseguita e PR corretta. AI-033: "funziona" ritirato dopo aver visto 9 riavvii in 31 minuti |
| Evitare comandi distruttivi non compresi | Permessi `ask`/`deny`; conferma esplicita per cancellare o ricreare il cluster | Tre comandi con `rm` (anche `docker rm -f`) fermati da me (AI-005, AI-009, AI-013) → regola in memoria |
| Non inserire secret nei prompt | Le password di Argo CD e Grafana le stampano script che lancio io; l'AI non le legge | AI-020: rifiutata una prova di login automatica che avrebbe usato la password. AI-014: export della chiave bloccato e rimesso a me |
| Validare manifest e script prima di eseguirli | `helm lint`, `helm template \| kubeconform -strict`, `shellcheck`, `go test` in locale e in CI; `kubectl apply --dry-run=server` per i manifest Krateo | Run rosso voluto della CI con un manifest rotto (AI-018) |
| Distinguere il plausibile dal funzionante | Le versioni si leggono dalle API ufficiali, non dalla memoria del modello; le diagnosi si confermano riproducendo il guasto | AI-005: kubectl fuori dalla version skew trovato così. AI-023: guasto riprodotto invece di supposto |
| Privacy | Nessun dato personale nel repo pubblico: il dominio della rete di casa è sostituito da `<dominio-del-router>` (AI-031), anche nel registro pubblicato | `grep` prima della pubblicazione (vedi testa del registro) |

## 4. Caso esemplare (passo 11 della demo): Argo CD non raggiunge GitHub

Voce **AI-019** (13/11, F3). È il caso che mostro dal vivo, perché la causa non era ovvia e lo stesso meccanismo è tornato altre due volte (AI-029, AI-033).

- **Input**: dopo l'installazione di Argo CD, l'Application `boutique-dev` era `Unknown` con questa condizione:
  `ComparisonError … Get "https://github.com/…/info/refs": dial tcp 127.0.0.1:443: connect: connection refused`.
  Ho chiesto all'AI una diagnosi con il metodo `/troubleshoot`, usando solo comandi in lettura.
- **Ragionamento**: `127.0.0.1` vuol dire che il nome è stato risolto, ma in un indirizzo sbagliato: è un problema di DNS, non di rete.
  Il DNS del cluster funzionava (`nslookup github.com` da un pod → IP di GitHub). Nel `resolv.conf` del repo-server c'erano `ndots:5` e i domini di
  ricerca della rete di casa, ereditati da Windows → WSL → Docker → nodo kind → pod. Con `ndots:5` un nome con meno di 5 punti viene provato **prima**
  con i domini di ricerca: `github.com.<dominio-del-router>`. Il router risponde `127.0.0.1` per qualsiasi nome nel suo dominio, quindi quella risposta vince.
- **Output**: catena causa → effetto su 5 livelli (router → WSL → Docker → kubelet → pod) e tre rimedi possibili. **Scelto**: `ndots: 1` solo sul
  repo-server ([`deploy/platform/argocd-values.yaml`](../deploy/platform/argocd-values.yaml), D-24), nel repo e quindi riproducibile.
  **Scartati**: `dns-search` nel `daemon.json` di Docker o in WSL (serve `sudo`, sta fuori dal repo, chi clona non lo eredita) e una regola CoreDNS
  per il dominio del router (dipende dalla rete).
- **Verifica**: rilancio di `install.sh` → Application Synced/Healthy. Oggi lo si può rivedere sullo stesso cluster, confrontando un pod senza la correzione
  (`argocd-server`, `ndots:5`) con il repo-server (`ndots:1`):
  ```bash
  kubectl exec -n argocd deploy/argocd-server -c server -- getent hosts github.com            # senza correzione
  kubectl exec -n argocd deploy/argocd-repo-server -c repo-server -- getent hosts github.com  # con ndots:1
  ```
  Esito il 19/11 sulla rete usata per la challenge (dominio oscurato):
  ```
  127.0.0.1       github.com.<dominio-del-router>
  140.82.121.3    github.com
  ```
  Su una rete il cui router non risponde per il proprio dominio entrambi i comandi restituiscono l'IP di GitHub: il guasto dipende dalla rete, la correzione no.
- **Valore**: guasto bloccante risolto con una causa dimostrata, non per tentativi. In F6 lo stesso sintomo verso `ghcr.io` è stato riconosciuto
  in pochi minuti (AI-033), e lì la correzione ha richiesto un altro strumento (MutatingAdmissionPolicy, D-33), perché quei pod li crea Krateo a runtime.
- **Limite**: perché il router risponda così è dedotto dal comportamento osservato, non dalla sua documentazione.

## 5. Errori dell'AI e chi li ha fermati

L'AI ha sbagliato. Il punto è che ogni errore è stato fermato prima di arrivare nella soluzione finale. Elenco completo dal registro:

| Voce | Errore dell'AI | Fermato da |
|---|---|---|
| AI-005, AI-009, AI-013 | Comandi con `rm` su percorsi con variabili; `docker rm -f` non segnalato | Me, in revisione del comando |
| AI-007 | SC2155 nello script; flussi dell'architettura scritti a memoria | shellcheck; rilettura del codice |
| AI-024 | Test con 3 serie attese invece di 4 | `go test` |
| AI-025 | Limite di memoria di Grafana scelto "a occhio" | Sintomo (503) e misure dei cgroup |
| AI-026 | Immagine di prova locale al posto di quella pubblicata; un `grep` che nascondeva un `Error:` di Helm | Confronto degli ID immagine; exit code |
| AI-027 | "Verified" scritto in una PR prima di fare la prova | L'AI stessa in chiusura, poi la prova |
| AI-029 | 4 errori nei guasti (policy "in più", crash previsto e non avvenuto, `updatedReplicas`, selettore di `kubectl wait`) | Le prove dei guasti |
| AI-030 | 5 errori nei rollback (tag "inesistente" che la CI avrebbe pubblicato, `gh` diretto all'upstream, revert del merge, banner letto dal posto sbagliato, `curl` sul pod in chiusura) | Lettura di `ci.yaml`; comando fallito senza effetti; prove ripetute |
| AI-031 | `trap` con `\\n` letterale | Prova prima del commit |
| AI-032 | `helm registry logout` usato per "ispezionare" le credenziali | Verifica successiva: niente rimosso |
| AI-033 | "Funziona" dichiarato a 48 s; memoria del motore misurata durante un crash | Eventi (9 riavvii); misura ripetuta |
| AI-034 | `yq` tra i prerequisiti, non installato | Prova dello script |
| AI-035 | Correzione dell'attesa dello script insufficiente | Prova reale dell'aggiornamento |

In più ci sono i rilievi delle revisioni indipendenti (AI-006, AI-010, AI-015, AI-021 con due giri, AI-027, AI-031, AI-034). Ogni rilievo è stato corretto o, con una mia decisione, accettato come limite dichiarato. Esempio: in F0 alcuni `deny` sui permessi non sono stati applicati e resta la conferma `ask` (AI-006).

## 6. Limiti riscontrati
- **La memoria del modello invecchia.** Versioni e comportamenti dei tool vanno letti dalla documentazione ufficiale (es. kubectl fuori dalla skew in AI-005, ritiro di ingress-nginx in AI-011).
- **Fretta di dichiarare il successo.** Due volte l'AI ha scritto "verificato" prima della prova (AI-027, AI-033). Contromisura: criteri che guardano i minuti successivi (riavvii, eventi), non il primo `Running`.
- **Dimensionamento a occhio.** Limiti e stime di RAM sbagliati finché non sono state fatte misure (AI-025, AI-032).
- **Una regola nota non basta.** La regola su `rm` era nota ed è stata violata (AI-009): la conferma umana sui comandi resta necessaria.
- **La stessa AI scrive e verifica.** Mitigazione: revisore con un contesto separato e mia approvazione. Il revisore però è anch'esso un modello: i rilievi si verificano, non si accettano a scatola chiusa (AI-006).
- **Lacune del registro.** Le prime voci (AI-002, AI-003, AI-004) non hanno il prompt registrato: lo dichiaro invece di ricostruirlo a memoria.

## 7. Valore prodotto
- **Implementazione**: chart, script, pipeline, metriche e golden path dalla F0 alla F6 in 9 giorni di calendario (10-18/11), con test e validatori fin dalla prima versione.
- **Troubleshooting**: 10 guasti reali diagnosticati con evidenze. Tre comportamenti non ovvi sono diventati scenari del runbook: rolling update che nasconde un'immagine rotta,
  connessioni gRPC già aperte che nascondono un Service vuoto, DNS che "mente" (AI-029).
- **Operations**: rischi per la demo trovati prima del colloquio (script che falliva dopo un riavvio, `install.sh` che si sarebbe fermato 10 minuti a metà demo: AI-010, AI-021).
- **Documentazione**: documenti allineati al codice e comandi provati. Le revisioni hanno tolto frasi false prima della consegna.
- **Responsabilità**: l'AI ha accelerato tutto, ma ogni scelta di progetto, ogni azione su `main` e su prod e ogni credenziale sono rimaste a me.
