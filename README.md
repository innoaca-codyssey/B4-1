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

## 앱 실행 시 키 경로 오류

```bash
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1001)
[2/5] Verifying Environment Variables     [FAIL]
   >>> Key Path Mismatch. Expected: /home/agent-admin/agent-app/api_keys
[3/5] Checking Required Files             [FAIL]
   >>> Skipped due to previous critical failure.
[4/5] Checking Port Availability          [FAIL]
   >>> Skipped due to previous critical failure.
[5/5] Verifying Log Permission            [FAIL]
   >>> Skipped due to previous critical failure.
--------------------------------------------------
System Boot Failed. Process Terminated.
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess                      
LISTEN 0      128          0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=72,fd=3))
LISTEN 0      128             [::]:20022         [::]:*    users:(("sshd",pid=72,fd=4))
ls: cannot open directory '/home/agent-admin/agent-app/api_keys': Permission denied
ls: cannot open directory '/var/log/agent-app': Permission denied
```

명세의 파일 경로를 AGENT_KEY_PATH에 지정했으나 바이너리는 api_keys 디렉토리를 요구했습니다. 환경변수 검사에서 중단되어 아직 앱 포트가 열리지 않았습니다. QA 계정은 upload_files에 파일을 만들 수 있고, 키와 로그 목록 조회는 거부됩니다.

## 키 파일명 확인

```bash
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1001)
[2/5] Verifying Environment Variables     [OK]
   ... All required Envs correct
[3/5] Checking Required Files             [FAIL]
   >>> Missing File: secret.key
   >>>    (Expected location: /home/agent-admin/agent-app/api_keys/secret.key)
[4/5] Checking Port Availability          [FAIL]
   >>> Skipped due to previous critical failure.
[5/5] Verifying Log Permission            [FAIL]
   >>> Skipped due to previous critical failure.
--------------------------------------------------
System Boot Failed. Process Terminated.
```

경로를 디렉토리로 수정한 뒤에는 secret.key 파일명을 요구했습니다. 명세에 나온 t_secret.key와 함께 같은 테스트 문자열의 secret.key를 생성했습니다.

## 앱 부트와 포트

```bash
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1001)
[2/5] Verifying Environment Variables     [OK]
   ... All required Envs correct
[3/5] Checking Required Files             [OK]
   ... Verified 'secret.key' with correct key string.
[4/5] Checking Port Availability          [OK]
   ... Port 15034 is available.
[5/5] Verifying Log Permission            [OK]
   ... Log directory is writable: /var/log/agent-app
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-09-30 12:55:57,969 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-09-30 12:55:57,969 [INFO] Agent listening at port 15034
2026-09-30 12:55:57,969 [INFO] === Agent Worker Started ===
2026-09-30 12:55:57,969 [INFO]    > Cycle: 0 -> 256MB/Lv10 -> 0
2026-09-30 12:55:57,969 [INFO] --- Step Info: Mode=UP, CPU Lv=1, Mem=0MB ---
2026-09-30 12:55:57,971 [INFO] [Memory] Increasing... (+25 MB) Total: 25 MB
2026-09-30 12:55:57,971 [INFO] [CPU] Occupy core for 1s (Level 1)
2026-09-30 12:55:59,977 [INFO] --- Step Info: Mode=UP, CPU Lv=2, Mem=25MB ---
2026-09-30 12:55:59,992 [INFO] [Memory] Increasing... (+25 MB) Total: 50 MB
2026-09-30 12:55:59,992 [INFO] [CPU] Occupy core for 2s (Level 2)
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess                      
LISTEN 0      128          0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=72,fd=3))
LISTEN 0      1            0.0.0.0:15034      0.0.0.0:*                                
LISTEN 0      128             [::]:20022         [::]:*    users:(("sshd",pid=72,fd=4))
  314     0 agent-a+ agent-app-linux /home/agent-admin/agent-app/agent-app-linux-arm64
  320   314 agent-a+ agent-app-linux /home/agent-admin/agent-app/agent-app-linux-arm64
```

