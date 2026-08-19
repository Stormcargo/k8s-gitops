# CloudNativePG

Postgres for the cluster: one `Cluster` (`postgres17`) in the `databases` namespace, backed up
daily to R2 via barman-cloud.

Databases and roles are **declarative** — the operator creates them from `Database` and
`DatabaseRole` CRs. Apps do not run a `postgres-init` init container, and no app ever receives
the Postgres superuser password.

## Adding a database for a new app

**1. Add the credentials to 1Password.** In the app's existing item, add a
`<APP>_POSTGRES_PASSWORD` field. The role name and database name are *not* secrets and live in
git (step 2) — don't put them in 1Password, or the two will drift.

**2. Create `cluster/databases/<app>.yaml`.** Copy `romm.yaml` and rename. Three resources:

- an `ExternalSecret` rendering a `kubernetes.io/basic-auth` secret, labelled
  `cnpg.io/reload: "true"`
- a `DatabaseRole` — the Postgres role
- a `Database` — owned by that role

**3. Add it to `cluster/databases/kustomization.yaml`.**

**4. Wire up the app.** In the app's `ExternalSecret`, point it at the database with literals
matching step 2:

```yaml
DB_HOST: "postgres17-rw.databases.svc.cluster.local"
DB_PORT: "5432"
DB_USER: "<role>"
DB_NAME: "<dbname>"
DB_PASSWD: "{{ .<APP>_POSTGRES_PASSWORD }}"
```

**5. Add `cloudnative-pg-cluster` to the app's `ks.yaml` `dependsOn`.** This is what orders the
database ahead of the app.

## Things that will bite you

**The CRs must live in the `databases` namespace.** They reference the `Cluster` by name only,
with no namespace field, so they must be co-located with it. They cannot go in the app's
directory — app Kustomizations pin `targetNamespace`, which would silently drop them into the
wrong namespace. That is why they are centralised here.

**The secret's `username` must equal `DatabaseRole.spec.name`.** On a mismatch the operator
refuses to reconcile (`the username in secret %q does not match role %q`) before running any
SQL. It fails safe, but the role is then unmanaged until you fix it.

**Adopting an *existing* role rewrites every attribute.** The operator emits a single
`ALTER ROLE` with every option spelled out, so anything you omit is reset to its default and
any role membership not listed in `inRoles` is revoked. Before pointing a `DatabaseRole` at a
role that already exists, dump its current attributes and make the manifest match:

```sh
kubectl -n databases exec postgres17-1 -c postgres -- psql -U postgres -Atc \
  "select rolname, rolcanlogin, rolinherit, rolcreatedb, rolcreaterole, rolsuper,
          rolreplication, rolbypassrls, rolconnlimit, rolvaliduntil
   from pg_roles where rolname = '<role>';"
```

Adopting an existing *database* is safe by comparison — the operator only issues `ALTER` for
fields you actually set, so a minimal spec just re-asserts the owner.

**Keep both reclaim policies on `retain`** (the default). Under `delete`, removing the CR —
including a Flux prune — drops the database.

## Verifying

```sh
kubectl -n databases get database,databaserole      # both should report applied=true
kubectl -n databases get database <name> -o jsonpath='{.status}'
```

`applied: true` means the operator reconciled it, not that the app can connect — check the
app's own logs for that.
