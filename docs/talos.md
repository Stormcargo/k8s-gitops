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

## K8S upgrades
If kubernetes can't be upgraded but is in the support matrix on the talos website. Update 
talosctl

Check https://www.talos.dev/v1.9/kubernetes-guides/upgrading-kubernetes/ 

## System upgrade Maybe
https://discord.com/channels/673534664354430999/942576972943491113/1200508059710128189

https://github.com/onedr0p/home-ops/blob/86d5320b6262454fab09f1d8123df2d0d2c322e4/kubernetes/main/apps/system-upgrade/system-upgrade-controller/plans/talos.yaml#L13C13-L13C39

