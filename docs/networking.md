# Networking

### Multus - Cilium - Home Assistant
Multus provides the ability to attach a second NIC to a pod. Currently the only place this is used is in Home Assistant for HomeKit multicast.

While Cilium functions as the main CNI, Multus needs to use a second CNI, macvlan, to provide the alternate NIC. By default in the helm chart, the value `cni.exlusive` is set to `True`. This stops multus from functioning entirely. Set this value to `False`, then upgrade the helm install.

Once this is done, you may also need to perform the steps detailed (here)[https://github.com/angelnu/helm-charts/issues/74]. This allows Multus to pick up the correct binaries for macvlan.

Finally, restart Home Assistant. You should see multus bring up the secondary interface in the logs. If it isn't enabled, click on your profile and turn on Advanced Mode. Then in the `System > Netowrking` panel, select your Multus interface for traffic.


### 🌐 DNS

The `external-dns` application created in the `networking` namespace will handle creating public DNS records. By default, `echo-server` and the `flux-webhook` are the only public sub-domains exposed. In order to make additional applications public you must set an ingress annotation (`external-dns.alpha.kubernetes.io/target`) like done in the `HelmRelease` for `echo-server`.

For split DNS to work it is required to have `${SECRET_DOMAIN}` point to the `${K8S_GATEWAY_ADDR}` load balancer IP address on your home DNS server. This will ensure DNS requests for `${SECRET_DOMAIN}` will only get routed to your `k8s_gateway` service thus providing **internal** DNS resolution to your cluster applications/ingresses from any device that uses your home DNS server.

For and example with Pi-Hole apply the following file and restart dnsmasq:

```sh
# /etc/dnsmasq.d/99-k8s-gateway-forward.conf
server=/${SECRET_DOMAIN}/${K8S_GATEWAY_ADDR}
```

Now try to resolve an internal-only domain with `dig @${pi-hole-ip} hajimari.${SECRET_DOMAIN}` it should resolve to your `${INGRESS_NGINX_ADDR}` IP.

If having trouble you can ask for help in [this](https://github.com/onedr0p/flux-cluster-template/discussions/719) Github discussion.

If nothing is working, that is expected. This is DNS after all!
