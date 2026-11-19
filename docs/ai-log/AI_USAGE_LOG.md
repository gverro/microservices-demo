# Registro dell'uso dell'AI (appendice)

Copia del registro tenuto durante il lavoro, una voce per ogni contributo significativo dell'AI. La sintesi per ambito è in [`../AI_USAGE.md`](../AI_USAGE.md).

Note per chi legge:
- Le voci sono state scritte sul momento e non sono state riscritte dopo. Le lacune (es. prompt non registrato) sono dichiarate nella voce stessa.
- **Unica modifica rispetto all'originale**: il dominio di ricerca della rete di casa è sostituito da `<dominio-del-router>` (privacy, come in `docs/DECISIONS.md` D-24).
  Prima della pubblicazione il registro è stato controllato con `grep` per email, token, password e percorsi personali: nessuna occorrenza.
- I rimandi a file come `docs/03-REQUISITI.md`, `docs/05-DECISIONI.md`, `notes/diario/…` o `demo/DEMO_CHECKLIST.md` riguardano la mia workspace di lavoro, fuori da questo repo.
  Le decisioni D-xx sono riportate in [`docs/DECISIONS.md`](../DECISIONS.md), la demo in [`docs/DEMO.md`](../DEMO.md).

Schema di ogni voce (vedi skill `/log-ai`): Data/Fase/Ambito · Strumento · Problema · Prompt/approccio ·
Output · Decisione · Verifica · Valore · Limiti.
Per i casi di troubleshooting sono ammessi anche i campi Sintomo · Evidenze · Diagnosi · Rimedio (formato `/troubleshoot`).
Se un campo non era stato registrato sul momento lo dichiariamo come lacuna, senza ricostruirlo a memoria.
Strumento usato finora: **Claude Code** (modello Claude Opus 5.5) in WSL2.

---

### AI-001 — Analisi iniziale della challenge
- **Data / Fase / Ambito**: 10/11/2026 · F0 · Analisi
- **Strumento**: Claude Code (Claude Opus 5.5).
- **Problema**: capire requisiti, scadenza, ammissibilità dell'AI e fattibilità.
- **Prompt / approccio**: "analizza il documento nella cartella; capire se vale la pena proseguire e se va bene l'AI".
- **Output**: sintesi dei requisiti, calcolo della scadenza (06/11 + 10 giorni → 16/11), conferma che l'AI è ammessa e
  richiesta (§6, §10), lettura dei pesi di valutazione (troubleshooting e analisi = 38%).
- **Decisione**: Accettato.
- **Verifica**: DA VERIFICARE: Gabriele rilegge il PDF e conferma i punti chiave.
- **Valore**: lettura ragionata di 7 pagine e priorità chiare in pochi minuti.
- **Limiti**: l'ipotesi "Kiratech = autore di Krateo" era una deduzione dell'AI, poi confermata dall'utente.

### AI-002 — Stesura della mail di risposta
- **Data / Fase / Ambito**: 10/11/2026 · F0 · Documentazione/comunicazione
- **Strumento**: Claude Code (Claude Opus 5.5).
- **Prompt / approccio**: non registrato al momento (lacuna: voce scritta prima di applicare lo schema completo).
- **Problema**: confermare la ricezione, chiedere una proroga realistica e chiarimenti, senza affermazioni non vere.
- **Output**: bozza con richiesta di consegna al 23/11 e 3 domande (kind, demo dal vivo, PoC Krateo); stima di circa 10 giorni lavorativi.
- **Decisione**: inviata dall'utente (eventuali modifiche apportate: DA COMPLETARE a cura di Gabriele).
- **Verifica**: stima confrontata con il piano di fase (`docs/01-SINTESI.md`).
- **Valore**: comunicazione rapida e senza promesse non verificate.
- **Limiti**: la stima dei giorni è dell'AI; resta da confermare con l'avanzamento reale.

### AI-003 — Troubleshooting: `usermod: group 'docker' does not exist`
- **Data / Fase / Ambito**: 10/11/2026 · F0 · Operations/Troubleshooting
- **Strumento**: Claude Code (Claude Opus 5.5).
- **Prompt / approccio**: non registrato al momento (lacuna: voce scritta prima di applicare lo schema completo); l'AI ha raccolto evidenze solo con comandi in lettura.
- **Sintomo**: `docker info` → `permission denied ... /var/run/docker.sock`; poi `usermod -aG docker $USER` → `group 'docker' does not exist`.
- **Evidenze raccolte dall'AI**: `which docker` → `/snap/bin/docker` (installazione via snap); socket `root:root`;
  `systemctl is-active docker` → `inactive` (nessun servizio Docker Engine di sistema).
- **Diagnosi**: Docker installato come snap, che non crea il gruppo `docker` e usa un isolamento noto per creare problemi con kind.
- **Rimedio proposto**: rimuovere lo snap e installare Docker Engine ufficiale (script get.docker.com, da leggere prima di eseguirlo), poi aggiungere l'utente al gruppo `docker` e riavviare WSL.
- **Decisione**: Accettato; snap rimosso dall'utente (verificato: `docker: command not found` il 10/11).
- **Verifica**: VERIFICATO il 10/11: `docker run --rm hello-world` → "Hello from Docker!"; Docker Engine 29.9.3 da repo apt ufficiale.
- **Valore**: evitata una configurazione fragile che avrebbe causato errori più oscuri con kind.
- **Limiti**: la diagnosi "snap problematico con kind" si basava su conoscenza generale dell'AI, non su una prova riprodotta qui.

### AI-004 — Setup della workspace e della configurazione AI
- **Data / Fase / Ambito**: 10/11/2026 · F0 · Governance/Documentazione
- **Strumento**: Claude Code (Claude Opus 5.5).
- **Problema**: impostare un metodo di lavoro verificabile e un uso dell'AI con permessi espliciti prima di scrivere codice.
- **Prompt / approccio**: non registrato al momento (lacuna: voce scritta prima di applicare lo schema completo).
- **Output**: `CLAUDE.md`, `.claude/settings.json` (allow/ask/deny), 5 skill, subagent `revisore`, matrice dei requisiti, ADR, principi, glossario.
- **Decisione**: DA RIVEDERE da parte di Gabriele.
- **Verifica**: matrice R-01..R-26 confrontata sezione per sezione con il PDF; validità JSON di `settings.json` VERIFICATA (parsing con Python: OK).
- **Valore**: regole e tracciabilità pronte dal primo giorno.
- **Limiti**: la revisione di fine fase 0 (subagent `revisore`) ha trovato permessi più ampi del dichiarato in
  `.claude/settings.local.json` (`docker run *`, `gh auth *`) e in `settings.json` (`git branch:*`, deny di `git push --force` aggirabile). Vedi AI-006.

### AI-005 — Installazione dei tool con versioni fissate e smoke test del cluster
- **Data / Fase / Ambito**: 10-11/11/2026 · F0 · Analisi/Operations
- **Strumento**: Claude Code (Claude Opus 5.5).
- **Problema**: installare kind, kubectl, helm, kubeconform, shellcheck e gh in modo riproducibile e verificabile.
- **Prompt / approccio**: `/avvia-fase 0`; l'AI legge le versioni dalle API ufficiali (GitHub releases, dl.k8s.io) invece che dalla memoria,
  scarica i binari nella propria scratchpad e ne verifica il checksum; i comandi `sudo` e il login li esegue Gabriele.
