#!/bin/bash
# ==============================================================================
#  GSP188 - App Dev: Deploying the Application into Kubernetes Engine - Python
#
#  Credit : Jutapen
#  GitHub : https://github.com/Jutapen
#
#  Pakai  : curl -fsSL https://raw.githubusercontent.com/Jutapen/GSP188/main/gsp188.sh | bash
#
#  Jalankan di Cloud Shell dengan akun student dari lab. Script ini idempotent:
#  aman dijalankan ulang, bagian yang sudah ada akan dilewati.
# ==============================================================================

set -eE

# ------------------------------- warna ----------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  USE_COLOR=1
  C_RESET=$'\033[0m'
  C_BLUE=$'\033[1;34m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'
  C_CYAN=$'\033[1;36m'
else
  USE_COLOR=0
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""
fi

info() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf '%s[ERR ]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

# Jeda di setiap "Check my progress" (tetap jalan lewat curl | bash)
pause() {
  echo
  printf '%s>>> Klik "Check my progress": %s%s\n' "$C_YELLOW" "$1" "$C_RESET"
  read -r -p ">>> Tekan ENTER setelah skor terverifikasi untuk lanjut... " _ </dev/tty
}

# Tanya nilai ke pengguna (dipakai kalau region/zone kosong)
ask() {
  local prompt="$1" def="${2:-}" ans=""
  while :; do
    if [ -n "$def" ]; then
      read -r -p "$prompt [$def]: " ans </dev/tty
      ans="${ans:-$def}"
    else
      read -r -p "$prompt: " ans </dev/tty
    fi
    if [ -n "$ans" ]; then break; fi
  done
  printf '%s' "$ans"
}

