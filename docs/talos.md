# Talos Notes

## ⬆️ Upgrading Talos and Kubernetes

### Manual

```sh
# Upgrade Talos to a newer version
# NOTE: This needs to be run once on every node
task talos:upgrade node=? image=?
task talos:upgrade NODE=? IMAGE=?
# e.g.
# task talos:upgrade node=192.168.42.10 image=factory.talos.dev/installer/${schematic_id}:v1.7.4
# task talos:upgrade NODE=192.168.42.10 IMAGE=factory.talos.dev/installer/${schematic_id}:v1.7.4
```
```sh
# Upgrade Kubernetes to a newer version
# NOTE: This only needs to be run once against a controller node
task talos:upgrade-k8s controller=? to=?
task talos:upgrade-k8s NODE=? VERSION=?
# e.g.
# task talos:upgrade-k8s controller=192.168.42.10 to=1.30.1
# task talos:upgrade-k8s CONTROLLER=192.168.42.10 VERSION=1.30.1
```
