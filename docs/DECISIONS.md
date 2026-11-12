# Decisioni di progetto

Registro sintetico delle scelte (ADR leggeri): contesto, decisione, alternative scartate.
Stato: **ACCETTATA** (in uso) · **PROPOSTA** (sarà confermata nella fase indicata).

| ID | Decisione | Stato | Motivo | Alternative scartate |
|---|---|---|---|---|
| D-01 | Workload: Online Boutique **v0.10.7** | ACCETTATA | Consigliata dal PDF; 11 microservizi in 5 linguaggi, HTTP + gRPC, chart Helm disponibile | Altre app demo (es. Sock Shop): equivalenza da dimostrare senza vantaggi |
| D-02 | Cluster locale **kind** a nodo singolo, node image fissata per digest | ACCETTATA | Leggero, basato su Docker, usato anche in CI; confermato accettabile da Kiratech | minikube (più pesante), k3d (valido); OpenShift Local (RAM insufficiente) |
| D-03 | Packaging con il **chart Helm** upstream e un file di values per ambiente | ACCETTATA | Differenze tra ambienti esplicite e revisionabili; Redis già fissato per digest nel chart | Kustomize (valido, ma uno strumento solo); manifest `release/` (Redis senza digest) |
| D-04 | Ambienti **dev** e **prod** come namespace dello stesso cluster | PROPOSTA (F2) | Ammesso dal PDF; sta nella RAM disponibile | Cluster separati (realistico ma troppo pesante in locale) |
| D-05 | Build solo del servizio modificato (**frontend**) | PROPOSTA (F2) | Compilare 11 servizi in 5 linguaggi non aggiunge valore | Build di tutti i servizi |
| D-06 | Metrica applicativa `/metrics` Prometheus nel frontend | PROPOSTA (F4) | Il frontend vede tutto il traffico esterno | Metriche solo infrastrutturali |
| D-07 | Password di Redis come Secret cifrato in Git (Sealed Secrets) | PROPOSTA (F2) | Compatibile con GitOps, nessun secret in chiaro | External Secrets + vault (troppo per un ambiente locale), SOPS |
| D-08 | CI con GitHub Actions, CD GitOps con Argo CD | PROPOSTA (F3) | Integrazione con il fork e GHCR; Argo CD è lo standard di fatto | Flux (valido), deploy diretto da pipeline (non GitOps) |
| D-09 | Krateo: valutazione con blueprint e YAML concettuale; PoC se le risorse bastano | ACCETTATA | Il PDF non rende obbligatoria l'integrazione; confermato da Kiratech | Integrazione completa (RAM limitata) |
| D-10 | Nessun worker/broker nell'app: gap dichiarato + CronJob di smoke test come componente batch | PROPOSTA (F2) | Copre il componente "worker" senza inventare funzioni | Aggiungere un broker (fuori scopo) |
| D-13 | Esposizione del frontend: Ingress o Gateway API su kind | PROPOSTA (F2) | Il chart non ha Ingress; la doc kind indica cloud-provider-kind | Service LoadBalancer da solo (resta `<pending>` su kind) |
| D-14 | Repository nel filesystem Linux di WSL | ACCETTATA | Sul disco Windows montato in WSL git non può impostare i permessi (`chmod … Operation not permitted`) | Opzione `metadata` del mount (sudo, I/O lento) |
| D-15 | GitHub Actions disattivato sul fork fino alla F3 | ACCETTATA | I workflow upstream presuppongono l'infrastruttura Google Cloud | Disattivare i singoli workflow (non ancora registrati da GitHub) |

Le decisioni D-11 e D-12 riguardano l'ambiente personale di lavoro (RAM di WSL, demo dal vivo) e non il repository.
