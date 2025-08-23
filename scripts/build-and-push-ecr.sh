#!/usr/bin/env bash
# Create two private ECR repos, build backend/frontend images (multi-arch) and push to ECR
# Usage:
#   ./scripts/build-and-push-ecr.sh <region> <backend-repo-name> <frontend-repo-name> [tag]
# Env:
#   PLATFORM (optional, default: linux/amd64) — e.g., linux/amd64 or linux/arm64
# Example:
#   PLATFORM=linux/amd64 ./scripts/build-and-push-ecr.sh us-west-2 todo-backend todo-frontend v1

set -euo pipefail

if [[ ${#} -lt 3 ]]; then
  echo "Usage: $0 <region> <backend-repo-name> <frontend-repo-name> [tag]"
  exit 1
fi

REGION="$1"
BACKEND_REPO="$2"
FRONTEND_REPO="$3"
TAG="${4:-latest}"
PLATFORM="${PLATFORM:-linux/amd64}"

# Resolve AWS account ID
echo "Resolving AWS account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Ensuring ECR repositories exist..."
create_repo_if_missing() {
  local repo_name="$1"
  if ! aws ecr describe-repositories --repository-names "${repo_name}" --region "${REGION}" >/dev/null 2>&1; then
    echo "Creating ECR repo: ${repo_name}"
    aws ecr create-repository --repository-name "${repo_name}" --image-scanning-configuration scanOnPush=true --region "${REGION}" >/dev/null
  else
    echo "ECR repo already exists: ${repo_name}"
  fi
}

create_repo_if_missing "${BACKEND_REPO}"
create_repo_if_missing "${FRONTEND_REPO}"

BACKEND_IMAGE_URI="${ECR_REGISTRY}/${BACKEND_REPO}:${TAG}"
FRONTEND_IMAGE_URI="${ECR_REGISTRY}/${FRONTEND_REPO}:${TAG}"

echo "Logging into ECR ${ECR_REGISTRY}..."
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."

# Prepare buildx for cross-platform builds (useful on Mac/ARM building x86 images)
echo "Configuring docker buildx (platform=${PLATFORM})..."
if ! docker buildx inspect multiarch-builder >/dev/null 2>&1; then
  docker buildx create --name multiarch-builder --use >/dev/null
else
  docker buildx use multiarch-builder >/dev/null
fi

# Backend: build and push with buildx for the requested platform
echo "Building and pushing backend image (${BACKEND_IMAGE_URI}) for ${PLATFORM}..."
docker buildx build \
  --platform "${PLATFORM}" \
  -t "${BACKEND_IMAGE_URI}" \
  -f "${ROOT_DIR}/backend/Dockerfile" "${ROOT_DIR}/backend" \
  --push

# Frontend: build and push with buildx for the requested platform
echo "Building and pushing frontend image (${FRONTEND_IMAGE_URI}) for ${PLATFORM}..."
docker buildx build \
  --platform "${PLATFORM}" \
  -t "${FRONTEND_IMAGE_URI}" \
  -f "${ROOT_DIR}/frontend/Dockerfile" "${ROOT_DIR}/frontend" \
  --push

cat <<EOF

Done.

Image URIs:
  Backend:  ${BACKEND_IMAGE_URI}
  Frontend: ${FRONTEND_IMAGE_URI}

Next steps:
  - Update Kubernetes manifests to use these images.
    File: k8s-manifests/backend-deployment.yaml
      spec.template.spec.containers[0].image: ${BACKEND_IMAGE_URI}
    File: k8s-manifests/frontend-deployment.yaml
      spec.template.spec.containers[0].image: ${FRONTEND_IMAGE_URI}

  - Or use 'kubectl set image' to update live deployments, e.g.:
    kubectl -n todo-app set image deployment/backend-api backend-api=${BACKEND_IMAGE_URI}
    kubectl -n todo-app set image deployment/frontend-app frontend-app=${FRONTEND_IMAGE_URI}

EOF
