# OpenCost 설치 및 사용 가이드

## 개요

OpenCost는 Kubernetes 환경에서 비용 모니터링을 제공하는 오픈소스 도구입니다. 이 문서는 OpenCost 설치 방법과 API 사용법을 설명합니다.

## 설치 방법

### 1. 자동 설치 스크립트 사용

프로젝트에 포함된 자동 설치 스크립트를 사용하여 간편하게 설치할 수 있습니다.

```bash
# 실행 권한 부여
chmod +x ./install-opencost.sh

# 기본 설치 (Helm 사용)
./install-opencost.sh

# 도움말 보기
./install-opencost.sh -h
```

#### 스크립트 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `-m, --method` | 설치 방법 (`helm` 또는 `manifest`) | `helm` |
| `-n, --namespace` | Kubernetes 네임스페이스 | `opencost` |
| `-p, --prometheus` | Prometheus 함께 설치 (Helm만) | `false` |
| `-f, --values-file` | 커스텀 Helm values 파일 | - |
| `-h, --help` | 도움말 표시 | - |

#### 사용 예시

```bash
# Kubernetes manifest로 설치
./install-opencost.sh -m manifest

# Prometheus와 함께 설치
./install-opencost.sh -p

# 커스텀 네임스페이스에 설치
./install-opencost.sh -n my-opencost

# 커스텀 values 파일로 설치
./install-opencost.sh -f custom-values.yaml
```

### 2. 수동 설치

#### 2.1 Helm으로 설치 (권장)

```bash
# Helm 저장소 추가
helm repo add opencost-charts https://opencost.github.io/opencost-helm-chart
helm repo update

# 네임스페이스 생성
kubectl create namespace opencost

# OpenCost 설치
helm install opencost opencost-charts/opencost --namespace opencost
```

#### 2.2 Kubernetes Manifest로 설치

```bash
# Kubernetes manifest로 설치
kubectl apply -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/opencost.yaml
```

### 3. Prometheus 설치 (필요시)

OpenCost는 Prometheus가 필요합니다. 별도로 설치하려면:

```bash
# Prometheus 네임스페이스 생성
kubectl create namespace prometheus-system

# Prometheus 설치 (node-exporter 비활성화)
helm install prometheus --repo https://prometheus-community.github.io/helm-charts prometheus \
    --namespace prometheus-system \
    --set prometheus-node-exporter.enabled=false \
    --set prometheus-pushgateway.enabled=false \
    --set alertmanager.enabled=false \
    -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/prometheus/extraScrapeConfigs.yaml
```

> **Note**: Docker Desktop 환경에서는 node-exporter가 권한 문제로 실행되지 않을 수 있습니다. 위 명령어는 node-exporter를 비활성화한 상태로 설치합니다.

## 설치 확인

### 1. Pod 상태 확인

```bash
# OpenCost pod 상태 확인
kubectl get pods -n opencost

# 로그 확인
kubectl logs -f -n opencost deployment/opencost
```

### 2. 서비스 확인

```bash
# OpenCost 서비스 확인
kubectl get svc -n opencost
```

## 접근 방법

### 1. Port Forward 설정

```bash
# OpenCost UI 및 API 접근을 위한 포트 포워딩
kubectl port-forward --namespace opencost deployment/opencost 9003:9003
```

### 2. 웹 UI 접근

브라우저에서 다음 URL로 접근:
```
http://localhost:9003
```

## API 엔드포인트

OpenCost는 RESTful API를 제공합니다. 포트 포워딩 후 다음 엔드포인트를 사용할 수 있습니다.

### 기본 URL
```
http://localhost:9003
```

### 주요 API 엔드포인트

#### 1. Allocation API
Kubernetes 워크로드의 비용 할당 정보를 제공합니다.

```bash
# 1일간 할당 비용 데이터
curl "http://localhost:9003/allocation?window=1d"

# 7일간 할당 비용 데이터
curl "http://localhost:9003/allocation?window=7d"

# 네임스페이스별로 집계
curl "http://localhost:9003/allocation?window=1d&aggregate=namespace"

# 컨테이너별로 집계
curl "http://localhost:9003/allocation?window=1d&aggregate=container"

# 클러스터별로 집계
curl "http://localhost:9003/allocation?window=1d&aggregate=cluster"
```

#### 2. Health Check API
```bash
# 상태 확인
curl "http://localhost:9003/healthz"
```

#### 3. Metrics API
```bash
# Prometheus 형식 메트릭
curl "http://localhost:9003/metrics"
```

### API 파라미터

#### 공통 파라미터

