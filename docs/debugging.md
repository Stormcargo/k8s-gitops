
# 🐛 Debugging

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

## Debug pod

`kubectl debug node/<node-name> -it --image=<debug-image> -n kube-system --profile=sysadmin`