- **Output**:
  - trovato che kubectl snap v1.35 era fuori dalla version skew rispetto al nodo kind v1.37 → sostituito con binario v1.37.2;
  - SHA-256 verificati per kubectl, kind, helm, kubeconform; impronte GPG del repo gh confrontate con la doc ufficiale;
  - cluster `smoke` creato con node image fissata per digest, nodo Ready, poi cancellato.
- **Decisione**: Accettato, con due correzioni dell'utente:
  - **Scartato** un comando dell'AI con `rm -rf $D` (variabile non tra virgolette): Gabriele lo ha bloccato perché una
    variabile vuota poteva cancellare il percorso sbagliato. Rifatto senza `rm`, con `mktemp -d`. Regola salvata nella memoria dell'AI.
  - Mini-troubleshooting: il primo comando `! sudo snap remove … && sudo install …` lanciato in un terminale normale ha rimosso lo snap
    ma non installato kubectl. Diagnosi dell'AI: in bash `!` nega l'exit code, quindi `&&` ha saltato il resto. Rimedio: rilanciare senza `!`.
- **Verifica**: `kind version`, `helm version --short`, `kubeconform -v`, `shellcheck -V`, `gh --version`, `gh auth status`;
  `kubectl version` → client v1.37.2 / server v1.37.0; `kubectl get nodes` → Ready; `kind get clusters` → nessun cluster residuo.
- **Valore**: errore di version skew evitato prima che causasse problemi oscuri; integrità dei binari dimostrabile.
- **Limiti**: l'AI aveva proposto un comando potenzialmente distruttivo, intercettato dalla revisione umana. È una prova che serve la conferma umana sui comandi.

### AI-006 — Revisione indipendente di fine fase 0
- **Data / Fase / Ambito**: 11/11/2026 · F0 · Governance/Revisione
- **Strumento**: Claude Code, subagent `revisore` (sola lettura, contesto separato).
- **Problema**: verificare coerenza dei documenti, onestà del log, assenza di secret e coerenza dei permessi AI con CLAUDE.md.
- **Prompt / approccio**: `/chiudi-fase 0` → delega al revisore con 5 punti di controllo e richiesta di rilievi con gravità e file:riga.
- **Output**: 15 rilievi (3 alti, 7 medi, 5 bassi). I più importanti: permessi AI troppo ampi; token gh leggibile in
  `~/.config/gh/hosts.yml` e non coperto dai deny; versione di shellcheck incoerente nel diario; log AI non conforme allo schema.
- **Decisione**: rilievi documentali corretti dall'AI principale (versioni, scope, ADR, fonte Helm, schema del log);
  rilievi sui permessi **sottoposti a Gabriele** perché toccano la configurazione di sicurezza dell'AI.
  Scelta di Gabriele: ristretti gli allow locali (`docker run --rm hello-world`, `gh auth status`); deny su credenziali
  e su varianti di `git push --force` **non applicati** (limite residuo: resta la conferma umana di `ask`); `apt-mark hold` eseguito da Gabriele; scope `gist` mantenuto.
