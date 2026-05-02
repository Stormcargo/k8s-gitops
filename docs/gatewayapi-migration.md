# Ingress → Gateway API migration plan (repo-specific)

## Decisions confirmed

- **Cutover type:** Full cutover from ingress-nginx (no long-lived hybrid).
- **Scope:** Internal + external move together in one coordinated migration wave.
- **Host/path policy:** Keep existing hostnames and paths exactly the same (no normalization changes during migration).
- **Pilot set:** All current ingress-exposed apps are in scope.

## Current state in this repo

- Cluster currently runs **ingress-nginx** (internal + external) and many apps expose `values.ingress` through the `bjw-s/app-template` chart.
- Gateway API CRDs are already installed through Cilium (`gateway.networking.k8s.io`).
- At least one workload (`glance`) already has commented `route:` stanzas and RBAC permissions to list both Ingress and Gateway API resources.

## What migration requires

1. **Gateway foundation (internal + external together)**
   - Confirm Cilium Gateway API datapath features are enabled for production traffic.
   - Define and apply `GatewayClass`/`Gateway` resources for both internal and external entrypoints in the same release window.
   - Keep listener TLS and hostname behavior equivalent to current ingress behavior.

2. **Per-app manifest migration (`bjw-s/app-template`)**
   - For each app using `values.ingress.<name>`, add corresponding `values.route.<name>` with equivalent host/path/backend behavior.
   - During migration execution, ensure every converted app points to the correct `parentRefs` and listener `sectionName` where required.

3. **Annotation replacement strategy**
   - Existing nginx annotations are controller-specific and do not map directly to portable Gateway API fields.
   - Replace each annotation-driven behavior via one of:
     - HTTPRoute-native features (matches/filters/timeouts where supported),
     - Cilium/Gateway implementation policy CRDs,
     - Application-level configuration.

4. **DNS ownership after cutover**
   - `HTTPRoute` should be the primary source for DNS reconciliation after cutover (via `external-dns` Gateway API support).
   - Practical meaning:
     - **Today:** DNS records are derived from ingress resources in current setup.
     - **Target:** DNS records are derived from HTTPRoute/Gateway objects once Ingress is removed.
   - Action: update `external-dns` source flags and test record reconciliation before removing ingress resources.

5. **Dependency/order updates**
   - Replace `dependsOn: ingress-nginx-*` for application Kustomizations/HelmReleases with dependencies on the new Gateway API foundation objects/controllers.
   - Enforce ordering so app HTTPRoutes reconcile only after Gateways/listeners are ready.

6. **Execution plan for “all apps”**
   - Inventory all app manifests currently defining `values.ingress`.
   - Convert all to `values.route` with equivalent exposure semantics.
   - Validate TLS, DNS, auth, websocket/streaming, and timeout-sensitive paths for every app.
   - Remove ingress-nginx and residual ingress manifests only after parity verification across the full app set.

## Chart-specific notes (bjw-s/app-template)

The app-template chart supports both:
- `ingress:` (Ingress resources)
- `route:` (HTTPRoute resources)

For each app route definition, ensure:
- `hostnames`
- `parentRefs` (`name`, `namespace`, and often `sectionName`)
- `rules.matches.path`
- `backendRefs` (service + port)

## Glance-specific notes

`glance` currently has:
- active `ingress.app`
- commented `route.glance`
- RBAC including `gateways` and `httproutes`

It can still serve as a reference template for conversion mechanics, but migration scope is now all apps in the same coordinated cutover.

## Host/path invariance (explicit)

No normalization will be performed.

- Hostnames must remain exactly as they are today.
- Paths must remain exactly as they are today.
- Any route conversion must preserve existing URL shape 1:1.