# Efek ketik (nonaktif kalau output bukan terminal)
typewrite() {
  local s="$1" i
  if [ "$USE_COLOR" = 1 ]; then
    for ((i = 0; i < ${#s}; i++)); do
      printf '%s' "${s:i:1}"
      sleep 0.02
    done
    printf '\n'
  else
    printf '%s\n' "$s"
  fi
}

show_banner() {
  local -a rows=(
    ' ____   ___  _   _ _____ '
    '|  _ \ / _ \| \ | | ____|'
    '| | | | | | |  \| |  _|  '
    '| |_| | |_| | |\  | |___ '
    '|____/ \___/|_| \_|_____|'
  )
  local -a cols=(196 202 208 214 220)
  local i
  for i in "${!rows[@]}"; do
    if [ "$USE_COLOR" = 1 ]; then
      printf '\033[1;38;5;%sm%s\033[0m\n' "${cols[$i]}" "${rows[$i]}"
    else
      printf '%s\n' "${rows[$i]}"
    fi
  done
}

main() {
  trap 'err "Terjadi error di baris $LINENO. Perbaiki lalu jalankan ulang (script aman dijalankan ulang)."' ERR

  echo
  printf '%sGSP188 - App Dev: Deploying the Application into Kubernetes Engine - Python%s\n' "$C_CYAN" "$C_RESET"
  printf '%sCredit: Jutapen  |  https://github.com/Jutapen%s\n' "$C_CYAN" "$C_RESET"
  echo

  # ---------------------------- environment ----------------------------------
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
  if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-${DEVSHELL_PROJECT_ID:-}}"
  fi
  if [ -z "$PROJECT_ID" ]; then
    err "Project ID tidak ditemukan. Jalankan di Cloud Shell dengan akun student lab."
    exit 1
  fi

  ACCOUNT="$(gcloud config get-value account 2>/dev/null || true)"
  case "$ACCOUNT" in
    *qwiklabs.net)
      ok "Akun student lab terdeteksi."
      ;;
    *)
      warn "Akun aktif bukan akun student lab (qwiklabs.net). Gunakan hanya akun student dari lab."
      read -r -p "Tetap lanjut? (y/N): " yn </dev/tty
      if [ "$yn" != "y" ] && [ "$yn" != "Y" ]; then exit 1; fi
      ;;
  esac

  REGION="${REGION:-$(gcloud config get-value compute/region 2>/dev/null || true)}"
  if [ "$REGION" = "(unset)" ]; then REGION=""; fi
  if [ -z "$REGION" ]; then
    REGION="$(ask 'Masukkan REGION dari lab (contoh: us-west1)')"
  fi

  ZONE="${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null || true)}"
  if [ "$ZONE" = "(unset)" ]; then ZONE=""; fi
  case "$ZONE" in
    "$REGION"-*) ;;
    *) ZONE="$(ask 'Masukkan ZONE dari lab' "${REGION}-b")" ;;
  esac
  case "$ZONE" in
    "$REGION"-*) ;;
    *) err "Zone $ZONE tidak berada di region $REGION."; exit 1 ;;
  esac

  APP_REGION="$REGION"
  REPO="container-dev-repo"
  IMG_BASE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO"
  export REGION APP_REGION

  info "Project : $PROJECT_ID"
  info "Region  : $REGION"
  info "Zone    : $ZONE"

  ##############################################################################
  # TASK 1: Prepare the Quiz application
  ##############################################################################
  echo
  info "=== Task 1: Prepare the Quiz application ==="
  cd ~
  if [ ! -d "$HOME/kubernetesengine" ]; then
    gcloud storage cp -r "gs://$PROJECT_ID-assets/kubernetesengine" .
  else
    info "Folder kubernetesengine sudah ada, dilewati."
  fi
  cd ~/kubernetesengine/start

  # sed hanya sekali (agar python3.12 tidak berubah jadi python3.12.12 saat diulang)
  if [ ! -f .sed_done ]; then
    sed -i -e 's/us-central1/'"$REGION"'/g' -e 's/us-central/'"$APP_REGION"'/g' -e 's/python3/'"python3.12"'/g' prepare_environment.sh
    touch .sed_done
  fi

  if [ ! -f .prepare_done ]; then
    . prepare_environment.sh || { err "prepare_environment.sh gagal."; exit 1; }
    touch .prepare_done
  else
    info "prepare_environment.sh sudah pernah dijalankan, dilewati."
  fi

  # Pastikan variabel tersedia (juga saat dijalankan ulang)
  export GCLOUD_PROJECT="${GCLOUD_PROJECT:-$PROJECT_ID}"
  if [ -z "${GCLOUD_BUCKET:-}" ]; then
    GCLOUD_BUCKET="$(gcloud storage buckets list --format='value(name)' | grep -- '-media$' | head -1 || true)"
    export GCLOUD_BUCKET
  fi
  if [ -z "$GCLOUD_BUCKET" ]; then
    err "Bucket media tidak ditemukan."
    exit 1
  fi
  info "GCLOUD_PROJECT=$GCLOUD_PROJECT"
  info "GCLOUD_BUCKET=$GCLOUD_BUCKET"
  pause "Configure the Quiz application"

  ##############################################################################
  # TASK 2: Create Kubernetes Engine cluster
  ##############################################################################
  echo
  info "=== Task 2: Create cluster quiz-cluster ==="
  if gcloud container clusters describe quiz-cluster --zone "$ZONE" >/dev/null 2>&1; then
    info "Cluster quiz-cluster sudah ada, dilewati."
  else
    gcloud container clusters create quiz-cluster \
      --zone "$ZONE" \
      --scopes=cloud-platform \
      --num-nodes=3 \
      --quiet
  fi
  pause "Create Kubernetes engine cluster"

  info "Menghubungkan ke cluster..."
  gcloud container clusters get-credentials quiz-cluster --zone "$ZONE" --project "$PROJECT_ID"
  kubectl get pods || true

  ##############################################################################
  # TASK 3: Create a Docker repository on Artifact Registry
  ##############################################################################
  echo
  info "=== Task 3: Create Docker repository ==="
  if gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1; then
    info "Repository $REPO sudah ada, dilewati."
  else
    gcloud artifacts repositories create "$REPO" --repository-format=docker \
      --location="$REGION" \
      --description="Docker repository for Container Dev Workshop"
  fi
  pause "Create a Docker Repository"

  ##############################################################################
  # TASK 4: Build Docker images using Cloud Build
  ##############################################################################
  echo
  info "=== Task 4: Dockerfile dan Cloud Build ==="
  cd ~/kubernetesengine/start

  cat > frontend/Dockerfile <<'EOF'
FROM gcr.io/google_appengine/python

RUN virtualenv -p python3.7 /env

ENV VIRTUAL_ENV /env
ENV PATH /env/bin:$PATH

ADD requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

ADD . /app

CMD gunicorn -b 0.0.0.0:$PORT quiz:app
EOF

  cat > backend/Dockerfile <<'EOF'
FROM gcr.io/google_appengine/python

RUN virtualenv -p python3.7 /env

ENV VIRTUAL_ENV /env
ENV PATH /env/bin:$PATH

ADD requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

ADD . /app

