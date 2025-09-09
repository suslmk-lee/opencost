# OpenCost API 완전 가이드

## 개요

OpenCost는 Kubernetes 환경에서 비용 모니터링을 위한 강력한 RESTful API를 제공합니다. 이 문서는 모든 API 엔드포인트와 실제 사용 예시를 포함합니다.

## 기본 설정

### API 접근 방법

```bash
# 포트 포워딩 설정
kubectl port-forward --namespace opencost deployment/opencost 9003:9003

# 기본 URL
BASE_URL="http://localhost:9003"
```

## 주요 API 엔드포인트

### 1. Allocation API (`/allocation`)

Kubernetes 워크로드의 비용 할당 정보를 제공하는 핵심 API입니다.

#### 기본 구문
```
GET /allocation?window={duration}&[additional_params]
```

#### 필수 파라미터

| 파라미터 | 설명 | 예시 | 필수 여부 |
|----------|------|------|-----------|
| `window` | 조회 기간 | `1d`, `7d`, `30d` | ✅ 필수 |

#### 선택적 파라미터

| 파라미터 | 설명 | 가능한 값 | 기본값 |
|----------|------|----------|--------|
| `aggregate` | 집계 기준 | `cluster`, `node`, `namespace`, `controller`, `service`, `pod`, `container` | - |
| `step` | 데이터 포인트 간격 | `1h`, `6h`, `1d` | `window/100` |
| `resolution` | Prometheus 쿼리 해상도 | `1m`, `5m`, `1h` | `1m` |
| `includeIdle` | 유휴 비용 포함 여부 | `true`, `false` | `true` |
| `shareIdle` | 유휴 비용 분산 여부 | `true`, `false` | `false` |
| `idleByNode` | 노드별 유휴 비용 계산 | `true`, `false` | `false` |
| `filter` | 필터 조건 | `namespace:"kube-system"` | - |

#### 실제 사용 예시

```bash
# 1. 기본 조회 (1일간)
curl -G "${BASE_URL}/allocation" \
  -d "window=1d"

# 2. 네임스페이스별 7일간 비용 조회
curl -G "${BASE_URL}/allocation" \
  -d "window=7d" \
  -d "aggregate=namespace"

# 3. 유휴 비용 분산된 컨테이너별 비용
curl -G "${BASE_URL}/allocation" \
  -d "window=1d" \
  -d "aggregate=container" \
  -d "shareIdle=true"

# 4. 특정 네임스페이스 필터링
curl -G "${BASE_URL}/allocation" \
  -d "window=7d" \
  -d "aggregate=pod" \
  -d 'filter=namespace:"opencost"'

# 5. 시간 단위별 상세 분석
curl -G "${BASE_URL}/allocation" \
  -d "window=1d" \
  -d "step=1h" \
  -d "resolution=5m"
```

#### 응답 예시

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
        "cpuCores": 0.01,
        "cpuCost": 0.00004,
        "ramBytes": 57671680,
        "ramCost": 0.00003,
        "totalCost": 0.00007,
        "totalEfficiency": 0.45
      }
    }
  ]
}
```

### 2. Assets API (`/assets`)

클러스터의 개별 자산(노드, 디스크, 네트워크 등) 비용 정보를 제공합니다.

#### 기본 구문
```
GET /assets?window={duration}
```

#### 사용 예시

```bash
# 1. 기본 자산 정보 조회 (7일간)
curl -G "${BASE_URL}/assets" \
  -d "window=7d"

# 2. 1일간 자산 정보 상세 조회
curl -G "${BASE_URL}/assets" \
  -d "window=1d" \
  -d "aggregate=type"

# 3. 특정 기간 자산 비용 추이
curl -G "${BASE_URL}/assets" \
  -d "window=2025-09-01T00:00:00Z,2025-09-08T00:00:00Z"
