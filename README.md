# phantom-cloud-images

Phantom-cloud에서 직접 빌드하는 컨테이너 이미지의 소스와 CI입니다.
결정 근거: [ADR-0006](https://github.com/Phantom-s-Lab/Phantom-cloud/blob/main/adr/0006-image-ci-gitops-cd.md)

## 이미지

| 디렉터리 | 이미지 | 설명 |
|---|---|---|
| `tenant-base/` | `ghcr.io/phantom-s-lab/tenant-base` | 테넌트 SSH 베이스 이미지 (Alpine + OpenSSH, 공개키 인증만) |

## 파이프라인

```
PR    : hadolint → 빌드 → 스모크 테스트 → Trivy (CRITICAL 시 실패), 푸시 안 함
main  : 위 검증 → arm64/amd64 빌드 → GHCR 푸시 (태그 sha-<커밋 7자리>)
        → phantom-cloud-gitops의 tenant 차트 이미지 태그 변경 PR 자동 생성
        → PR 병합 시 ArgoCD가 배포
```

## tenant-base 실행 규칙

- SSH 포트: 2222, 로그인 사용자: `tenant`
- 비밀번호·root 로그인 차단, sudo 미설치
- 호스트 키와 공개키는 이미지에 포함하지 않음
  - 호스트 키: `/etc/ssh/hostkeys/`에 Secret으로 마운트 (없으면 컨테이너 시작 시 생성)
  - 공개키: `/etc/ssh/authorized_keys/tenant`에 Secret으로 마운트

## 로컬 확인

```bash
docker build -t tenant-base:test tenant-base
./tenant-base/test.sh tenant-base:test
```

## 필요한 Secret

| 이름 | 용도 |
|---|---|
| `GITOPS_PR_TOKEN` | phantom-cloud-gitops에 배포 PR 생성 (fine-grained PAT: 해당 레포 한정, Contents·Pull requests 쓰기) |
