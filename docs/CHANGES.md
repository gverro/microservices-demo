# Modifiche rispetto all'upstream

Base: `GoogleCloudPlatform/microservices-demo` `main` al commit `c7cb6d5b` (contenuto identico al tag `v0.10.7`
tranne due file di workflow CI). Regola: si modifica l'upstream solo se serve a un requisito della challenge.

| # | File | Tipo | Motivo | Requisito |
|---|---|---|---|---|
| 1 | `kind/cluster.yaml` | Aggiunto | Cluster kind a nodo singolo, node image fissata per digest | R-08 |
| 2 | `scripts/cluster-up.sh` | Aggiunto | Creazione idempotente del cluster (shellcheck pulito) | R-08, R-26 |
| 3 | `docs/ARCHITECTURE.md` | Aggiunto | Architettura, flussi, mappatura dei componenti | R-02, R-03, R-04 |
| 4 | `docs/CHANGES.md` | Aggiunto | Questo file | R-04 |
| 5 | `README.md` | Modificato (sezione iniziale) | Contesto della challenge e motivazione della scelta | R-01 |

Codice applicativo (`src/`) e chart (`helm-chart/`): **nessuna modifica** finora.