AGENT_KEY_PATH는 api_keys 디렉토리, 키 파일명은 secret.key로 실행했습니다. 제공 바이너리는 같은 경로로 부모와 자식 프로세스를 생성합니다. 리슨 소켓을 가진 자식 프로세스를 모니터링 대상으로 선택합니다.

## 프로세스와 자원 모니터

```bash
+ chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh
+ chmod 750 /home/agent-admin/agent-app/bin/monitor.sh
+ printf 'agent-admin ALL=(root) NOPASSWD: /usr/sbin/ufw status\n'
+ chmod 440 /etc/sudoers.d/agent-monitor
+ visudo -c
/etc/sudoers: parsed OK
/etc/sudoers.d/README: parsed OK
/etc/sudoers.d/agent-monitor: parsed OK
+ ls -l /home/agent-admin/agent-app/bin/monitor.sh
-rwxr-x--- 1 agent-dev agent-core 2252 Sep 30 12:56 /home/agent-admin/agent-app/bin/monitor.sh
+ sudo -u agent-admin bash -c 'source ~/agent.env; /home/agent-admin/agent-app/bin/monitor.sh'
[OK] PID:320 PORT:15034
CPU:2.0% MEM:3.1% RSS:246932KiB DISK_USED:5%
[INFO] Log appended: /var/log/agent-app/monitor.log
+ tail -n 3 /var/log/agent-app/monitor.log
[2026-09-30 12:57:05] PID:320 CPU:2.0% MEM:3.1% DISK_USED:5%
```

pgrep -n으로 바이너리 자식 PID를 고르고 ss로 포트 상태를 따로 확인합니다. CPU는 /proc/PID/stat의 utime/stime 증가분을 1초 간격으로 계산하며 100%는 한 코어를 뜻합니다. 메모리는 RSS를 Linux VM의 MemTotal로 나눈 비율입니다. 컨테이너 메모리 제한 대비 비율과는 다릅니다. 디스크는 df의 루트 파일시스템 사용률입니다. agent-admin은 sudoers에서 ufw status만 실행할 수 있습니다.

## 방화벽 연결 확인

```bash
nc -z -w 2 codyssey-b4 20022
Connection to codyssey-b4 (172.27.0.2) 20022 port [tcp/*] succeeded!
exit=0
nc -z -w 2 codyssey-b4 15034
Connection to codyssey-b4 (172.27.0.2) 15034 port [tcp/*] succeeded!
exit=0
nc -z -w 2 codyssey-b4 15035
exit=1
```

별도 클라이언트 컨테이너에서 20022와 15034에 연결되고, 리스너를 실행한 15035는 연결되지 않았습니다. 호스트 포트 매핑 없이 전용 내부 네트워크에서 확인했습니다.

## cron 등록

```bash
+ printf '* * * * * /bin/bash -c '\''source /home/agent-admin/agent.env; /home/agent-admin/agent-app/bin/monitor.sh'\'' >> /var/log/agent-app/cron.log 2>&1\n'
+ crontab -u agent-admin -
+ service cron start
 * Starting periodic command scheduler cron
   ...done.
+ crontab -u agent-admin -l
* * * * * /bin/bash -c 'source /home/agent-admin/agent.env; /home/agent-admin/agent-app/bin/monitor.sh' >> /var/log/agent-app/cron.log 2>&1
+ date -u
Wed Sep 30 12:58:02 UTC 2026
+ wc -l /var/log/agent-app/monitor.log
1 /var/log/agent-app/monitor.log
```

cron은 agent-admin으로 실행되며 비로그인 셸에서도 환경변수를 읽도록 agent.env를 명시적으로 source합니다. 로그는 >>로 이어 붙이며 >를 사용하면 이전 기록이 덮어써집니다.

