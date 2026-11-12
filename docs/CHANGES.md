# Modifiche rispetto all'upstream

Base: `GoogleCloudPlatform/microservices-demo` `main` al commit `c7cb6d5b` (contenuto identico al tag `v0.10.7`
tranne due file di workflow CI). Regola: si modifica l'upstream solo se serve a un requisito della challenge
(il § indica la sezione del documento della challenge).

| # | File | Tipo | Motivo | § challenge |
|---|---|---|---|---|
| 1 | `kind/cluster.yaml` | Aggiunto | Cluster kind a nodo singolo, node image fissata per digest | §2.4 cluster locale |
| 2 | `scripts/cluster-up.sh` | Aggiunto | Creazione idempotente del cluster, ripartenza dopo un riavvio di WSL/Docker | §2.4, §8 script |
| 3 | `docs/ARCHITECTURE.md` | Aggiunto | Architettura, flussi, mappatura dei componenti | §3, §4.1 |
| 4 | `docs/DECISIONS.md` | Aggiunto | Scelte di progetto e alternative | §10 motivare le scelte |
| 5 | `docs/CHANGES.md` | Aggiunto | Questo file | §4.1 modifiche documentate |
| 6 | `README.md` | Modificato (sezione iniziale) | Dominio, motivazione della scelta, parti usate | §2.2, §8 |
| 7 | GitHub Actions del fork | Disattivato (impostazione, non file) | I workflow upstream richiedono Google Cloud | — |

Codice applicativo (`src/`) e chart (`helm-chart/`): **nessuna modifica** finora.