- **Verifica**: l'AI principale ha ricontrollato i rilievi chiave (lettura dei file settings, `gh auth status`) e la fonte Helm
  (https://helm.sh/blog/helm-4-released/: fix di sicurezza Helm 3 fino all'11/11/2026).
- **Valore**: trovato un divario reale tra "cosa dichiaro" e "cosa è configurato", che un intervistatore avrebbe notato.
- **Limiti**: il revisore è anch'esso un modello AI; i rilievi vanno verificati, non accettati a scatola chiusa.


### AI-007 — Fase 1: fork, cluster, primo deploy e analisi dell'architettura
- **Data / Fase / Ambito**: 11-12/11/2026 · F1 · Analisi/Implementazione/Documentazione
- **Strumento**: Claude Code (Claude Opus 5.5).
- **Problema**: portare Online Boutique su kind in modo riproducibile e documentarne l'architettura partendo da fatti verificati.
- **Prompt / approccio**: `/avvia-fase 1` → esplorazione in sola lettura (API GitHub, chart, doc kind) → piano approvato → esecuzione.
  Dal 12/11 Gabriele chiede che l'AI guidi lo sviluppo, fermandosi solo per azioni esterne, distruttive, `sudo` o scelte di progetto.
- **Output**: fork pubblico; `kind/cluster.yaml` e `scripts/cluster-up.sh` (idempotente); deploy Helm in `dev`; `docs/ARCHITECTURE.md`
  (diagramma Mermaid, servizi, flussi, mappatura §3), `docs/CHANGES.md`, sezione README "Perché Online Boutique".
- **Decisione**: accettato. Correzioni nate dalla verifica:
  - shellcheck SC2155 trovato nella prima versione dello script → corretto;
  - flussi "home" e "checkout" scritti inizialmente a memoria → ricontrollati sul codice (`frontend/handlers.go`, `checkoutservice/main.go`): corretti;
  - affermazione del README upstream ("valori reali BCE") smentita dal codice (`currencyservice/server.js:110` legge un JSON statico) → documentata.
- **Verifica**: `helm lint`; `kubeconform` 36/36 valide; `helm list -n dev` deployed; 12/12 pod Running; `curl` → 200; `docker stats` → 1,19 GiB.
- **Valore**: fase completata in poche ore, con ogni dato dell'architettura legato a un comando o a un file.
- **Limiti**: la doc di ingress-nginx non è stata letta per intero (pagina troncata) → DA VERIFICARE in F2.

### AI-008 — Troubleshooting: `git clone` fallito su `/mnt/c`
- **Data / Fase / Ambito**: 11/11/2026 · F1 · Operations/Troubleshooting
- **Strumento**: Claude Code.
- **Problema**: `git clone` in `repo/` → `error: chmod on …/.git/config.lock failed: Operation not permitted`.
- **Approccio**: sintomo → evidenze (`mount` mostra drvfs con `uid=0` e senza `metadata`; `chmod` su un file di prova → exit 1) →
  causa: l'utente uid 1000 non è proprietario dei file sul mount e non può cambiarne i permessi; git li imposta già all'init.
- **Output**: tre opzioni presentate a Gabriele (clone nel filesystem Linux + symlink; `metadata` in `/etc/wsl.conf`; spostare la workspace).
- **Decisione**: Gabriele ha scelto il filesystem Linux + symlink (ADR D-14).
- **Verifica**: clone riuscito, `core.fileMode=true`, `ls -l repo` → symlink; `git -C repo remote -v` corretto.
- **Valore**: problema bloccante risolto in pochi minuti con una causa dimostrata, non per tentativi.
- **Limiti**: perché il mount sia `uid=0` resta un'IPOTESI (nessuna sezione `[automount]` in `/etc/wsl.conf`).

### AI-009 — Comando con `rm` su percorso con variabile, bloccato da Gabriele
- **Data / Fase / Ambito**: 12/11/2026 · F1 · Governance
- **Problema**: per aggiungere una sezione al README l'AI ha proposto file temporaneo + `mv` + `rm "$HOME/.r01.md"`.
- **Decisione**: **scartato** da Gabriele (seconda volta dopo AI-005): `rm` su percorso con variabile, vietato anche se la variabile è `$HOME`.
  Rifatto con l'editor, senza file temporanei. Regola rafforzata nella memoria dell'AI.
- **Valore / Limiti**: la regola era già nota all'AI ma è stata violata: la conferma umana sui comandi resta necessaria.

### AI-010 — Revisione indipendente di fine fase 1
- **Data / Fase / Ambito**: 12/11/2026 · F1 · Governance/Revisione
- **Strumento**: Claude Code, subagent `revisore` (sola lettura, contesto separato, accesso in lettura al cluster).
- **Problema**: verificare accuratezza tecnica dei documenti rispetto a cluster e codice, copertura del PDF §3/§8, robustezza dello script.
- **Prompt / approccio**: `/chiudi-fase 1` → delega con 6 punti di controllo; l'AI principale ha ricontrollato i rilievi chiave
  (conteggio servizi, endpoint `/product-meta`, tasso d'errore del checkout, restart policy, formato dei log, variabili d'ambiente) prima di correggere.
- **Output**: 17 rilievi (1 alto, 5 medi, 11 bassi). Il più utile per la demo: lo script falliva se il nodo kind era fermo dopo un riavvio.
  Il più utile per il colloquio: conteggio dei servizi sbagliato ("11 + load generator").
- **Decisione**: 15 corretti, 1 accettato come limite (immagini per tag), 1 aperto (render Mermaid, lo verifica Gabriele). Dettaglio nel diario F1.
- **Verifica**: shellcheck OK; `docker stop boutique-control-plane` → `cluster-up.sh` → nodo Ready in 46 s, 12/12 pod Running, `GET /` → 200.
- **Valore**: trovato un rischio concreto per la demo dal vivo e un errore fattuale che un intervistatore avrebbe notato.
- **Limiti**: il revisore è anch'esso un modello; non ha potuto verificare il rendering Mermaid.

### AI-011 — Avvio fase 2: analisi del chart, scelta dell'esposizione, piano
- **Data / Fase / Ambito**: 12/11/2026 · F2 · Analisi/Pianificazione
- **Strumento**: Claude Code (Opus 5.5), skill `/avvia-fase 2`, WebFetch sulle fonti ufficiali.
- **Problema**: pianificare build, packaging, ambienti e sicurezza minima; decidere come esporre il frontend su kind in WSL2.
- **Prompt / approccio**: lettura in sola lettura di chart, Dockerfile del frontend, `Startup.cs` di cartservice e stato del cluster;
  consultazione di kind docs (Ingress), README di cloud-provider-kind, blog Kubernetes sul ritiro di ingress-nginx.
- **Output**: piano in 7 passi con criteri verificabili (diario F2); trovati 3 punti non ovvi: distroless senza digest nel Dockerfile,
  `REDIS_ADDR` passato intero a StackExchange.Redis (password possibile senza toccare il C#, da verificare),
  cloud-provider-kind su WSL2 richiede `sudo` e usa porte effimere.
- **Decisione**: Gabriele approva extraPortMappings + Traefik e la ricreazione del cluster (D-13).
- **Verifica**: citazioni dalle fonti nel diario F2; ipotesi H1-H4 marcate come da verificare.
- **Valore**: evitata una scelta (ingress-nginx) ritirata e senza patch di sicurezza; rischio demo (porta effimera) individuato prima.
- **Limiti**: la pagina GitHub di cloud-provider-kind non mostrava l'ultima release; versioni di Traefik e Sealed Secrets da verificare all'installazione.

### AI-012 — Troubleshooting: restart di servizi e del control plane all'installazione
- **Data / Fase / Ambito**: 12/11/2026 · F2 · Operations/Troubleshooting (R-18, R-21)
- **Strumento**: Claude Code (Opus 5.5), comandi `kubectl` in sola lettura.
- **Problema**: dopo l'installazione di dev e prod, restart su recommendation/email/payment (fino a 4) e 5 restart di kube-controller-manager e kube-scheduler.
- **Prompt / approccio**: sintomo → `describe` (exit 137, liveness gRPC timeout 1s) → finestra temporale degli eventi `Unhealthy` → log `--previous`
  del control plane (`leaderelection lost`, lease non rinnovato entro 5s) → log di etcd filtrati per minuto (372 "slow fdatasync / took too long" tra 12:00 e 12:04, 4 dopo).
  Ipotesi alternativa (NetworkPolicy che blocca le probe) scartata: i pod sono diventati Ready e i contatori si sono fermati.
- **Output**: catena causale: pull ed estrazione di molte immagini → I/O del disco virtuale WSL2 → etcd lento → API lenta → perdita del lease (uscita voluta) e probe in timeout.
- **Decisione**: nessun intervento a caldo; mitigazioni proposte a Gabriele (immagini pre-caricate, lease più lunghi nel cluster a nodo singolo).
- **Verifica**: contatori fermi e nessun `Unhealthy` dopo le 12:05 (controllo in background a +3 min); lo stesso sintomo di F0 ora ha una causa con evidenze.
- **Valore**: caso concreto di troubleshooting L2 per la demo e il runbook; evitata una diagnosi sbagliata (NetworkPolicy).
- **Esito (approvato da Gabriele)**: lease 60s/40s/5s via `kubeadmConfigPatchesJSON6902` (formato verificato su `/kind/kubeadm.conf`: kubeadm v1beta4, lista).
  Test da zero: etcd ugualmente lento (354 avvisi) ma 0 restart nel cluster → la catena causale è confermata dall'esperimento.
- **Limiti**: la mitigazione aumenta la tolleranza, non elimina la lentezza del disco; con più nodi control plane i lease lunghi ritarderebbero il failover.

### AI-013 — `docker rm -f` usato per pulizia, fermato da Gabriele
- **Data / Fase / Ambito**: 12/11/2026 · F2 · Governance
- **Problema**: per testare l'immagine in locale l'AI ha inserito `docker rm -f` (prima e dopo il test) in un comando unico, senza segnalarlo.
- **Decisione**: comando rifiutato da Gabriele ("attenzione con i comandi di rm"). Rifatto con `docker run --rm` + `docker stop`: il container si rimuove da solo.
  Regola salvata nella memoria persistente dell'AI: niente comandi della famiglia `rm` (anche `docker rm -f`) se non inevitabili e confermati.
- **Valore**: terzo caso della stessa classe (vedi AI-009): il controllo umano sui comandi distruttivi funziona; la regola è ora più ampia.

### AI-014 — Export della chiave privata di Sealed Secrets bloccato dal classifier
- **Data / Fase / Ambito**: 12/11/2026 · F2 · Governance/Sicurezza
- **Problema**: per poter ricreare il cluster senza perdere i secret, l'AI voleva salvare la chiave privata del controller in `~/.config` (permessi 600).
- **Output**: il classifier di sicurezza di Claude Code ha bloccato l'azione ("credential materialization").
- **Decisione**: l'AI non ha cercato di aggirare il blocco; ha scritto `scripts/backup-sealing-key.sh` che Gabriele lancia a mano, e un ripiego
  (`seal-secrets.sh`) per i cluster nuovi senza backup. Limite L2 documentato in `SECURITY.md`.
- **Valore**: esempio di "uso governato dell'AI": le credenziali più sensibili restano un'azione esplicita dell'umano.

### AI-015 — Revisione indipendente di fine fase 2 e correzioni
- **Data / Fase / Ambito**: 12/11/2026 · F2 · Governance/Revisione
- **Strumento**: Claude Code, subagent `revisore` (sola lettura, contesto separato), in parallelo alla riesecuzione dei criteri.
- **Problema**: verificare chart, script, documenti e copertura del PDF prima di chiudere la fase.
- **Output**: 21 rilievi (1 alto, 6 medi, 14 bassi). Il più importante: il percorso di chi clona il repo senza la nostra chiave di Sealed Secrets
  finiva in un vicolo cieco (e alla seconda esecuzione non si riprendeva).
- **Decisione**: 19 corretti, 1 accettato come limite (#19 gruppo operatori → L11), 1 scartato (#17 `replicas: 0`, caso non realistico qui). Dettaglio nel diario F2.
- **Verifica**: `kubeseal --validate` su file vero (decifrabile), su file cifrato con certificato estraneo (rilevato) e vuoto (rilevato);
  `seal-secrets.sh` provato su una copia nello scratchpad; `install.sh` ×3 dopo le modifiche, exit 0; shellcheck, lint, kubeconform puliti.
- **Effetto collaterale utile**: misurando un rollout per un rilievo minore (checksum della ConfigMap) l'AI ha scoperto che prod **non** era senza disservizio
  come dichiarato (3 errori su 417) → `preStop` (D-19) → 0 su 399. Senza misura, la frase falsa sarebbe arrivata in demo.
- **Limiti**: il percorso "clone nuovo senza chiave" non è stato provato end-to-end (richiederebbe un altro cluster da zero); lo è per componenti.


### AI-016 — Mappa di preparazione al colloquio (F0-F2)
- **Data / Fase / Ambito**: 12/11/2026 · trasversale · Documentazione/Studio
- **Strumento**: Claude Code (Opus 5.5), sola lettura di diario, ADR, log AI e repo; un file nuovo scritto.
- **Problema**: il pitch "Come lo spiego al colloquio" di ogni fase non rimandava alle prove; a una domanda di dettaglio Gabriele non sapeva dove guardare.
- **Output**: `notes/manuale/A-MAPPA-COLLOQUIO.md` (spostato nel manuale): ogni frase del pitch diventa una scheda (dove lo mostro con file:riga, prova comando → esito, decisione D-xx, approfondimento AI-xx) + indice inverso "domanda → file".
- **Decisione**: DA VALIDARE da Gabriele rileggendo.
- **Verifica**: riferimenti file:riga controllati con `grep`/`sed` sul commit `39416fc8`; esiti copiati dai diari, non rieseguiti.
- **Valore**: collega racconto e evidenze, utile anche per la demo.
- **Limiti**: i numeri di riga vanno riallineati se i file cambiano nelle fasi successive.
- **Estensione (stessa sessione, su richiesta di Gabriele: "struttura come un libro/guida, ordine per rifarlo a mano, diagrammi")**:
  creato `notes/manuale/` con indice, un capitolo per F0-F2 (In breve · Quadro · Concetti · Procedura passo-passo con
  Obiettivo/Comandi/Perché/Verifica/Inciampi · Approfondimenti · Punto di arrivo · Colloquio · Verifica di comprensione),
  diagrammi Mermaid, `TEMPLATE-capitolo.md`; skill `/chiudi-fase` aggiornata per scrivere il capitolo a ogni chiusura.
  Scelta di struttura: diario = registro storico (invariato), manuale = come si fa e perché, mappa = dove sta la prova.
  Verifica: numeri di riga ricontrollati sui file (2 corretti: `cluster-up.sh:41-44`, `install.sh:94-108`).
  Limiti: comandi di F0 e alcuni di F1 (fork, primo `helm install`) ricostruiti dalla doc ufficiale e dal diario, segnalati come tali
  e non rieseguiti; render dei diagrammi Mermaid non verificato.


### AI-017 — Avvio fase 3: stato, versioni, piano CI/CD e GitOps
- **Data / Fase / Ambito**: 12/11/2026 · F3 · Analisi/Pianificazione
- **Strumento**: Claude Code (Opus 5.5), solo comandi in lettura su repo, cluster e GitHub API; scrittura di diario, capitolo, glossario.
- **Problema**: pianificare R-09 (pipeline) e R-10 (GitOps) partendo dallo stato reale di F2.
- **Output**: stato verificato (cluster, RAM 2,31 GiB, rami: `main` ancora upstream, Actions disattivato, 9 workflow upstream);
  versioni correnti da GitHub API (Argo CD v3.6.1, chart 10.18.0); piano in 7 passi con criteri e comandi di verifica; alternative scartate;
  12 termini nel glossario; scheletro del capitolo `04-fase-3-cicd-gitops.md`.
- **Decisione**: DA APPROVARE da Gabriele (piano, merge su `main`, riattivazione Actions, gestione dei SealedSecret con Argo CD).
- **Verifica**: comandi `kubectl`/`helm`/`gh`/`git` in sola lettura, riportati nel diario; ipotesi marcate (compatibilità Argo CD/k8s 1.37, value file fuori dal chart, RAM).
- **Valore**: piano legato ai criteri di accettazione; individuato in anticipo il rischio "clone senza chiave + GitOps".
- **Limiti**: la doc ufficiale di Argo CD non è ancora stata consultata per i punti marcati DA VERIFICARE.


### AI-018 — Pipeline CI: scrittura, prova negativa, problemi upstream e supply chain
- **Data / Fase / Ambito**: 12/11/2026 · F3 · Implementazione/Sicurezza
- **Strumento**: Claude Code (Opus 5.5) con `gh`, `docker`, ricerca web.
- **Problema**: costruire la pipeline di R-09 e dimostrare che blocca gli errori.
- **Output**: `ci.yaml` (lint, validate, test, build+Trivy+GHCR); rimozione workflow upstream; prova negativa con un manifest rotto; ADR D-21, D-22; CHANGES #7, #19, #20.
- **Decisione**: accettato. Due scelte dell'AI da far validare a Gabriele: `go vet -copylocks=false` (problema upstream) e soglia Trivy "CRITICAL correggibili".
- **Verifica**: controlli rieseguiti in locale prima del push; run verde 43267250772; run rosso atteso 43269182026; actionlint pulito.
- **Valore**: la ricerca sulle versioni ha fatto emergere l'incidente `trivy-action` (CVE-2026-33634) → pin per SHA motivato con un caso reale.
- **Limiti / governance**: il merge della PR #2 su `main` è stato bloccato dal classifier di Claude Code ("Merge Without Review"): azione rimessa a Gabriele.
  Resta su GitHub il ramo `feat/ci-negative-test`, da cancellare con il suo ok.


### AI-019 — Troubleshooting: Argo CD non raggiunge GitHub (DNS del router + ndots)
- **Data / Fase / Ambito**: 13/11/2026 · F3 · Operations/Troubleshooting
- **Strumento**: Claude Code (Opus 5.5), `kubectl`, pod busybox usa e getta, `docker exec` sul nodo.
- **Sintomo**: `boutique-dev` `Unknown`, condition `ComparisonError … Get "https://github.com/…/info/refs": dial tcp 127.0.0.1:443: connect: connection refused`.
- **Ipotesi e prove**: `nslookup github.com` da pod → 140.82.121.4 (DNS del cluster sano); `resolv.conf` del repo-server → search con
  `<dominio-del-router> broadband` e `ndots:5`; `nslookup github.com.<dominio-del-router>` → **127.0.0.1** (il router risponde per il suo dominio);
  nodo kind: `search <dominio-del-router> broadband` copiato da Docker/WSL.
- **Causa**: con `ndots:5` il resolver prova prima `github.com.<dominio di ricerca>`; la risposta finta del router vince.
- **Rimedio**: `repoServer.dnsConfig` `ndots: 1` nei values di Argo CD. Alternative scartate: `dns-search` in `daemon.json` di Docker o `resolv.conf` di WSL
  (sudo, fuori dal repo, non riproducibile per chi clona); regola CoreDNS per il dominio del router (dipende dalla rete).
- **Verifica**: rilancio di `install.sh` (vedi diario).
- **Valore**: caso L2 reale, con catena causa→effetto su 5 livelli (router → WSL → Docker → kubelet → pod); collegato all'anomalia DNS lasciata come ipotesi in F2.


### AI-020 — Chiusura del ciclo GitOps e documentazione della F3
- **Data / Fase / Ambito**: 16/11/2026 · F3 · Operations/Documentazione
- **Strumento**: Claude Code (Opus 5.5), `kubectl`, `curl`/`curl.exe` di Windows, `gh`, documentazione ufficiale di Argo CD.
- **Problema**: (1) 404 nel browser dopo il riavvio del PC; (2) login di Argo CD rifiutato; (3) documentare CI e GitOps nel repo consegnato.
- **Output**: (1) diagnosi: Traefik ripartito e non ancora pronto (liveness fallita, 2 restart), nessun intervento; sezione §0 "Dopo un riavvio" nella checklist.
  (2) Log del server: 3 tentativi `Invalid username or password`; la prova di login automatica proposta dall'AI è stata **rifiutata da Gabriele**
  (avrebbe usato la password, pur senza stamparla); Gabriele è poi entrato da solo. (3) README (sezione CI/CD e GitOps, badge), ARCHITECTURE §9,
  CHANGES #21-#24, DECISIONS D-23..D-27, SECURITY (misure 13-17, limiti L6, L13, L14); commit `23441398`.
- **Decisione**: accettato; le citazioni della doc di Argo CD (progetto `default`, health degli Ingress) controllate sulle pagine ufficiali il 16/11.
- **Verifica**: comandi della checklist §0 eseguiti (exit 0, tre `200`); `helm lint` dev/prod; comandi di verifica scritti in SECURITY eseguiti
  (nessun `uses:` senza SHA, nessun secret di repository in Argo CD, `clusterResourceWhitelist` `[]`, `exec.enabled` `false`).
- **Governance**: la password di Argo CD non è mai stata letta né usata dall'AI: limite rispettato anche quando avrebbe accelerato la diagnosi.

### AI-021 — Revisione indipendente della F3 e reinstallazione da zero
- **Data / Fase / Ambito**: 16/11/2026 · F3 · Qualità/Operations
- **Strumento**: Claude Code (Opus 5.5) con subagent `revisore` (sola lettura), `kind`, `kubectl`, `shellcheck`, `actionlint`.
- **Output**: 11 rilievi (0 bloccanti, 4 importanti); 8 corretti nel commit `b88e2226` (PR #5), 2 motivati e lasciati, 1 già coperto (commit su `main` via PR #5).
  Il rilievo più utile: `install.sh` rilanciato con prod in attesa di promozione si sarebbe fermato dopo 10 minuti, cioè proprio durante la demo (tra il passo C e il D).
- **Decisione**: accettati i rilievi con impatto sulla demo o sulla correttezza; scartati quelli che aggiungono complessità senza rischio reale.
- **Verifica**: cluster ricreato da zero (ok esplicito di Gabriele), `install.sh` exit 0 in 583 s; prova del rilievo 1 con un drift voluto in prod → avviso ed exit 0 in 35 s.
- **Valore**: la revisione separata trova errori che chi ha scritto il codice non vede (es. una frase falsa nel README); la reinstallazione ha fatto emergere
  l'avvio lento dei servizi Python (tema F5).
- **Seconda revisione** (sul commit di correzione): ha trovato un caso residuo dello stesso guasto (risorsa `Missing` in prod non promosso) e 3 minori → PR #6.
  Lezione: anche le correzioni vanno revisionate; una correzione parziale avrebbe dato una falsa sicurezza.


### AI-022 — Avvio della F4: stato, versioni, piano dell'osservabilità
- **Data / Fase / Ambito**: 16/11/2026 · F4 · Pianificazione
- **Strumento**: Claude Code (Opus 5.5), `kubectl`/`docker` in sola lettura, `gh api` per le versioni.
- **Problema**: pianificare R-11..R-13 partendo da cosa c'è già nell'upstream.
- **Output**: diario e scheletro del capitolo F4, 11 voci di glossario, piano in 8 passi con alternative scartate.
- **Decisione**: piano approvato da Gabriele ("procedi").
- **Verifica**: punto di partenza verificato con comandi (log già JSON, probe su 10/11 workload, nessuna metrica Prometheus); versioni lette da GitHub API (chart 93.3.0, client_golang v1.25.0).
- **Valore**: R-11 si dimostra senza scrivere codice; scoperto un problema reale (riavvii 137 dopo il reboot) da indagare in R-12.


### AI-023 — Troubleshooting: la liveness uccide i servizi all'avvio a freddo
- **Data / Fase / Ambito**: 16/11/2026 · F4 · Operations/Troubleshooting
- **Strumento**: Claude Code (Opus 5.5), `journalctl` del kubelet sul nodo, `docker restart` del nodo kind, eventi Kubernetes.
- **Sintomo**: emailservice e recommendationservice con 6 restart in dev (4 in prod), exit 137, dopo il riavvio del PC.
- **Ipotesi e prove**: motivo `Error` e non `OOMKilled` → non è memoria; journal del kubelet senza dettagli (verbosità) ed eventi scaduti (TTL 1 h)
  → **riprodotto** con `docker restart boutique-control-plane`: eventi `Liveness probe failed: timeout … within 1s` su quasi tutti i servizi e
  `Container server failed liveness probe, will be restarted` per currencyservice, paymentservice, recommendationservice, redis.
- **Causa**: 24 pod che partono insieme su CPU contesa; probe upstream con timeout di 1 s e nessuna startupProbe.
- **Rimedio**: opzione `probes.tuning` nel chart (default spento, render identico all'upstream): startupProbe (fino a 180 s), timeout 3 s, liveness `failureThreshold: 5`. PR #7.
- **Verifica**: `diff` del render con default, `helm lint`, kubeconform 52/52 e 49/49; DA VERIFICARE dopo il merge: nuovo avvio a freddo senza kill.
- **Valore**: caso L2 con riproduzione controllata invece di supposizioni; ADR D-29.


### AI-024 — Metriche del frontend, stack di monitoring, dashboard come codice
- **Data / Fase / Ambito**: 16/11/2026 · F4 · Implementazione
- **Strumento**: Claude Code (Opus 5.5), container `golang` per build e test, `helm`, kubeconform, actionlint, API di Prometheus e Grafana.
- **Problema**: R-13, metrica applicativa visibile in Prometheus e Grafana.
- **Output**: `metrics.go` + test (contatore e istogramma per rotta, ordini completati) su porta separata; opzione `frontend.metrics` nel chart
  (porta, NetworkPolicy solo da `monitoring`, ServiceMonitor); kube-prometheus-stack 93.3.0 in `install.sh`; dashboard JSON; CI con schemi CRD. PR #8.
- **Decisione**: accettato. Un errore dell'AI corretto subito: nel test le serie di durata attese erano 3 invece di 4 (il test ha fatto il suo lavoro).
- **Verifica**: `go test` ok; immagine eseguita in locale (`:8080/metrics` 404, `:9090/metrics` ok); target Prometheus tutti `up`; dashboard via API.
- **Limiti / governance**: merge delle PR #6, #7, #8 a Gabriele (il classifier blocca i merge senza revisione).


### AI-025 — Troubleshooting: Grafana satura la CPU del nodo (thrashing della page cache)
- **Data / Fase / Ambito**: 16/11/2026 · F4 · Operations/Troubleshooting
- **Strumento**: Claude Code (Opus 5.5), `top` e cgroup v2 (`memory.stat`, `memory.events`, `/proc/<pid>/io`) sul nodo kind.
- **Sintomo**: `grafana.localhost` → 503 `no available server`; Grafana 2/3, readiness in timeout; nodo al 615% di CPU, load 10 su 8 core.
- **Prove**: Grafana 136-600% CPU; `read_bytes` ≈ **1 TB** in 1 h; cgroup `memory.current` = `memory.max` (384Mi), `workingset_refault_file` 263 M,
  `memory.events max` 5,4 M, nessun OOM. Gli errori nei log (`context canceled`) erano conseguenza, non causa.
- **Causa**: limite di memoria scelto dall'AI troppo basso: la page cache conta nel limite, il kernel toglieva a Grafana i suoi file e Grafana li rileggeva.
- **Rimedio**: limite 1Gi (misurato dopo: ~270 MiB anon + ~420 MiB cache, CPU ~2%, 0 eventi `max`).
- **Valore**: errore dell'AI (dimensionamento "a occhio") scoperto con le misure e documentato; lezione: i limiti di memoria si fissano dopo aver misurato.


### AI-026 — Verifiche dopo i merge: prod, avvio a freddo, installazione da zero
- **Data / Fase / Ambito**: 16/11/2026 · F4 · Verifica/Operations
- **Strumento**: Claude Code (Opus 5.5), `kubectl`, API di Prometheus e Grafana, `docker restart` / `kind delete cluster`, `crictl` nel nodo.
- **Problema**: dimostrare R-12 e R-13 su dev e prod e R-08 con il monitoring.
- **Output**: avvio a freddo con 0 kill da liveness in dev e prod; liveness della piattaforma allineata (PR #9); `install.sh` da zero exit 0 in 704 s;
  correzione di `install.sh` (pull da GHCR sempre prima, host dopo la sync); sezione §G della checklist della demo.
- **Errore dell'AI scoperto dalla verifica**: la build locale di prova di `kt.2` ha preso il posto dell'immagine pubblicata nel cluster ricreato.
  Trovato confrontando gli ID; provato il rimedio con il digest di configurazione (nodo = GHCR `7482c36c…`).
- **Verifica**: numeri di Prometheus in prod identici al traffico generato (25/50/25 richieste, 2 ordini); 15/15 target up dopo la reinstallazione.
- **Limiti / governance**: promozione di prod, ricreazione del cluster e merge sono stati decisi da Gabriele. Un filtro di `grep` scritto male ha nascosto
  un `Error:` di Helm: per gli script si guarda sempre l'exit code, non un estratto dell'output.


### AI-027 — Chiusura della F4: verifiche, secondo avvio a freddo, revisione indipendente
- **Data / Fase / Ambito**: 16/11/2026 · F4 · Verifica/Revisione
- **Strumento**: Claude Code (Opus 5.5) e subagent `revisore` (sola lettura).
- **Problema**: chiudere la fase con prove su tutti i criteri.
- **Errore dell'AI corretto**: nella descrizione della PR #9 avevo scritto "verified with a second cold start" prima di farlo. Accortomi in chiusura,
  ho eseguito la prova (0 kill da probe in tutti i namespace) e aggiunto i risultati alla PR. Lezione: scrivere le prove solo dopo averle fatte.
- **Revisione**: 0 rilievi ALTI, 2 MEDI, 9 BASSI. Corretti: documentazione (README, SECURITY L15-L17, ARCHITECTURE, D-05, D-29), commenti nei values,
  NaN della dashboard, `jq` in CI. Dichiarato: criterio R-12 letto come "nessun riavvio da probe" (gli `Unhealthy` del boot restano). Accettati come limiti:
  `statusWriter` senza `Unwrap()` (non regressione), `log.Fatal` del server metriche (fail-fast), dashboard fuori da GitOps (L17).
- **Verifica**: helm lint, kubeconform 53/53 e 50/50, render di default identico all'upstream, shellcheck, actionlint, go vet/test, query PromQL provate.
- **Valore**: il revisore ha trovato documentazione non allineata e un criterio scritto meglio di come era dimostrato.

### AI-028 — Avvio della F5: contesto, stato del cluster, piano di guasti e rollback
- **Data / Fase / Ambito**: 16/11/2026 · F5 · Analisi/Pianificazione
- **Strumento**: Claude Code (Opus 5.5), skill `/avvia-fase 5`.
- **Problema**: pianificare R-17..R-19 (20% del punteggio) senza combattere contro GitOps: in dev `selfHeal` annulla i guasti fatti a mano,
  l'app non ha una release Helm (`helm rollback` non si applica), prod ha 1 sola voce di history in Argo CD.
- **Approccio**: lettura di requisiti, PDF (§4.7, §7, §9), ADR e diario F4; comandi in sola lettura su repo e cluster; consultata la doc ufficiale
  di `argocd app rollback` (nessun limite citato per multi-source → lasciato DA VERIFICARE, non dato per buono).
- **Output**: piano in 7 passi (smoke test, `fault.sh` con 4 scenari, rollback via `git revert` + history di Argo CD, runbook, demo 7-9),
  diario `2026-11-16-fase-5.md`, scheletro del capitolo 06, 10 voci di glossario.
- **Accettato / modificato / scartato**: piano accettato da Gabriele; scelte: rollback dev con due PR vere, D-10 senza CronJob. Scartati Chaos Mesh/Litmus (RAM, KISS) e guasti in prod.
- **Verifica**: stato iniziale con `kubectl get applications`, `docker stats`, history di `boutique-prod` via `kubectl get application -o json`.
- **Valore**: i vincoli di GitOps sono emersi prima di scrivere codice e sono diventati parte del piano.

### AI-029 — F5: smoke test, quattro guasti in dev e diagnosi di un DNS che risponde 127.0.0.1
- **Data / Fase / Ambito**: 16/11/2026 · F5 · Implementazione + Operations (troubleshooting)
- **Strumento**: Claude Code (Opus 5.5).
- **Problema**: guasti ripetibili per runbook e demo nonostante `selfHeal`; criterio di uscita automatico per ogni guasto.
- **Approccio**: `smoke-test.sh` a livelli (Argo CD → Deployment → endpoint → HTTP); `fault.sh` che sospende la sync automatica, rompe una risorsa
  gestita e la restituisce a Git al ripristino. Ogni scenario eseguito con evidenze (eventi, EndpointSlice, log JSON, metrica di Prometheus).
- **Errori dell'AI corretti**: (1) piano con S4 come NetworkPolicy "in più": non può bloccare, perché le policy si sommano → rifatto come modifica di
  una policy esistente; (2) previsto un crash per S2: il client gRPC è pigro → pod Ready e pagine 500; (3) controllo del rollout con `updatedReplicas`
  (conta anche i pod non pronti) → `.status.replicas`; (4) `kubectl wait` su un selettore che prendeva anche il pod sano.
- **Caso di troubleshooting**: in S2 l'errore era `connection refused` su `127.0.0.1` invece di un errore DNS. Ipotesi formulata e verificata con un
  container effimero: `ndots:5` + domini di ricerca della rete di casa ereditati fino al pod + DNS del router che risponde `127.0.0.1`.
  Inoltre: Service vuoto e policy che blocca restano invisibili finché la connessione gRPC già aperta regge (verificato riavviando il client).
- **Verifica**: shellcheck; smoke test exit 1 in ogni guasto ed exit 0 dopo ogni `restore`; `syncPolicy` di nuovo `automated` a fine prova.
- **Valore**: tre comportamenti non ovvi (rolling update che nasconde un'immagine rotta, connessioni vecchie che nascondono un Service vuoto,
  DNS che "mente") sono diventati scenari documentati del runbook.

### AI-030 — F5: rollback eseguiti (git revert, history di Argo CD, rollout undo), runbook e passi 8-9 della demo
- **Data / Fase / Ambito**: 17/11/2026 · F5 · Operations + Documentazione
- **Strumento**: Claude Code (Opus 5.5); azioni in Argo CD (promozione e rollback dalla UI) e merge delle PR #10-#13 fatte da Gabriele.
- **Problema**: eseguire davvero un rollback (R-17) in modo coerente con GitOps e misurarne i tempi; completare il runbook (R-19).
- **Approccio**: rilascio cattivo provato prima in dev con la sync sospesa, poi su `main` con una PR dichiarata; osservatori in background con timestamp
  (revisione, stato, pod, HTTP, banner); verifica di ogni comando del runbook prima di scriverlo.
- **Errori dell'AI corretti**: (1) primo piano con "tag inesistente": la CI lo avrebbe pubblicato (`ci.yaml:108`) → valore di memoria sbagliato;
  (2) `gh pr create` senza `--repo` diretto all'upstream di Google (fallito senza effetti; regola salvata in memoria); (3) `git revert` sul commit di merge;
  (4) controllo del banner fatto sulle env del Deployment invece che sulla ConfigMap; (5) passo §H della demo con una `curl` che colpiva il pod in `preStop`
  e un `kubectl wait` inutile (`.status.replicas` non conta i pod in chiusura) → corretto e riprovato.
- **Indagine aperta**: frontend di dev a tratti lento (p99 10 s) da stamattina, correlato a CPU strozzata e iowait; escluse rete, Traefik, riavvii, nodo saturo.
- **Verifica**: tempi da log degli osservatori e da `operationState`/`history` di Argo CD; smoke test dev e prod OK dopo ogni ripristino; shellcheck.
- **Valore**: tre comportamenti dimostrati con dati (rolling update che protegge gli utenti, `rollout undo` annullato in 8 s, history che lascia prod OutOfSync
  finché Git non viene corretto); una regola di sicurezza sul fork (`--repo`) emersa da un errore prima che facesse danni.

### AI-031 — F5: chiusura della fase, criteri rieseguiti e revisione indipendente
- **Data / Fase / Ambito**: 17/11/2026 · F5 · Verifica + Revisione
- **Strumento**: Claude Code (Opus 5.5) e subagent `revisore` (sola lettura).
- **Problema**: chiudere la F5 con prove rieseguite sul `main` finale (`4373b288`) e una revisione indipendente degli script e del runbook.
- **Approccio**: i 4 guasti rieseguiti di fila in dev da uno script nella scratchpad (inject → smoke test → restore → rollout status → smoke test);
  `shellcheck`, `helm lint`, `helm template | kubeconform -strict` per dev e prod; diff dei values per confermare l'annullamento dei rilasci di prova.
- **Output del revisore**: 0 rilievi alti, 3 medi, 6 bassi. Decisioni:
  (1) `inject` fallito dopo la pausa → sync in pausa senza avviso: **corretto** (controlli prima di `pause_sync`, `trap … ERR` con l'indicazione di `restore`);
  (2) rimozione dell'unica voce di `from` nella NetworkPolicy = consenti a tutti: **corretto** (serve una seconda voce);
  (3) diario non allineato agli scenari implementati e al comando `restore`: **corretto**;
  (4) dominio della rete di casa nel repo pubblico (D-24, `argocd-values.yaml`): **in attesa della decisione di Gabriele**;
  (5)-(7) runbook ("ogni comando eseguito" vs §4.5, `jq` tra i prerequisiti, 4Mi vs 64Mi/128Mi): **corretti**;
  (8) policy di `restore` scritta a mano: **corretto** (`kubectl apply` del manifest in `deploy/argocd/`, `kubectl diff` prima = nessuna differenza);
  (9) data e SHA nel diario: **corretti**.
- **Errore dell'AI corretto**: primo `trap` scritto con `\\n` (avrebbe stampato `\n` letterale) → corretto prima del commit e provato.
- **Verifica**: smoke exit 1 durante tutti e 4 i guasti, exit 0 dopo ogni `restore` (12-39 s); `netpol inject` due volte → il secondo si ferma senza
  sospendere la sync; `restore` → `{"prune":true,"selfHeal":true}`; shellcheck pulito.
- **Valore**: due difetti reali degli script trovati da una revisione con occhi nuovi prima della demo; uno (lista `from` vuota) avrebbe aperto la rete
  invece di chiuderla in un layout diverso della policy.

### AI-032 — F6: valutazione di Krateo e golden path
- **Data / Fase / Ambito**: 18/11/2026 · F6 · Analisi + Implementazione + Documentazione
- **Strumento**: Claude Code (Opus 5.5), con documentazione ufficiale letta via `gh api` (repo `krateoplatformops/krateo-v2-docs`) e `helm show/template`.
- **Problema**: valutare Krateo (R-20) e decidere se una PoC è possibile con 10 GB di RAM.
- **Approccio**: requisiti ufficiali (12 vCPU / 16 GiB per la piattaforma completa) contro le misure reali del cluster (Prometheus: un ambiente ~0,5 GiB,
  non 2-3 GB come stimato); scoperta che il solo core-provider si installa con Helm; render locale del chart prima di installarlo; lettura del blueprint ufficiale.
- **Output**: `docs/KRATEO.md`; chart golden path con `values.schema.json`; AppProject `tenants`; job CI che pubblica il chart su GHCR; PR #16.
- **Accettato / modificato / scartato**: accettato il modello "Krateo sopra Argo CD" (confermato dal blueprint ufficiale); scartati il deploy diretto via CDC e
  lo schema nel chart upstream. Gabriele ha scelto PoC "motore + Argo CD" e OCI su GHCR.
- **Verifica**: `helm lint`; `kubeconform` (3 risorse valide); 5 input sbagliati rifiutati da `helm template`; precedenza `valuesObject` > `valueFiles` sulla doc di Argo CD;
  CI della PR 4/4 verde; pubblicazione su `main` (`Pushed: …boutique-service:0.1.0`) e pull anonimo con lo stesso digest.
- **Valore**: il render del chart prima dell'installazione ha fatto emergere un rischio vero da portare al colloquio (core-provider ≈ cluster-admin,
  chart-inspector che legge tutti i Secret). **Errore dell'AI**: `helm registry logout` usato per "ispezionare" le credenziali (verificato: nulla rimosso).

### AI-033 — F6: PoC di Krateo, due guasti diagnosticati (inotify, DNS) e un "VERIFICATO" da correggere
- **Data / Fase / Ambito**: 18/11/2026 · F6 · Operations + Troubleshooting
- **Strumento**: Claude Code (Opus 5.5).
- **Problema**: la CompositionDefinition non diventava Ready.
- **Approccio**: sintomo → evidenze → causa, senza riavvii "per vedere": (1) pod 0/1 CrashLoopBackOff, log del container precedente `too many open files`,
  `/proc/sys/fs/inotify/max_user_instances` = 128, kind known issues → fix con `sudo` lanciato da Gabriele (D-32); (2) dopo il fix `Synced=False` con
  `dial tcp 127.0.0.1:443` verso ghcr.io → riconosciuto il caso D-24; il CDC nasce a runtime e il chart non espone `dnsConfig` → MutatingAdmissionPolicy (D-33),
  primo tentativo `ApplyConfiguration` rifiutato (`atomic arrays`), corretto con `JSONPatch`; prova con un pod busybox temporaneo (`ndots:1`, ghcr.io → 140.82.121.33).
- **Errore dell'AI corretto**: avevo dichiarato "funziona su Kubernetes 1.37" vedendo il pod Running a 48 s; gli eventi mostravano 9 riavvii in 31 min.
  Ritirato nel diario; lo script ora controlla i riavvii dopo 30 s. Anche la misura di 59 MiB del motore era presa durante il crash (reale: ~373 MiB).
- **Verifica**: CD Ready 11:59:53; dry-run lato server di una richiesta sbagliata → 3 errori; `team-a` Healthy in 65 s, HTTP 200 su 3 pagine, carrello ok,
  12 NetworkPolicy, niente loadgenerator; cancellazione in ~17 s senza residui; dev/prod sempre Synced/Healthy; `krateo-poc.sh` rieseguito (idempotente, 36 s).
- **Valore**: PoC end-to-end funzionante sul portatile e due lezioni di adozione reali (limiti del kernel condivisi, uscita verso i registry) entrate nei rischi.

### AI-034 — F6: chiusura, criteri rieseguiti e revisione indipendente
- **Data / Fase / Ambito**: 18/11/2026 · F6 · Verifica + Revisione
- **Strumento**: Claude Code (Opus 5.5) e subagent `revisore` (sola lettura).
- **Problema**: chiudere la F6 con prove rieseguite su `main` `4b1955c5` e una revisione indipendente di chart, policy, script, CI e documenti.
- **Approccio**: grep delle voci di R-20 in KRATEO.md; shellcheck, helm lint, kubeconform, 5 test negativi, dry-run lato server dei manifest Krateo;
  seconda prova end-to-end (Krateo + Argo CD 10 s; Healthy dopo 246 s per l'avvio lento dei pod) e cancellazione in 30 s.
- **Output del revisore**: 0 alti, 5 medi, 9 bassi. Decisioni (scelta di Gabriele: correggere tutto con il chart 0.1.1):
  M1 host di dev accettabile da un team → **corretto** (`fail` nel template + test in CI); M2 prod a 1 replica → **corretto**; M3 PoC non riproducibile su un fork
  → **limite documentato** + avviso nello script; M4 script che fallisce dopo un riavvio → **corretto**; M5 richieste non legate al team → **limite documentato**;
  B1 revisione `1.10` letta come numero → **corretto**; B2 schema aperto → **limite**; B3 versioni → **controllo in CI** + D-34 riformulata; B4-B9 → **corretti**
  (B5 marcato DA VERIFICARE). In più, trovato correggendo: dopo un cambio di versione `kubectl wait Ready` può tornare subito → lo script aspetta la nuova versione della CRD.
- **Errore dell'AI corretto**: avevo messo `yq` tra i prerequisiti dello script, ma non è installato in WSL → tornato al `sed` già provato.
- **Verifica**: casi del revisore rieseguiti (`dev.boutique.localhost` e `team-b...` rifiutati, prod 2 repliche, `1.10` stringa), shellcheck/lint/kubeconform puliti, PR #18.
- **Valore**: due difetti reali del golden path (furto dell'host tra team, downtime in prod) trovati da occhi nuovi prima del colloquio; il versioning
  del golden path diventa una prova pratica e non solo una citazione della documentazione.

### AI-035 — F6: aggiornamento del golden path a 0.1.1 sul cluster e attesa dello script
- **Data / Fase / Ambito**: 19/11/2026 · F6 · Verifica + Codice
- **Strumento**: Claude Code (Opus 5.5).
- **Problema**: dopo il merge della PR #18, portare la CompositionDefinition a 0.1.1 e rifare la prova end-to-end.
- **Approccio**: controllo della pubblicazione (log della CI, pull senza credenziali), `scripts/krateo-poc.sh`, dry-run negativo, `team-a` con curl e carrello, cancellazione.
- **Output**: aggiornamento riuscito (~70 s, due versioni della CRD servite), `team-a` Healthy in 33 s, cancellazione in 29 s. Lo script però ha dichiarato pronto
  con `READY False`: l'attesa leggeva il Ready della versione vecchia. Diagnosi dagli orari delle condizioni e del Deployment; correzione: attendere il controller della nuova versione.
- **Accettato / modificato / scartato**: accettata l'attesa del Deployment; scartati uno `sleep` fisso (fragile con le pause della VM) e il controllo di `status.apiVersion` (già nuovo mentre Ready era False).
- **Verifica**: shellcheck pulito, rilancio idempotente Ready True in 41 s; percorso di aggiornamento con la correzione DA VERIFICARE (serve una nuova versione). PR #19.
- **Valore**: la mia correzione della revisione ("aspetta la nuova versione della CRD") non bastava; l'ha mostrato solo la prova reale, non il ragionamento.


### AI-036 — Avvio della F7: stato di consegna, criteri e piano
- **Data / Fase / Ambito**: 19/11/2026 · F7 · Analisi/Pianificazione
- **Strumento**: Claude Code (Opus 5.5), skill `/avvia-fase 7`.
- **Problema**: pianificare la consegna (R-22, R-23, R-25) e la chiusura di R-04 e R-21, a 4 giorni dalla scadenza richiesta (23/11).
- **Approccio**: lettura di requisiti, PDF (§6, §7, §8), ADR, diario F6, checklist della demo, README; comandi in sola lettura su repo e cluster;
  scansione del registro AI per dati sensibili prima di proporne la pubblicazione.
- **Output**: lacune trovate (nessun `AI_USAGE.md`, README senza sezioni test e demo, checklist della demo solo nella workspace e mai provata per intero,
  ultima installazione da zero in F4); piano in 7 passi con clean-room test distruttivo da confermare; diario `2026-11-19-fase-7.md`,
  scheletro del capitolo 08, 5 voci di glossario.
- **Accettato / modificato / scartato**: piano accettato da Gabriele così com'è; scelte: clean-room test con cancellazione del cluster, log grezzo pubblicato come appendice, passo 11 = AI-019.
- **Verifica**: `kubectl get applications -n argocd` (Synced/Healthy), `kubectl get pods -A` (47 Running), `docker stats` (5,62/9,7 GiB), `gh pr list` (nessuna aperta).
- **Valore**: le lacune di consegna sono emerse prima di scrivere; il rischio principale (README mai seguito da zero dopo F4-F6) è diventato un passo esplicito.
