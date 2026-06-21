# Gateway API

This cluster uses [Envoy Gateway](https://gateway.envoyproxy.io/) as its Gateway API implementation, replacing ingress-nginx. Cilium remains the CNI/kube-proxy-replacement only — it is not involved in the Gateway API layer.

## Ingress vs Gateway API

Ingress squashes everything (entrypoint, TLS cert, routing rules, vendor tuning) into one annotated object per app. Gateway API splits that into layers, each owned by a different concern:

| Layer | Ingress equivalent | Gateway API object | Scope |
|---|---|---|---|
| Which controller handles this | `IngressClass` (`internal`/`external`) | `GatewayClass` (`envoy`) | cluster-wide, 1 total |
| The entrypoint: IP, port, TLS cert | The controller + its Service (`ingress-nginx-internal-controller`) | `Gateway` (`internal`/`external`) | 1 per entrypoint — set up once, holds the LoadBalancer IP + wildcard cert |
| Host/path → backend Service | `Ingress.spec.rules` | `HTTPRoute` | 1 per app — same granularity as today's per-app `Ingress` |
| Vendor tuning annotations | `nginx.ingress.kubernetes.io/*` | Native `HTTPRoute` filter, or an Envoy Gateway policy CRD via `targetRefs` | varies, see below |

A single `Ingress` becomes **two** objects: a `Gateway` (shared infrastructure, created once, never touched per-app again) + an `HTTPRoute` (per-app, the thing you actually create/edit when adding or changing an app's routing).

## nginx annotation → Gateway API mapping

| nginx annotation | Gateway API equivalent | Attaches to |
|---|---|---|
| `proxy-read-timeout` / `proxy-send-timeout` | `HTTPRoute.spec.rules[].timeouts` — native field | the route itself |
| `force-ssl-redirect` | `RequestRedirect` filter — native | a route (the shared `http-redirect` HTTPRoute) |
| `configuration-snippet` (header injection, e.g. Plex's `X-Forwarded-*`) | `RequestHeaderModifier` / `ResponseHeaderModifier` filter — native | the route itself |
| `whitelist-source-range` (Longhorn) | `SecurityPolicy` — Envoy Gateway CRD | `targetRefs` → the `HTTPRoute` |
| `hsts-max-age` (global) | `ClientTrafficPolicy` — Envoy Gateway CRD | `targetRefs` → the `Gateway` |
| `block-user-agents` (global) | `EnvoyExtensionPolicy` + inline Lua — Envoy Gateway CRD | `targetRefs` → the `Gateway` |

Two flavors of CRD:
- **Native Gateway API** — `Gateway`, `HTTPRoute`, filters like `RequestRedirect`/`RequestHeaderModifier`. Portable, works with any conformant implementation.
- **Envoy-Gateway-specific policy CRDs** — `EnvoyProxy`, `ClientTrafficPolicy`, `SecurityPolicy`, `EnvoyExtensionPolicy`. Only work with this controller, used to recreate what nginx did via annotations.

Every policy CRD follows the same shape: a standalone object with `targetRefs` pointing at the `Gateway` or `HTTPRoute` it modifies, instead of an annotation living directly on the object it affects.
