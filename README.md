# HomeOps backed by Flux

A K3S cluster (and more) managed by flux, renovate and a sprinkle of jank.

Glued together with:
- Repo layout and tooling from onedr0p's [flux cluster template](https://github.com/onedr0p/flux-cluster-template)
- Helm values from the K8S@Home community [search](https://nanne.dev/k8s-at-home-search/)
- Helpful advice from the [K8S@Home discord](https://discord.gg/k8s-at-home) server.

## Infrastructure

2x micro nodes

3x raspberry pi 4B's

## 📂 Repository structure

The Git repository contains the following directories under `cluster` and are ordered below by how Flux will apply them.

```sh
📁 cluster      # k8s cluster defined as code
├─📁 flux       # flux, gitops operator, loaded before everything
├─📁 charts     # helm chart repos
├─📁 config     # cluster config
└─📁 apps       # regular apps, namespaced dir tree, loaded last
```
