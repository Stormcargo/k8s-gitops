# Home cluster backed by Flux

This repo leverages flux, ansible and sops to manage a K3S cluster.

Copied from onedr0p's extremely useful flux cluster template

## 📂 Repository structure

The Git repository contains the following directories under `cluster` and are ordered below by how Flux will apply them.

```sh
📁 cluster      # k8s cluster defined as code
├─📁 flux       # flux, gitops operator, loaded before everything
├─📁 charts     # helm chart repos
├─📁 config     # cluster config
└─📁 apps       # regular apps, namespaced dir tree, loaded last
```

### 🔹 GitOps with Flux

📍 Here we will be installing [flux](https://toolkit.fluxcd.io/) after some quick bootstrap steps.
1. Verify Flux can be installed: `task cluster:verify`
2. Push you changes to git
    📍 **Verify** all the `*.sops.yaml` and `*.sops.yml` files under the `./cluster` and `./provision` folders are **encrypted** with SOPS
    ```sh
    git add -A
    git commit -m "Initial commit :rocket:"
    git push
    ```
3. Install Flux and sync to the Git repository: `task cluster:install`
4. Verify Flux components are running in the cluster: `task cluster:pods -- -n flux-system`

### 🎤 Verification Steps
_Mic check, 1, 2_ - In a few moments applications should be lighting up like a Christmas tree 🎄

You are able to run all the commands below with one task: `task cluster:resources`

1. View the Flux Git Repositories: `task cluster:gitrepositories`
2. View the Flux kustomizations: `task cluster:kustomizations`
3. View all the Flux Helm Releases: `task cluster:helmreleases`
4. View all the Flux Helm Repositories: `task cluster:helmrepositories`
5. View all the Pods: `task cluster:pods`
6. View all the certificates and certificate requests: `task cluster:certificates`
7. View all the ingresses: `task cluster:ingresses`

☢️ If you run into problems, you can run `task ansible:nuke` to destroy the k3s cluster and start over.



## 📣 Post installation

### 🌐 DNS

📍 The [external-dns](https://github.com/kubernetes-sigs/external-dns) application created in the `networking` namespace will handle creating public DNS records. By default, `echo-server` is the only public domain exposed on your Cloudflare domain. In order to make additional applications public you must set an ingress annotation like in the `HelmRelease` for `echo-server`. You do not need to use Terraform to create additional DNS records unless you need a record outside the purposes of your Kubernetes cluster (e.g. setting up MX records).

[k8s_gateway](https://github.com/ori-edge/k8s_gateway) is deployed on the IP choosen for `${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR}`. Inorder to test DNS you can point your clients DNS to the `${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR}` IP address and load `https://hajimari.${BOOTSTRAP_CLOUDFLARE_DOMAIN}` in your browser.

You can also try debugging with the command `dig`, e.g. `dig @${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR} hajimari.${BOOTSTRAP_CLOUDFLARE_DOMAIN}` and you should get a valid answer containing your `${BOOTSTRAP_METALLB_INGRESS_ADDR}` IP address.

If your router (or Pi-Hole, Adguard Home or whatever) supports conditional DNS forwarding (also know as split-horizon DNS) you may have DNS requests for `${SECRET_DOMAIN}` only point to the  `${BOOTSTRAP_METALLB_K8S_GATEWAY_ADDR}` IP address. This will ensure only DNS requests for `${SECRET_DOMAIN}` will only get routed to your [k8s_gateway](https://github.com/ori-edge/k8s_gateway) service thus providing DNS resolution to your cluster applications/ingresses.

To access services from the outside world port forwarded `80` and `443` in your router to the `${BOOTSTRAP_METALLB_INGRESS_ADDR}` IP, in a few moments head over to your browser and you _should_ be able to access `https://echo-server.${BOOTSTRAP_CLOUDFLARE_DOMAIN}` from a device outside your LAN.

Now if nothing is working, that is expected. This is DNS after all!

### 🔐 SSL

By default in this template Kubernetes ingresses are set to use the [Let's Encrypt Staging Environment](https://letsencrypt.org/docs/staging-environment/). This will hopefully reduce issues from ACME on requesting certificates until you are ready to use this in "Production".

Once you have confirmed there are no issues requesting your certificates replace `letsencrypt-staging` with `letsencrypt-production` in your ingress annotations for `cert-manager.io/cluster-issuer`

### 🤖 Renovatebot

[Renovatebot](https://www.mend.io/free-developer-tools/renovate/) will scan your repository and offer PRs when it finds dependencies out of date. Common dependencies it will discover and update are Flux, Ansible Galaxy Roles, Terraform Providers, Kubernetes Helm Charts, Kubernetes Container Images, Pre-commit hooks updates, and more!

The base Renovate configuration provided in your repository can be view at [.github/renovate.json5](https://github.com/onedr0p/flux-cluster-template/blob/main/.github/renovate.json5). If you notice this only runs on weekends and you can [change the schedule to anything you want](https://docs.renovatebot.com/presets-schedule/) or simply remove it.

To enable Renovate on your repository, click the 'Configure' button over at their [Github app page](https://github.com/apps/renovate) and choose your repository. Over time Renovate will create PRs for out-of-date dependencies it finds. Any merged PRs that are in the cluster directory Flux will deploy.

### 🪝 Github Webhook

Flux is pull-based by design meaning it will periodically check your git repository for changes, using a webhook you can enable Flux to update your cluster on `git push`. In order to configure Github to send `push` events from your repository to the Flux webhook receiver you will need two things:

1. Webhook URL - Your webhook receiver will be deployed on `https://flux-receiver.${BOOTSTRAP_CLOUDFLARE_DOMAIN}/hook/:hookId`. In order to find out your hook id you can run the following command:

    ```sh
    kubectl -n flux-system get receiver/github-receiver --kubeconfig=./provision/kubeconfig
    # NAME              AGE    READY   STATUS
    # github-receiver   6h8m   True    Receiver initialized with URL: /hook/12ebd1e363c641dc3c2e430ecf3cee2b3c7a5ac9e1234506f6f5f3ce1230e123
    ```

    So if my domain was `onedr0p.com` the full url would look like this:

    ```text
    https://flux-receiver.onedr0p.com/hook/12ebd1e363c641dc3c2e430ecf3cee2b3c7a5ac9e1234506f6f5f3ce1230e123
    ```

2. Webhook secret - Your webhook secret can be found by decrypting the `secret.sops.yaml` using the following command:

    ```sh
    sops -d ./cluster/apps/flux-system/webhooks/github/secret.sops.yaml | yq .stringData.token
    ```

    **Note:** Don't forget to update the `BOOTSTRAP_FLUX_GITHUB_WEBHOOK_SECRET` variable in your `.config.env` file so it matches the generated secret if applicable

Now that you have the webhook url and secret, it's time to set everything up on the Github repository side. Navigate to the settings of your repository on Github, under "Settings/Webhooks" press the "Add webhook" button. Fill in the webhook url and your secret.

### 🔏 Authenticate Flux over SSH

Authenticating Flux to your git repository has a couple benefits like using a private git repository and/or using the Flux [Image Automation Controllers](https://fluxcd.io/docs/components/image/).

By default this template only works on a public GitHub repository, it is advised to keep your repository public.

The benefits of a public repository include:

* Debugging or asking for help, you can provide a link to a resource you are having issues with.
* Adding a topic to your repository of `k8s-at-home` to be included in the [k8s-at-home-search](https://whazor.github.io/k8s-at-home-search/). This search helps people discover different configurations of Helm charts across others Flux based repositories.

<details>
  <summary>Expand to read guide on adding Flux SSH authentication</summary>

  1. Generate new SSH key:
      ```sh
      ssh-keygen -t ecdsa -b 521 -C "github-deploy-key" -f ./cluster/github-deploy-key -q -P ""
      ```
  2. Paste public key in the deploy keys section of your repository settings
  3. Create sops secret in `cluster/flux/flux-system/github-deploy-key.sops.yaml` with the contents of:
      ```yaml
      # yamllint disable
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
      sops --encrypt --in-place ./cluster/flux/flux-system/github-deploy-key.sops.yaml
      ```
  5. Apply secret to cluster:
      ```sh
      sops --decrypt cluster/flux/flux-system/github-deploy-key.sops.yaml | kubectl apply -f -
      ```
  6.  Update `cluster/flux/flux-system/flux-cluster.yaml`:
      ```yaml
      ---
      apiVersion: source.toolkit.fluxcd.io/v1beta2
      kind: GitRepository
      metadata:
        name: flux-cluster
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
