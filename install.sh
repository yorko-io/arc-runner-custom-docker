                                                                    
NAMESPACE="arc-systems"
helm upgrade --install arc \
  --namespace "$NAMESPACE" --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --wait          # wait until the controller deployment is ready
  
kubectl create ns arc-runners || true  # create the namespace for runners if it doesn't exist
kubectl apply -f ghcr-login-secret.yaml  # ensure the GHCR login secret is created

INSTALLATION_NAME="arc-runners"
RUNNER_NS="arc-runners"
helm upgrade --install "$INSTALLATION_NAME" \
  --namespace "$RUNNER_NS" --create-namespace \
  -f values.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set