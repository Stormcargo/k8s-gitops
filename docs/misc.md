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