```

#### 응답 예시

```json
{
  "code": 200,
  "data": [
    {
      "cluster=default-cluster:name=docker-desktop:type=node": {
        "type": "node",
        "name": "docker-desktop", 
        "properties": {
          "cluster": "default-cluster",
          "providerID": "docker-desktop"
        },
        "labels": {
          "kubernetes.io/arch": "arm64",
          "kubernetes.io/os": "linux"
        },
        "start": "2025-09-08T00:00:00Z",
        "end": "2025-09-09T00:00:00Z",
        "minutes": 1440.0,
        "cpuCores": 4.0,
        "cpuCoreHours": 96.0,
        "cpuCost": 3.03,
        "ramBytes": 8589934592,
        "ramByteHours": 206158430208,
        "ramCost": 0.87,
        "totalCost": 3.90
      }
    }
  ]
}
```

### 3. Cloud Costs API (`/cloudCost`)

클라우드 공급업체의 실제 청구 데이터를 조회합니다.

#### 기본 구문
```
GET /cloudCost?window={duration}
```

#### 파라미터

| 파라미터 | 설명 | 가능한 값 | 기본값 |
|----------|------|----------|--------|
| `window` | 조회 기간 | `1d`, `7d`, `30d` | - |
| `aggregate` | 집계 기준 | `provider`, `account`, `service` | - |
| `accumulate` | 누적 단위 | `hour`, `day`, `week`, `month` | - |
| `filter` | 필터 조건 | `provider:"AWS"` | - |

#### 사용 예시

```bash
# 1. 프로바이더별 7일간 클라우드 비용
curl -G "${BASE_URL}/cloudCost" \
  -d "window=7d" \
  -d "aggregate=provider"

# 2. 서비스별 월간 비용 분석
curl -G "${BASE_URL}/cloudCost" \
  -d "window=30d" \
  -d "aggregate=service" \
  -d "accumulate=day"

# 3. AWS 특정 계정 비용 필터링
curl -G "${BASE_URL}/cloudCost" \
  -d "window=7d" \
  -d 'filter=provider:"AWS",account:"123456789"'
```

### 4. Custom Costs API (`/customCost`)

외부 서비스 비용을 통합 관리합니다.

#### 엔드포인트

- `/customCost/timeseries`: 시계열 데이터
- `/customCost/total`: 총 비용 요약

#### 사용 예시

```bash
# 1. 외부 서비스 시계열 비용 데이터
curl -G "${BASE_URL}/customCost/timeseries" \
  -d "window=7d" \
  -d "aggregate=domain"

# 2. 외부 서비스 총 비용
curl -G "${BASE_URL}/customCost/total" \
  -d "window=30d" \
  -d "aggregate=providerId"
```

### 5. 기타 유용한 엔드포인트

#### Health Check
```bash
curl "${BASE_URL}/healthz"
```

#### Prometheus 메트릭
```bash
curl "${BASE_URL}/metrics"
```

#### 버전 정보
```bash
curl "${BASE_URL}/version"
```

## 고급 사용 예시

### 1. 비용 최적화 분석

```bash
# 유휴 리소스가 많은 네임스페이스 찾기
curl -G "${BASE_URL}/allocation" \
  -d "window=7d" \
  -d "aggregate=namespace" \
  -d "includeIdle=true" | \
jq '.data[0] | to_entries | map(select(.value.totalEfficiency < 0.3)) | .[].key'
```

### 2. 비용 추이 분석

```bash
# 일별 비용 추이 (최근 30일)
curl -G "${BASE_URL}/allocation" \
  -d "window=30d" \
  -d "step=1d" \
  -d "aggregate=cluster" | \
jq '.data | map(keys[0] as $key | .[$key] | {date: .start, cost: .totalCost})'
```

### 3. 리소스 효율성 리포트

```bash
# 컨테이너별 효율성 분석
curl -G "${BASE_URL}/allocation" \
  -d "window=7d" \
  -d "aggregate=container" | \
jq '.data[0] | to_entries | map({
  container: .key | split("/")[-1],
  cost: .value.totalCost,
  efficiency: .value.totalEfficiency,
  cpuEfficiency: .value.cpuEfficiency,
  ramEfficiency: .value.ramEfficiency
}) | sort_by(.efficiency)'
```

### 4. 네임스페이스별 비용 청구서

```bash
# 월간 네임스페이스 비용 리포트
curl -G "${BASE_URL}/allocation" \
  -d "window=30d" \
  -d "aggregate=namespace" \
  -d "shareIdle=true" | \