## 실패와 경고 분리

```bash
+ sudo -u agent-admin bash -c 'source ~/agent.env; AGENT_PORT=15036 "$AGENT_HOME/bin/monitor.sh"; echo "exit=$?"; AGENT_APP=/missing "$AGENT_HOME/bin/monitor.sh"; echo "exit=$?"'
[ERROR] Port 15036 is not listening
exit=1
[ERROR] Process is not running: /missing
exit=1
+ ufw disable
Firewall stopped and disabled on system startup
+ sudo -u agent-admin bash -c 'source ~/agent.env; "$AGENT_HOME/bin/monitor.sh"; echo "exit=$?"'
[OK] PID:320 PORT:15034
[WARNING] Firewall is inactive or its status is unavailable
CPU:20.0% MEM:1.8% RSS:144140KiB DISK_USED:5%
[INFO] Log appended: /var/log/agent-app/monitor.log
exit=0
+ ufw --force enable
Firewall is active and enabled on system startup
```

프로세스나 리슨 포트가 없으면 자원 로그를 기록하지 않고 1로 종료합니다. 방화벽 비활성은 앱 자체가 멈춘 상태와 구분해 경고만 출력합니다. 비활성 검증 후 UFW를 다시 활성화했습니다.

## 로그 용량 관리

```bash
monitor.log 62 bytes
monitor.log.1 10000000 bytes
monitor.log.2 10000000 bytes
monitor.log.3 10000000 bytes
monitor.log.4 10000000 bytes
monitor.log.5 10000000 bytes
monitor.log.6 10000000 bytes
monitor.log.7 10000000 bytes
monitor.log.8 10000000 bytes
monitor.log.9 10000000 bytes
log files=10
[2026-09-30 13:00:01] PID:320 CPU:11.9% MEM:3.1% DISK_USED:5%
```

로그 회전은 flock으로 직렬화합니다. 다음 줄을 더해 10,000,000바이트를 넘으면 현재 파일을 .1로 옮기고 .9를 제거합니다. 현재 파일과 .1부터 .9까지 최대 10개입니다. 위 검사는 AGENT_LOG_DIR을 별도 테스트 디렉토리로 지정하고 truncate로 10MB 파일을 만드는 과정을 12번 반복한 결과입니다. 실제 cron 로그는 이 검사에 사용하지 않았습니다.

## cron 자동 누적

```bash
Wed Sep 30 13:00:01 UTC 2026
+ date -u
+ wc -l /var/log/agent-app/monitor.log
3 /var/log/agent-app/monitor.log
+ tail -n 6 /var/log/agent-app/monitor.log
[2026-09-30 12:57:05] PID:320 CPU:2.0% MEM:3.1% DISK_USED:5%
[2026-09-30 12:59:02] PID:320 CPU:17.8% MEM:2.4% DISK_USED:5%
[2026-09-30 12:59:08] PID:320 CPU:20.0% MEM:1.8% DISK_USED:5%
+ tail -n 8 /var/log/agent-app/cron.log
[OK] PID:320 PORT:15034
CPU:17.8% MEM:2.4% RSS:195240KiB DISK_USED:5%
[INFO] Log appended: /var/log/agent-app/monitor.log
[OK] PID:320 PORT:15034
+ ufw status
Status: active

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW       Anywhere                  
15034/tcp                  ALLOW       Anywhere                  
20022/tcp (v6)             ALLOW       Anywhere (v6)             
15034/tcp (v6)             ALLOW       Anywhere (v6)             

```

12:58:02 UTC에 1행이던 monitor.log에 12:59의 cron 기록이 추가되었습니다. 13:00:01 조회 시 해당 분의 샘플은 진행 중이었습니다. 임계치 초과 경고는 cron.log에 남으며 모니터는 계속 실행됩니다.

## 점검과 실행 방법