| 파라미터 | 설명 | 예시 |
|----------|------|------|
| `window` | 조회 기간 | `1d`, `7d`, `30d`, `2023-01-01T00:00:00Z,2023-01-02T00:00:00Z` |
| `aggregate` | 집계 기준 | `namespace`, `cluster`, `container`, `controller`, `service` |
| `step` | 데이터 포인트 간격 | `1h`, `1d` |
| `resolution` | Prometheus 쿼리 해상도 | `1m`, `5m` |
| `includeIdle` | 유휴 비용 포함 여부 | `true`, `false` |

#### window 파라미터 형식

```bash
# 상대 시간
window=1d     # 1일
window=7d     # 7일
window=30d    # 30일

# 절대 시간 (ISO 8601)
window=2023-01-01T00:00:00Z,2023-01-02T00:00:00Z
```

### API 응답 예시

#### Allocation API 응답

```json
{
  "code": 200,
  "data": [
    {
      "default-cluster/docker-desktop/opencost/opencost-6ff4864d9b-5mps9/opencost": {
        "name": "default-cluster/docker-desktop/opencost/opencost-6ff4864d9b-5mps9/opencost",
        "properties": {
          "cluster": "default-cluster",
          "node": "docker-desktop",
          "container": "opencost",
          "namespace": "opencost",
          "pod": "opencost-6ff4864d9b-5mps9"
        },
        "window": {
          "start": "2025-09-08T00:00:00Z",
          "end": "2025-09-09T00:00:00Z"
        },
        "cpuCost": 0.00004,
        "ramCost": 0.00003,
        "totalCost": 0.00007
      }
    }
  ]
}
```

## 문제 해결

### 1. Pod가 CrashLoopBackOff 상태인 경우

Docker Desktop 환경에서 node-exporter가 실행되지 않을 수 있습니다:

```bash
# Prometheus에서 node-exporter 비활성화
helm upgrade prometheus --repo https://prometheus-community.github.io/helm-charts prometheus \
    -n prometheus-system \
    --set prometheus-node-exporter.enabled=false \
    --set prometheus-pushgateway.enabled=false \
    --set alertmanager.enabled=false
```

### 2. API 404 오류

API 엔드포인트에 필수 파라미터가 누락된 경우입니다:

```bash
# 잘못된 사용
curl "http://localhost:9003/allocation"  # 404 오류

# 올바른 사용
curl "http://localhost:9003/allocation?window=1d"  # 정상 응답
```

### 3. 포트 포워딩 확인

```bash
# 포트 포워딩 상태 확인
ps aux | grep "kubectl port-forward"

# 포트 사용 확인
lsof -i :9003
```

## 업그레이드

### Helm으로 설치한 경우

```bash
# Helm 저장소 업데이트
helm repo update

# OpenCost 업그레이드
helm upgrade opencost opencost-charts/opencost --namespace opencost
```

### Manifest로 설치한 경우

```bash
# 최신 manifest 적용
kubectl apply -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/opencost.yaml
```

## 제거

### Helm으로 설치한 경우

```bash
# OpenCost 제거
helm uninstall opencost --namespace opencost

# 네임스페이스 제거 (선택사항)
kubectl delete namespace opencost
```

### Manifest로 설치한 경우

```bash
# OpenCost 제거
kubectl delete -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/opencost.yaml
```

## NHN Cloud와 같은 미지원 CSP 연동 방법

Billing API를 지원하지 않는 클라우드 서비스 제공업체(CSP)에서도 OpenCost를 사용할 수 있습니다.

### 1. Custom Pricing 설정

#### 1.1 ConfigMap을 이용한 방법

```bash
# Custom pricing ConfigMap 적용
kubectl apply -f nhn-cloud-pricing-configmap.yaml
```

ConfigMap 예시 (`nhn-cloud-pricing-configmap.yaml`):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: opencost-custom-pricing
  namespace: opencost
data:
  default.json: |
    {
      "provider": "custom",
      "description": "NHN Cloud custom pricing configuration",
      "CPU": "0.025",
      "spotCPU": "0.010",
      "RAM": "0.003",
      "spotRAM": "0.001",
      "GPU": "0.80",
      "storage": "0.00004",
      "zoneNetworkEgress": "0.008",
      "regionNetworkEgress": "0.012",
      "internetNetworkEgress": "0.10",
      "loadBalancer": "0.020"
    }
```

#### 1.2 Helm Values를 이용한 방법

```bash
# Custom values 파일로 설치
helm install opencost opencost-charts/opencost \
    --namespace opencost \
    -f nhn-cloud-values.yaml
