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

## SSH와 역할별 권한

```bash
+ set -e
+ groupadd agent-common
+ groupadd agent-core
+ useradd -m -s /bin/bash -G agent-common,agent-core agent-admin
+ useradd -m -s /bin/bash -G agent-common,agent-core agent-dev
+ useradd -m -s /bin/bash -G agent-common agent-test
+ chmod 755 /home/agent-admin
+ install -d -o agent-admin -g agent-common -m 2750 /home/agent-admin/agent-app
+ install -d -o agent-admin -g agent-common -m 2770 /home/agent-admin/agent-app/upload_files
+ install -d -o agent-admin -g agent-core -m 2770 /home/agent-admin/agent-app/api_keys /var/log/agent-app
+ install -d -o agent-dev -g agent-core -m 2750 /home/agent-admin/agent-app/bin
+ setfacl -m d:u::rwx,d:g::rwx,d:o::--- /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
+ printf 'agent_api_key_test\n'
+ chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys/t_secret.key
+ chmod 660 /home/agent-admin/agent-app/api_keys/t_secret.key
+ printf 'export AGENT_HOME=/home/agent-admin/agent-app\nexport AGENT_PORT=15034\nexport AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files\nexport AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys/t_secret.key\nexport AGENT_LOG_DIR=/var/log/agent-app\n'
+ chown agent-admin:agent-core /home/agent-admin/agent.env
+ chmod 640 /home/agent-admin/agent.env
+ printf 'Port 20022\nPermitRootLogin no\n'
+ mkdir -p /run/sshd
+ sshd -t
+ /usr/sbin/sshd
+ ufw default deny incoming
Default incoming policy changed to 'deny'
(be sure to update your rules accordingly)
+ ufw default allow outgoing
Default outgoing policy changed to 'allow'
(be sure to update your rules accordingly)
+ ufw allow 20022/tcp
Rules updated
Rules updated (v6)
+ ufw allow 15034/tcp
Rules updated
Rules updated (v6)
+ ufw --force enable
Firewall is active and enabled on system startup
+ id agent-admin
uid=1001(agent-admin) gid=1003(agent-admin) groups=1003(agent-admin),1001(agent-common),1002(agent-core)
+ id agent-dev
uid=1002(agent-dev) gid=1004(agent-dev) groups=1004(agent-dev),1001(agent-common),1002(agent-core)
+ id agent-test
uid=1003(agent-test) gid=1005(agent-test) groups=1005(agent-test),1001(agent-common)
+ sshd -T
+ sed -n '/^port /p;/^permitrootlogin /p'
port 20022
permitrootlogin no
+ ss -ltnp
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess                      
LISTEN 0      128          0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=72,fd=3))
LISTEN 0      128             [::]:20022         [::]:*    users:(("sshd",pid=72,fd=4))
+ ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW IN    Anywhere                  
15034/tcp                  ALLOW IN    Anywhere                  
20022/tcp (v6)             ALLOW IN    Anywhere (v6)             
15034/tcp (v6)             ALLOW IN    Anywhere (v6)             

+ ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
drwxr-s---  5 agent-admin agent-common 4096 Sep 30 12:53 /home/agent-admin/agent-app
drwxrws---+ 2 agent-admin agent-core   4096 Sep 30 12:53 /home/agent-admin/agent-app/api_keys
drwxrws---+ 2 agent-admin agent-common 4096 Sep 30 12:53 /home/agent-admin/agent-app/upload_files
drwxrws---+ 2 agent-admin agent-core   4096 Sep 30 12:53 /var/log/agent-app
+ getfacl -p /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
# file: /home/agent-admin/agent-app/upload_files
# owner: agent-admin
# group: agent-common
# flags: -s-
user::rwx
group::rwx
other::---
default:user::rwx
default:group::rwx
default:other::---

# file: /home/agent-admin/agent-app/api_keys
# owner: agent-admin
# group: agent-core
# flags: -s-
user::rwx
group::rwx
other::---
default:user::rwx
default:group::rwx
default:other::---

# file: /var/log/agent-app
# owner: agent-admin
# group: agent-core
# flags: -s-
user::rwx
group::rwx
other::---
default:user::rwx
default:group::rwx
default:other::---

```

SSH의 실제 적용값은 sshd -T로 확인했습니다. 비밀번호 대입 공격을 줄이기 위해 기본 포트를 변경하고 Root 직접 로그인을 막습니다. 포트 변경만으로 인증을 대신할 수는 없습니다. 공용 업로드는 agent-common, 키와 로그는 agent-core로 제한합니다. setgid와 기본 ACL은 새 파일에도 공유 그룹과 권한이 이어지도록 적용합니다. 위 출력은 bash -x로 수집한 명령과 결과이며 컨테이너의 시각은 UTC입니다.
