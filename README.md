# Template for deploying a Kubernetes cluster backed by Flux

6. Use the API Token in the appropriate variable in configuration section below.

### ☁️ Cloudflare Tunnel

3. In the `~/.cloudflared` directory there will be a json file with details you need to populate in configuration section below. You can ignore the `cert.pem` file

### 📄 Configuration

1. Copy the configuration and addons files and start filling out all the variables.

   ```sh
   task init
   ```

2. Once done run the following command which will verify and generate all the files needed to continue.

   ```sh
   task configure
   ```

### 📂 Repository structure

The configure script will have created the following directories under `./kubernetes`.

```sh
📁 kubernetes      # Kubernetes cluster defined as code
├─📁 bootstrap     # Flux installation (not tracked by Flux)
├─📁 flux          # Main Flux configuration of repository
└─📁 apps          # Apps deployed into the cluster grouped by namespace
```

### ⚡ Preparing Debian Server with Ansible

📍 Here we will be running an Ansible Playbook to prepare Debian server for running a Kubernetes cluster.

📍 Nodes are not security hardened by default, you can do this with [dev-sec/ansible-collection-hardening](https://github.com/dev-sec/ansible-collection-hardening) or similar if supported. This is an advanced configuration and generally not recommended unless you want to [DevSecOps](https://www.ibm.com/topics/devsecops) your cluster and nodes.

1. Ensure you are able to SSH into your nodes from your workstation using a private SSH key **without a passphrase**. This is how Ansible is able to connect to your remote nodes.

2. Install the Ansible deps

   ```sh
   task ansible:deps
   ```

3. Verify Ansible can view your config

   ```sh
   task ansible:list
   ```

4. Verify Ansible can ping your nodes

   ```sh
   task ansible:ping
   ```

5. Run the Ansible prepare playbook

   ```sh
   task ansible:prepare
   ```

6. Reboot the nodes (if not done in step 5)

   ```sh
   task ansible:force-reboot
   ```

### ⛵ Installing k3s with Ansible

📍 Here we will be running a Ansible Playbook to install [k3s](https://k3s.io/) with [this](https://galaxy.ansible.com/xanmanning/k3s) wonderful k3s Ansible galaxy role. After completion, Ansible will drop a `kubeconfig` in `./kubeconfig` for use with interacting with your cluster with `kubectl`.

☢️ If you run into problems, you can run `task ansible:nuke` to destroy the k3s cluster and start over.

1. Verify Ansible can view your config

   ```sh
   task ansible:list
   ```

2. Verify Ansible can ping your nodes

   ```sh
   task ansible:ping
   ```

3. Install k3s with Ansible

   ```sh
   task ansible:install
   ```

4. Verify the nodes are online

   ```sh
   task cluster:nodes
   # NAME           STATUS   ROLES                       AGE     VERSION
   # k8s-0          Ready    control-plane,etcd,master   1h      v1.27.3+k3s1
   # k8s-1          Ready    control-plane,etcd,master   1h      v1.27.3+k3s1
   # k8s-2          Ready    control-plane,etcd,master   1h      v1.27.3+k3s1
   # k8s-3          Ready    worker                      1h      v1.27.3+k3s1
   ```

### 🔹 GitOps with Flux

📍 Here we will be installing [flux](https://toolkit.fluxcd.io/) after some quick bootstrap steps.

1. Verify Flux can be installed

   ```sh
   task cluster:verify
   # ► checking prerequisites
   # ✔ kubectl 1.27.3 >=1.18.0-0
   # ✔ Kubernetes 1.27.3+k3s1 >=1.16.0-0
   # ✔ prerequisites checks passed
   ```

2. Push you changes to git

   📍 **Verify** all the `*.sops.yaml` and `*.sops.yaml` files under the `./ansible`, and `./kubernetes` directories are **encrypted** with SOPS

   ```sh
   git add -A
   git commit -m "Initial commit :rocket:"
   git push
   ```

3. Install Flux and sync the cluster to the Git repository

   ```sh
   task cluster:install
   # namespace/flux-system configured
   # customresourcedefinition.apiextensions.k8s.io/alerts.notification.toolkit.fluxcd.io created
   ```

4. Verify Flux components are running in the cluster

   ```sh
   task cluster:pods -- -n flux-system
   # NAME                                       READY   STATUS    RESTARTS   AGE
   # helm-controller-5bbd94c75-89sb4            1/1     Running   0          1h
   # kustomize-controller-7b67b6b77d-nqc67      1/1     Running   0          1h
   # notification-controller-7c46575844-k4bvr   1/1     Running   0          1h
   # source-controller-7d6875bcb4-zqw9f         1/1     Running   0          1h
   ```

### 🎤 Verification Steps

_Mic check, 1, 2_ - In a few moments applications should be lighting up like a Christmas tree 🎄

You are able to run all the commands below with one task

```sh
task cluster:resources
```

1. View the Flux Git Repositories

   ```sh
   task cluster:gitrepositories
   ```

2. View the Flux kustomizations

   ```sh
   task cluster:kustomizations
   ```

3. View all the Flux Helm Releases

   ```sh
   task cluster:helmreleases
   ```

4. View all the Flux Helm Repositories

   ```sh
   task cluster:helmrepositories
   ```

5. View all the Pods

   ```sh
   task cluster:pods
   ```

6. View all the certificates and certificate requests

   ```sh
   task cluster:certificates
   ```

7. View all the ingresses

   ```sh
   task cluster:ingresses
   ```

🏆 **Congratulations** if all goes smooth you'll have a Kubernetes cluster managed by Flux, your Git repository is driving the state of your cluster.

☢️ If you run into problems, you can run `task ansible:nuke` to destroy the k3s cluster and start over.

🧠 Now it's time to pause and go get some coffee ☕ because next is describing additional things like how DNS is handled.

## 📣 Post installation

### 🌱 Environment

[direnv](https://direnv.net/) will make it so anytime you `cd` to your repo's directory it export the required environment variables (e.g. `KUBECONFIG`). To set this up make sure you [hook it into your shell](https://direnv.net/docs/hook.html) and after that is done, run `direnv allow` while in your repos directory.

### 📜 Certificates

By default this template will deploy a wildcard certificate with the Let's Encrypt staging servers. This is to prevent you from getting rate-limited on configuration that might not be valid on bootstrap using the production server. Once you have confirmed the certificate is created and valid, make sure to switch to the Let's Encrypt production servers as outlined below. Do not enable the production certificate until you are sure you will keep the cluster up for more than a few hours.

1. Update the resources to use the production Let's Encrypt server:

    ```patch
    diff --git a/kubernetes/apps/networking/ingress-nginx/app/helmrelease.yaml b/kubernetes/apps/networking/ingress-nginx/app/helmrelease.yaml
    index e582d4a..0f80700 100644
    --- a/kubernetes/apps/networking/ingress-nginx/app/helmrelease.yaml
    +++ b/kubernetes/apps/networking/ingress-nginx/app/helmrelease.yaml
    @@ -60,7 +60,7 @@ spec:
               namespaceSelector:
                 any: true
           extraArgs:
    -        default-ssl-certificate: "networking/${SECRET_DOMAIN/./-}-staging-tls"
    +        default-ssl-certificate: "networking/${SECRET_DOMAIN/./-}-production-tls"
           resources:
             requests:
               cpu: 10m
    diff --git a/kubernetes/apps/networking/ingress-nginx/certificates/kustomization.yaml b/kubernetes/apps/networking/ingress-nginx/certificates/kustomization.yaml
    index d57147d..f58e4a7 100644
    --- a/kubernetes/apps/networking/ingress-nginx/certificates/kustomization.yaml
    +++ b/kubernetes/apps/networking/ingress-nginx/certificates/kustomization.yaml
    @@ -3,4 +3,4 @@ apiVersion: kustomize.config.k8s.io/v1beta1
     kind: Kustomization
     resources:
       - ./staging.yaml
    -  # - ./production.yaml
    +  - ./production.yaml
    ```

2. Commit and push your changes:

    ```sh
    git add -A
    git commit -m "fix: use production LE certificates"
    git push
    ```

3. Force Flux to pick up the changes:

    ```sh
    task cluster:reconcile
    ```

- To view the certificate request run `kubectl -n networking get certificaterequests`
- To verify the certificate is created run `kubectl -n networking get certificates`

You should start to see your applications using the new certificate.

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

### 🤖 Renovatebot

[Renovatebot](https://www.mend.io/free-developer-tools/renovate/) will scan your repository and offer PRs when it finds dependencies out of date. Common dependencies it will discover and update are Flux, Ansible Galaxy Roles, Terraform Providers, Kubernetes Helm Charts, Kubernetes Container Images, and more!

The base Renovate configuration provided in your repository can be view at [.github/renovate.json5](https://github.com/onedr0p/flux-cluster-template/blob/main/.github/renovate.json5). If you notice this only runs on weekends and you can [change the schedule to anything you want](https://docs.renovatebot.com/presets-schedule/) or simply remove it.

To enable Renovate on your repository, click the 'Configure' button over at their [Github app page](https://github.com/apps/renovate) and choose your repository. Over time Renovate will create PRs for out-of-date dependencies it finds. Any merged PRs that are in the kubernetes directory Flux will deploy.

### 🪝 Github Webhook

Flux is pull-based by design meaning it will periodically check your git repository for changes, using a webhook you can enable Flux to update your cluster on `git push`. In order to configure Github to send `push` events from your repository to the Flux webhook receiver you will need two things:

1. Webhook URL - Your webhook receiver will be deployed on `https://flux-webhook.${bootstrap_cloudflare_domain}/hook/:hookId`. In order to find out your hook id you can run the following command:

   ```sh
   kubectl -n flux-system get receiver/github-receiver
   # NAME              AGE    READY   STATUS
   # github-receiver   6h8m   True    Receiver initialized with URL: /hook/12ebd1e363c641dc3c2e430ecf3cee2b3c7a5ac9e1234506f6f5f3ce1230e123
   ```

   So if my domain was `onedr0p.com` the full url would look like this:

   ```text
   https://flux-webhook.onedr0p.com/hook/12ebd1e363c641dc3c2e430ecf3cee2b3c7a5ac9e1234506f6f5f3ce1230e123
   ```

2. Webhook secret - Your webhook secret can be found by decrypting the `secret.sops.yaml` using the following command:

   ```sh
   sops -d ./kubernetes/apps/flux-system/addons/webhooks/github/secret.sops.yaml | yq .stringData.token
   ```

   **Note:** Don't forget to update the `bootstrap_flux_github_webhook_token` variable in the `config.yaml` file so it matches the generated secret if applicable

Now that you have the webhook url and secret, it's time to set everything up on the Github repository side. Navigate to the settings of your repository on Github, under "Settings/Webhooks" press the "Add webhook" button. Fill in the webhook url and your secret.

### 💾 Storage

Rancher's `local-path-provisioner` is a great start for storage but soon you might find you need more features like replicated block storage, or to connect to a NFS/SMB/iSCSI server. Check out the projects below to read up more on some storage solutions that might work for you.

- [rook-ceph](https://github.com/rook/rook)
- [longhorn](https://github.com/longhorn/longhorn)
- [openebs](https://github.com/openebs/openebs)
- [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [democratic-csi](https://github.com/democratic-csi/democratic-csi)
- [csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs)
- [synology-csi](https://github.com/SynologyOpenSource/synology-csi)

### 🔏 Authenticate Flux over SSH

Authenticating Flux to your git repository has a couple benefits like using a private git repository and/or using the Flux [Image Automation Controllers](https://fluxcd.io/docs/components/image/).

By default this template only works on a public GitHub repository, it is advised to keep your repository public.

The benefits of a public repository include:

- Debugging or asking for help, you can provide a link to a resource you are having issues with.
- Adding a topic to your repository of `k8s-at-home` to be included in the [k8s-at-home-search](https://whazor.github.io/k8s-at-home-search/). This search helps people discover different configurations of Helm charts across others Flux based repositories.

<details>
  <summary>Expand to read guide on adding Flux SSH authentication</summary>

1. Generate new SSH key:

   ```sh
   ssh-keygen -t ecdsa -b 521 -C "github-deploy-key" -f ./kubernetes/bootstrap/github-deploy.key -q -P ""
   ```

2. Paste public key in the deploy keys section of your repository settings
3. Create sops secret in `./kubernetes/bootstrap/github-deploy-key.sops.yaml` with the contents of:

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: github-deploy-key
     namespace: flux-system
   stringData:
     # 3a. Contents of github-deploy-key
     identity: |
       -----BEGIN OPENSSH PRIVATE KEY-----
           ...
       -----END OPENSSH PRIVATE KEY-----
     # 3b. Output of curl --silent https://api.github.com/meta | jq --raw-output '"github.com "+.ssh_keys[]'
     known_hosts: |
       github.com ssh-ed25519 ...
       github.com ecdsa-sha2-nistp256 ...
       github.com ssh-rsa ...
   ```

4. Encrypt secret:

   ```sh
   sops --encrypt --in-place ./kubernetes/bootstrap/github-deploy-key.sops.yaml
   ```

5. Apply secret to cluster:

   ```sh
   sops --decrypt ./kubernetes/bootstrap/github-deploy-key.sops.yaml | kubectl apply -f -
   ```

6. Update `./kubernetes/flux/config/cluster.yaml`:

   ```yaml
   apiVersion: source.toolkit.fluxcd.io/v1beta2
   kind: GitRepository
   metadata:
     name: home-kubernetes
     namespace: flux-system
   spec:
     interval: 10m
     # 6a: Change this to your user and repo names
     url: ssh://git@github.com/$user/$repo
     ref:
       branch: main
     secretRef:
       name: github-deploy-key
   ```

7. Commit and push changes
8. Force flux to reconcile your changes

   ```sh
   task cluster:reconcile
   ```

9. Verify git repository is now using SSH:

   ```sh
   task cluster:gitrepositories
   ```

10. Optionally set your repository to Private in your repository settings.

</details>

### 💨 Kubernetes Dashboard

Included in your cluster is the [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/). Inorder to log into this you will have to get the secret token from the cluster using the command below.

```sh
kubectl -n monitoring get secret kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
```

You should be able to access the dashboard at `https://kubernetes.${SECRET_DOMAIN}`

## 🐛 Debugging

Below is a general guide on trying to debug an issue with an resource or application. For example, if a workload/resource is not showing up or a pod has started but in a `CrashLoopBackOff` or `Pending` state.

1. Start by checking all Flux Kustomizations & Git Repository & OCI Repository and verify they are healthy.

- `flux get sources oci -A`
- `flux get sources git -A`
- `flux get ks -A`

2. Then check all the Flux Helm Releases and verify they are healthy.

- `flux get hr -A`

3. Then check the if the pod is present.

- `kubectl -n <namespace> get pods`

4. Then check the logs of the pod if its there.

- `kubectl -n <namespace> logs <pod-name> -f`

Note: If a resource exists, running `kubectl -n <namespace> describe <resource> <name>` might give you insight into what the problem(s) could be.

Resolving problems that you have could take some tweaking of your YAML manifests in order to get things working, other times it could be a external factor like permissions on NFS. If you are unable to figure out your problem see the help section below.

## 👉 Help

- Make a post in this repository's GitHub [Discussions](https://github.com/onedr0p/flux-cluster-template/discussions).
- Start a thread in the `support` or `flux-cluster-template` channel in the [k8s@home](https://discord.gg/k8s-at-home) Discord server.

## ❔ What's next

The world is your cluster, have at it!

## 🤝 Thanks

Big shout out to all the authors and contributors to the projects that we are using in this repository.

[@whazor](https://github.com/whazor) created [this website](https://nanne.dev/k8s-at-home-search/) as a creative way to search Helm Releases across GitHub. You may use it as a means to get ideas on how to configure an applications' Helm values.