```

Values 파일 예시 (`nhn-cloud-values.yaml`):
```yaml
opencost:
  customPricing:
    enabled: true
    costModel:
      description: "NHN Cloud custom pricing"
      provider: "custom"
      CPU: "0.025"        # vCPU 시간당 비용 (USD)
      RAM: "0.003"        # GB RAM 시간당 비용 (USD)
      storage: "0.00004"  # GB 스토리지 시간당 비용 (USD)
      internetNetworkEgress: "0.10"  # 네트워크 송신 비용 (GB당)
```

### 2. 기존 OpenCost에 Custom Pricing 적용

#### 2.1 업그레이드 방식 (권장)

기존 OpenCost 설치를 유지하면서 custom pricing만 적용하는 방법입니다:

```bash
# 1. 현재 설치 상태 확인
kubectl get pods -n opencost
helm list -n opencost

# 2. Custom pricing ConfigMap 적용
kubectl apply -f nhn-cloud-pricing-configmap.yaml

# 3. Helm 업그레이드로 custom pricing 적용
helm upgrade opencost opencost-charts/opencost \
    --namespace opencost \
    -f nhn-cloud-values.yaml

# 4. Pod 재시작 확인
kubectl get pods -n opencost -w

# 5. 새로운 설정 확인 (로그 체크)
kubectl logs -f -n opencost deployment/opencost -c opencost
```

#### 2.2 재설치 방식 (완전 초기화)

기존 데이터를 완전히 초기화하고 새로 설치하는 방법입니다:

```bash
# 1. 기존 OpenCost 제거
helm uninstall opencost -n opencost

# 2. ConfigMap 적용
kubectl apply -f nhn-cloud-pricing-configmap.yaml

# 3. NHN Cloud 전용 스크립트로 재설치
chmod +x ./setup-nhn-cloud-opencost.sh
./setup-nhn-cloud-opencost.sh
```

#### 2.3 설정 적용 확인

Custom pricing이 올바르게 적용되었는지 확인하는 방법:

```bash
# OpenCost 로그에서 pricing 정보 확인
kubectl logs -n opencost deployment/opencost -c opencost | grep -i pricing

# API를 통해 현재 설정 확인
kubectl port-forward -n opencost deployment/opencost 9003:9003 &
curl "http://localhost:9003/allocation?window=1h" | jq '.'

# Pod 상태 및 재시작 여부 확인
kubectl get pods -n opencost
kubectl describe pod -n opencost $(kubectl get pods -n opencost -o jsonpath='{.items[0].metadata.name}')
```

### 3. 자동 설치 스크립트 (신규 설치용)

처음부터 NHN Cloud 설정으로 OpenCost를 설치하는 경우:

```bash
# 실행 권한 부여
chmod +x ./setup-nhn-cloud-opencost.sh

# NHN Cloud 환경에 OpenCost 설치
./setup-nhn-cloud-opencost.sh
```

### 4. 비용 정보 수집 (선택사항)

실제 클라우드 비용 정보를 수집하려면 별도의 cost exporter를 구축할 수 있습니다:

```bash
# Cost exporter 배포
kubectl apply -f nhn-cloud-cost-exporter.yaml
```

### 5. 커스텀 가격 설정 가이드

각 리소스 유형별 가격을 실제 NHN Cloud 요금에 맞게 조정하세요:

| 리소스 | 설명 | 단위 | 예시 값 |
|--------|------|------|---------|
| `CPU` | vCPU 비용 | 시간당 USD | `0.025` |
| `RAM` | 메모리 비용 | GB/시간당 USD | `0.003` |
| `storage` | 스토리지 비용 | GB/시간당 USD | `0.00004` |
| `internetNetworkEgress` | 인터넷 송신 비용 | GB당 USD | `0.10` |
| `loadBalancer` | 로드밸런서 비용 | 시간당 USD | `0.020` |

### 6. 환경 변수 설정

OpenCost 컨테이너에 다음 환경 변수를 설정할 수 있습니다:

```yaml
env:
  - name: CLOUD_PROVIDER_API_KEY
    value: "default-key"
  - name: CLUSTER_ID
    value: "nhn-cloud-cluster"
  - name: CUSTOM_PRICING_CONFIG_PATH
    value: "/tmp/custom-config/default.json"
```

## 참고 자료

- [OpenCost 공식 문서](https://opencost.io/docs/)
- [OpenCost GitHub](https://github.com/opencost/opencost)
- [API 문서](https://opencost.io/docs/integrations/api/)
- [Helm Chart](https://github.com/opencost/opencost-helm-chart)
- [On-Premises 설정](https://opencost.io/docs/configuration/on-prem/)
- [Custom Pricing 가이드](https://opencost.io/docs/configuration/)