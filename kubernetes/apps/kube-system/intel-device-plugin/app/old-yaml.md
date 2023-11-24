---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kube-system
resources:
  - ./gpu/kustomization.yaml
  - ./app/kustomization.yaml
  # - nodefeaturerule.yaml
