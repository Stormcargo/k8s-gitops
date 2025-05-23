# Bootstrap notes

1. All nodes in maintenance mode
2. Run `task talos:bootstrap`, wait for all nodes to be running
3. Optional (maybe) - Remove longhorn Data Directories
    Using `kubectl node-shell -x <node-name>`, navigate to /host/var/mnt/longhorn and delete the content
    Repeat for all longhorn nodes
4. Verify that the kube-system components are running (cilium, coredns, spegel, etc..)
5. Run `task flux:bootstrap`, and be patient
    This can take a while, not everything will appear immediately, get a drink and wait at least half an hour
6. Things that broke:
    1. Missing elements (kinda). Check before and after next time
        - ran `kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml` from this issue https://github.com/fluxcd/flux2/issues/4530
        - This caused everything to show up
    2. Missing Keywords in K9S
        - helmrelease and kustomization keywords were definitely not working in K9S but were present in kubectl