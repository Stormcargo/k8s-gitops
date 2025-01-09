# Talos Notes

#### ⚙️ Updating Talos node configuration
📍 _Ensure you have updated `talconfig.yaml` and any patches with your updated configuration._

```sh
# (Re)generate the Talos config
task talos:generate-config
# Apply the config to the node
task talos:apply-config HOSTNAME=? MODE=?
# e.g. task talos:apply-config HOSTNAME=k8s-0 MODE=reboot
```

#### ⬆️ Updating Talos and Kubernetes versions
📍 _Ensure the `talosVersion` and `kubernetesVersion` in `talhelper.yaml` are up-to-date with the version you wish to upgrade to._

```sh
# Upgrade the whole cluster to a newer Talos version
task talos:upgrade-cluster
# e.g. task talos:upgrade-cluster
```

```sh
# Upgrade node to a newer Talos version
task talos:upgrade-node HOSTNAME=?
# e.g. task talos:upgrade HOSTNAME=k8s-0
```

```sh
# Upgrade cluster to a newer Kubernetes version
task talos:upgrade-k8s
# e.g. task talos:upgrade-k8s
```
