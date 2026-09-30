# B4-1: 컴퓨터가 알아서 자기 상태를 점검하게 만들기

Ubuntu에서 역할별 계정과 디렉토리 권한, SSH와 방화벽을 설정합니다. 제공된 agent-app을 일반 사용자로 실행하고 Bash 모니터를 cron에 등록합니다.

## 실행 환경

macOS arm64의 Docker Desktop에서 Ubuntu 24.04 컨테이너를 사용합니다. 컨테이너에 NET_ADMIN 권한을 부여하고 내부 네트워크에서 방화벽을 검증합니다. 호스트에는 SSH 포트나 앱 포트를 공개하지 않습니다.

## Linux 환경

```bash
PRETTY_NAME="Ubuntu 24.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.5 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo
aarch64
GNU bash, version 5.2.21(1)-release (aarch64-unknown-linux-gnu)
OpenSSH_9.6p1 Ubuntu-3ubuntu13.19, OpenSSL 3.0.13 30 Jan 2024
```

Ubuntu 24.04의 arm64 바이너리를 실행합니다. 계정과 SSH, UFW 설정은 이 컨테이너 안에 적용합니다.