- [x] SSH 포트 변경(20022) 및 Root 원격 접속 차단 설정 확인 내역
- [x] 방화벽(UFW 또는 firewalld) 활성화 및 20022/tcp, 15034/tcp만 허용 내역
- [x] 계정/그룹(agent-admin/dev/test, agent-common/core) 생성 확인 내역
- [x] 디렉토리 구조 및 권한(ACL 포함) 확인 내역
- [x] 앱 Boot Sequence 5단계 [OK] 및 "Agent READY" 확인 내역
- [x] monitor.sh 실행 결과(프로세스/포트/리소스/경고) 내역
- [x] /var/log/agent-app/monitor.log 누적 기록 확인(최근 라인) 내역
- [x] crontab 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역

Ubuntu 환경에 openssh-server, ufw, acl, cron, sudo, procps, iproute2 패키지를 설치합니다. 위 명령으로 계정과 경로를 구성한 뒤 제공 arm64 바이너리를 `$AGENT_HOME/agent-app-linux-arm64`에 배치합니다. x86 환경에서는 해당 아키텍처의 바이너리 경로를 AGENT_APP으로 지정합니다. monitor.sh는 `$AGENT_HOME/bin`에 복사하고 agent-dev:agent-core, 750을 적용합니다.

실제 바이너리의 환경변수 설정은 다음과 같습니다.

```bash
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=/var/log/agent-app
```

일반 계정에서 앱을 실행한 뒤 다른 터미널에서 monitor.sh를 실행합니다. cron에는 위 설정을 담은 agent.env를 source하는 명령을 등록합니다. 모니터의 상태 경고는 방화벽이나 자원 여유가 줄었음을 뜻하며, 앱 중단을 의미하지 않습니다. CPU 20%, MEM 10%, 디스크 80% 초과 조건을 각각 비교합니다.

## 운영 시 확인 순서

웹 서버로 대상을 바꾸면 AGENT_APP과 AGENT_PORT를 해당 실행 경로와 포트로 맞추고 로그 위치와 임계값을 서비스에 맞게 조정합니다. 프로세스가 있으나 포트가 없으면 부트 로그, 환경변수, ss의 리슨 주소와 포트, 포트 충돌을 확인합니다. 프로세스의 존재만으로 서비스가 준비되었다고 판단하지 않습니다.

디스크가 부족하면 먼저 어떤 로그가 증가했는지와 남은 공간을 확인하고, 필요한 장애 기록을 별도로 보존한 뒤 오래된 회전 파일을 정리합니다. 이후 발생 원인, 기록 빈도, 보존 기간을 조정합니다. 10MB/10개 정책은 monitor.log 계열에 적용하며 app.log와 cron.log는 별도로 관리해야 합니다.

## cron 샘플 완료 확인

```bash
Wed Sep 30 13:00:53 UTC 2026
4 /var/log/agent-app/monitor.log
[2026-09-30 12:57:05] PID:320 CPU:2.0% MEM:3.1% DISK_USED:5%
[2026-09-30 12:59:02] PID:320 CPU:17.8% MEM:2.4% DISK_USED:5%
[2026-09-30 12:59:08] PID:320 CPU:20.0% MEM:1.8% DISK_USED:5%
[2026-09-30 13:00:02] PID:320 CPU:13.0% MEM:3.1% DISK_USED:5%
[OK] PID:320 PORT:15034
CPU:17.8% MEM:2.4% RSS:195240KiB DISK_USED:5%
[INFO] Log appended: /var/log/agent-app/monitor.log
[OK] PID:320 PORT:15034
CPU:13.0% MEM:3.1% RSS:246260KiB DISK_USED:5%
[INFO] Log appended: /var/log/agent-app/monitor.log
```

앞선 13:00:01 조회는 해당 분의 샘플이 기록되기 전이었습니다. 위 조회에서 새 시각의 로그가 실제로 추가된 것을 확인했습니다.
