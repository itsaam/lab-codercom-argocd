#!/usr/bin/env bash
set -euo pipefail
if [ "$(id -u)" -eq 0 ]; then
  echo 'Lancer sur Sunny avec votre compte habituel, sans sudo devant le script.' >&2
  exit 1
fi
key="$HOME/.ssh/coder_lab_ed25519"
test -f "$key" || { echo "Clé absente : $key" >&2; exit 1; }
user=$(id -un)
uid=$(id -u)
ssh_args=(-i "$key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -p 2222 coder@127.0.0.1)
# Vérifier les accès avant de modifier les services.
sudo -v
ssh "${ssh_args[@]}" 'sudo -n true && command -v k3s' >/dev/null
sudo systemctl stop coder-lab-tunnels.service 2>/dev/null || true
# Arrêter seulement les anciens tunnels SSH de ce lab, appartenant au compte courant.
python3 - "$uid" <<'PY'
import os,pathlib,signal,sys,time
uid=int(sys.argv[1])
for p in pathlib.Path('/proc').iterdir():
 if not p.name.isdigit(): continue
 try:
  if p.stat().st_uid!=uid: continue
  a=(p/'cmdline').read_bytes().split(b'\0'); a=[x.decode(errors='replace') for x in a if x]
  if not a or pathlib.Path(a[0]).name!='ssh': continue
  if 'coder@127.0.0.1' not in a: continue
  if not any(a[i]=='-p' and a[i+1]=='2222' for i in range(len(a)-1)): continue
  forwards={'127.0.0.1:18443:127.0.0.1:8443','127.0.0.1:18000:127.0.0.1:18000'}
  if not any(a[i]=='-L' and a[i+1] in forwards for i in range(len(a)-1)): continue
  os.kill(int(p.name),signal.SIGTERM)
 except (FileNotFoundError,ProcessLookupError,PermissionError): pass
 time.sleep(0.01)
PY
ssh "${ssh_args[@]}" 'sudo -n bash -s' <<'REMOTE'
set -euo pipefail
systemctl stop coder-lab-argocd-forward.service coder-lab-coder-forward.service 2>/dev/null || true
# Aucun autre port-forward ni application ne doit être arrêté.
python3 - <<'PY'
import pathlib,signal,os,time
for p in pathlib.Path('/proc').iterdir():
 if not p.name.isdigit(): continue
 try:
  a=[x.decode(errors='replace') for x in (p/'cmdline').read_bytes().split(b'\0') if x]
  if not a or pathlib.Path(a[0]).name not in ('k3s','kubectl'): continue
  if 'port-forward' not in a: continue
  if not (('svc/argocd-server' in a and '8443:443' in a) or ('svc/coder' in a and '18000:80' in a)): continue
  ns='argocd' if 'svc/argocd-server' in a else 'coder'
  if not any(a[i] in ('-n','--namespace') and a[i+1]==ns for i in range(len(a)-1)): continue
  os.kill(int(p.name),signal.SIGTERM)
 except (FileNotFoundError,ProcessLookupError,PermissionError): pass
time.sleep(1)
PY
k3s_bin=$(command -v k3s)
for name in argocd coder; do
  if [ "$name" = argocd ]; then svc=argocd-server; mapping=8443:443; else svc=coder; mapping=18000:80; fi
  cat > "/etc/systemd/system/coder-lab-${name}-forward.service" <<UNIT
[Unit]
Description=Coder lab - Kubernetes port-forward ${name}
After=k3s.service
Wants=k3s.service
StartLimitIntervalSec=0
[Service]
ExecStart=${k3s_bin} kubectl port-forward --address 127.0.0.1 -n ${name} svc/${svc} ${mapping}
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
done
systemctl daemon-reload
systemctl enable --now coder-lab-argocd-forward.service coder-lab-coder-forward.service
REMOTE
# Un unique tunnel SSH transporte les deux interfaces de Sunny vers la VM.
ssh_bin=$(command -v ssh)
sudo tee /etc/systemd/system/coder-lab-tunnels.service >/dev/null <<UNIT
[Unit]
Description=Coder lab - Sunny to VM SSH tunnels
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0
[Service]
User=${user}
ExecStart=${ssh_bin} -N -T -i ${key} -p 2222 -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -L 127.0.0.1:18443:127.0.0.1:8443 -L 127.0.0.1:18000:127.0.0.1:18000 coder@127.0.0.1
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now coder-lab-tunnels.service
# Attendre une vraie réponse HTTP, pas seulement l'ouverture d'un port.
ready=0
for attempt in $(seq 1 20); do
  if curl -fsS --connect-timeout 2 --max-time 3 http://127.0.0.1:18000/healthz >/dev/null &&
     curl -kfsS --connect-timeout 2 --max-time 3 https://127.0.0.1:18443/healthz >/dev/null; then
    ready=1
    break
  fi
  sleep 2
done
if [ "$ready" != 1 ]; then
  echo 'Services installés, mais les interfaces ne répondent pas encore.' >&2
  echo 'Diagnostic Sunny : sudo journalctl -u coder-lab-tunnels -n 25 --no-pager' >&2
  echo 'Diagnostic VM : sudo journalctl -u coder-lab-argocd-forward -u coder-lab-coder-forward -n 25 --no-pager' >&2
  exit 1
fi
printf '\nTransferts prêts sur Sunny. Activez les deux règles Termius sur votre PC.\nArgo CD : https://127.0.0.1:18443\nCoder   : http://127.0.0.1:18000\n'