jq '.data[0] | to_entries | map({
  namespace: .key | split("/")[2],
  totalCost: .value.totalCost,
  cpuCost: .value.cpuCost,
  ramCost: .value.ramCost,
  storageCost: .value.pvCost
}) | sort_by(-.totalCost)'
```

## 에러 처리

### 일반적인 HTTP 상태 코드

- `200`: 성공
- `400`: 잘못된 요청 (파라미터 오류)
- `500`: 서버 내부 오류

### 에러 응답 예시

```json
{
  "code": 400,
  "message": "invalid window format: missing required parameter 'window'"
}
```

## API 사용 시 주의사항

### 1. 성능 고려사항

- **해상도**: 높은 해상도(1m)는 더 정확하지만 느림
- **기간**: 긴 조회 기간은 응답 시간이 길어짐
- **집계**: 적절한 집계 레벨 선택으로 성능 향상

### 2. 정확도 vs 성능 트레이드오프

| Resolution | 단기 Pod 정확도 | 장기 Pod 정확도 | 성능 |
|------------|----------------|----------------|------|
| 1m | 95-99% | 99%+ | 느림 |
| 5m | 90-95% | 95-99% | 보통 |
| 1h | 70-90% | 90-95% | 빠름 |

### 3. 권장 사항

```bash
# 대시보드용 (실시간)
window=1d&resolution=5m&step=1h

# 리포트용 (정확성 중시)
window=30d&resolution=1m&step=1d

# 빠른 조회용
window=7d&resolution=1h&step=6h
```

## 스크립팅 예시

### Bash 스크립트 - 일간 비용 리포트

```bash
#!/bin/bash

BASE_URL="http://localhost:9003"
DATE=$(date '+%Y-%m-%d')

echo "=== OpenCost Daily Report ($DATE) ==="

# 네임스페이스별 비용
echo -e "\n📊 Top 5 Expensive Namespaces:"
curl -s -G "${BASE_URL}/allocation" \
  -d "window=1d" \
  -d "aggregate=namespace" | \
jq -r '.data[0] | to_entries | 
  map({ns: (.key | split("/")[2]), cost: .value.totalCost}) | 
  sort_by(-.cost) | .[0:5] | 
  .[] | "\(.ns): $\(.cost | @json)"'

# 총 비용
echo -e "\n💰 Total Daily Cost:"
curl -s -G "${BASE_URL}/allocation" \
  -d "window=1d" | \
jq -r '.data[0] | [.[]] | map(.totalCost) | add | "$\(.)"'
```

### Python 스크립트 - 비용 분석

```python
import requests
import json
from datetime import datetime

BASE_URL = "http://localhost:9003"

def get_allocation_data(window="7d", aggregate="namespace"):
    """OpenCost allocation 데이터 조회"""
    url = f"{BASE_URL}/allocation"
    params = {
        "window": window,
        "aggregate": aggregate
    }
    
    response = requests.get(url, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error: {response.status_code}")
        return None

def analyze_costs():
    """비용 분석 함수"""
    data = get_allocation_data()
    
    if not data or not data.get('data'):
        print("No data available")
        return
    
    allocations = data['data'][0]
    
    # 네임스페이스별 비용 분석
    namespace_costs = {}
    for key, allocation in allocations.items():
        namespace = allocation['properties'].get('namespace', 'unknown')
        cost = allocation.get('totalCost', 0)
        
        if namespace in namespace_costs:
            namespace_costs[namespace] += cost
        else:
            namespace_costs[namespace] = cost
    
    # 결과 출력
    print("=== Namespace Cost Analysis ===")
    sorted_costs = sorted(namespace_costs.items(), key=lambda x: x[1], reverse=True)
    
    for namespace, cost in sorted_costs:
        print(f"{namespace}: ${cost:.4f}")

if __name__ == "__main__":
    analyze_costs()
```

## 참고 자료

- [OpenCost API 공식 문서](https://opencost.io/docs/integrations/api/)
- [API 예시 모음](https://opencost.io/docs/integrations/api-examples/)
- [Postman Collection](https://www.postman.com/opencost)
- [OpenCost GitHub](https://github.com/opencost/opencost)