CMD python -m quiz.console.worker
EOF

  if gcloud artifacts docker images describe "$IMG_BASE/quiz-frontend:v1" >/dev/null 2>&1; then
    info "Image quiz-frontend:v1 sudah ada, dilewati."
  else
    gcloud builds submit -t "$IMG_BASE/quiz-frontend:v1" ./frontend/
  fi

  if gcloud artifacts docker images describe "$IMG_BASE/quiz-backend:v1" >/dev/null 2>&1; then
    info "Image quiz-backend:v1 sudah ada, dilewati."
  else
    gcloud builds submit -t "$IMG_BASE/quiz-backend:v1" ./backend/
  fi
  pause "Build Docker Images using Cloud Build"

  ##############################################################################
  # TASK 5: Create Kubernetes Deployment and Service resources
  ##############################################################################
  echo
  info "=== Task 5: Deployment dan Service ==="
  cd ~/kubernetesengine/start

  # Ganti placeholder (tidak berefek kalau sudah terganti)
  sed -i \
    -e "s|\[GCLOUD_PROJECT\]|$GCLOUD_PROJECT|g" \
    -e "s|\[GCLOUD_BUCKET\]|$GCLOUD_BUCKET|g" \
    -e "s|\[FRONTEND_IMAGE_IDENTIFIER\]|$IMG_BASE/quiz-frontend:v1|g" \
    frontend-deployment.yaml
  sed -i \
    -e "s|\[GCLOUD_PROJECT\]|$GCLOUD_PROJECT|g" \
    -e "s|\[GCLOUD_BUCKET\]|$GCLOUD_BUCKET|g" \
    -e "s|\[BACKEND_IMAGE_IDENTIFIER\]|$IMG_BASE/quiz-backend:v1|g" \
    backend-deployment.yaml

  if grep -nE '\[(GCLOUD_PROJECT|GCLOUD_BUCKET|FRONTEND_IMAGE_IDENTIFIER|BACKEND_IMAGE_IDENTIFIER)\]' frontend-deployment.yaml backend-deployment.yaml; then
    err "Masih ada placeholder yang belum terganti."
    exit 1
  fi

  for f in frontend-deployment.yaml backend-deployment.yaml frontend-service.yaml; do
    if kubectl get -f "./$f" >/dev/null 2>&1; then
      info "$f sudah ada di cluster, dilewati."
    else
      kubectl create -f "./$f"
    fi
  done

  info "Menunggu deployment siap..."
  kubectl rollout status deployment/quiz-frontend --timeout=300s || true
  kubectl rollout status deployment/quiz-backend --timeout=300s || true

  info "Menunggu External IP service..."
  IP=""
  for i in $(seq 1 30); do
    IP="$(kubectl get svc -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [ -n "$IP" ]; then break; fi
    sleep 10
  done
  kubectl get pods
  kubectl get svc
  pause "Create Kubernetes Deployment and service resources"

  ##############################################################################
  # Penutup
  ##############################################################################
  echo
  show_banner
  echo
  printf '%sGSP188 - App Dev: Deploying the Application into Kubernetes Engine - Python%s\n' "$C_CYAN" "$C_RESET"
  echo
  printf '%s ✔ %s Quiz application dikonfigurasi (prepare_environment.sh)\n' "$C_GREEN" "$C_RESET"
  printf '%s ✔ %s Cluster quiz-cluster dibuat di %s dan terhubung\n' "$C_GREEN" "$C_RESET" "$ZONE"
  printf '%s ✔ %s Repository Artifact Registry %s dibuat\n' "$C_GREEN" "$C_RESET" "$REPO"
  printf '%s ✔ %s Image quiz-frontend:v1 dan quiz-backend:v1 dibangun via Cloud Build\n' "$C_GREEN" "$C_RESET"
  printf '%s ✔ %s Deployment dan Service Kubernetes dibuat\n' "$C_GREEN" "$C_RESET"
  echo
  if [ -n "$IP" ]; then
    printf '%sService URL%s : http://%s\n' "$C_CYAN" "$C_RESET" "$IP"
    echo "(Kalau muncul peringatan 'connection not secure', pilih Continue to Site.)"
  else
    warn "External IP belum tersedia. Cek lagi dengan: kubectl get svc"
  fi
  echo
  typewrite "Jangan lupa mampir ke GitHub saya: https://github.com/Jutapen"
  echo
  printf '%sCredit: Jutapen%s\n' "$C_CYAN" "$C_RESET"
}

# Semua perintah dibaca dari terminal supaya tidak memakan isi script saat curl | bash
if ( : </dev/tty ) 2>/dev/null; then
  main "$@" </dev/tty
else
  main "$@"
fi
