#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# NHN Cloud OpenCost 설정 스크립트
print_info "NHN Cloud OpenCost 설정을 시작합니다..."

# 1. Helm 저장소 추가
print_info "Helm 저장소 추가 중..."
helm repo add opencost-charts https://opencost.github.io/opencost-helm-chart
helm repo update

# 2. 네임스페이스 생성
print_info "OpenCost 네임스페이스 생성 중..."
kubectl create namespace opencost --dry-run=client -o yaml | kubectl apply -f -

# 3. Custom Pricing ConfigMap 적용
print_info "Custom Pricing ConfigMap 적용 중..."
kubectl apply -f nhn-cloud-pricing-configmap.yaml

# 4. OpenCost 설치 (Custom Values 사용)
print_info "OpenCost 설치 중..."
helm install opencost opencost-charts/opencost \
    --namespace opencost \
    -f nhn-cloud-values.yaml

# 5. 설치 확인
print_info "설치 상태 확인 중..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opencost -n opencost --timeout=300s

print_success "NHN Cloud OpenCost 설정이 완료되었습니다!"
print_info "포트 포워딩을 위해 다음 명령어를 실행하세요:"
echo "kubectl port-forward --namespace opencost deployment/opencost 9003:9003"
echo ""
print_info "그 후 http://localhost:9003 에서 OpenCost UI에 접근할 수 있습니다."