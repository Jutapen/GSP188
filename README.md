# GSP188 - App Dev: Deploying the Application into Kubernetes Engine - Python

Script bash otomatis untuk lab Google Cloud **GSP188** di Cloud Shell. Script berhenti di setiap
**Check my progress**, jadi kamu bisa memverifikasi skor dulu sebelum lanjut.

**Credit: Jutapen** | GitHub: https://github.com/Jutapen

## Cara pakai (satu baris)

Buka Cloud Shell dengan akun student dari lab, lalu jalankan:

```bash
curl -fsSL https://raw.githubusercontent.com/Jutapen/GSP188/main/gsp188.sh | bash
```

Script mengambil Project ID dari `gcloud config`. Kalau region atau zone belum terisi,
script akan menanyakannya (isi sesuai nilai di panel lab, contoh `us-west1` dan `us-west1-b`).

Di setiap jeda:

1. Klik **Check my progress** di halaman lab.
2. Kembali ke terminal, tekan **ENTER**.

Script aman dijalankan ulang (idempotent): resource yang sudah ada akan dilewati.

## Yang dikerjakan script

| Task | Isi | Check my progress |
|------|-----|-------------------|
| 1 | Salin starter code, jalankan `prepare_environment.sh` | Configure the Quiz application |
| 2 | Buat cluster `quiz-cluster` (zonal, access scope full ke semua Cloud API, 3 node), lalu connect | Create Kubernetes engine cluster |
| 3 | Buat repository Docker `container-dev-repo` di Artifact Registry | Create a Docker Repository |
| 4 | Isi Dockerfile frontend dan backend, build image `v1` via Cloud Build | Build Docker Images using Cloud Build |
| 5 | Isi placeholder YAML, buat Deployment dan Service | Create Kubernetes Deployment and service resources |

## Langkah manual (GUI)

Bagian ini tetap kamu lakukan sendiri di browser:

1. Klik **Start Lab**, buka **Open Google Cloud console** di jendela Incognito, login dengan
   username dan password dari panel lab.
2. Klik **Activate Cloud Shell**.
3. Paste perintah satu baris di atas.
4. Klik **Check my progress** di setiap jeda.
5. Setelah selesai, buka alamat `http://<EXTERNAL-IP>` yang ditampilkan script di tab baru
   (atau lihat di **Kubernetes Engine > Workloads > quiz-frontend > Exposing services**).

Alternatif membuat cluster lewat console (nilai sama dengan yang dipakai script):

| Properti | Nilai |
|----------|-------|
| Name | `quiz-cluster` |
| Location type | Zonal, zone sesuai panel lab (contoh `us-west1-b`) |
| default-pool > Security > Access scopes | Allow full access to all Cloud APIs |

## Yang normal terjadi

- Pembuatan cluster dan build image masing-masing butuh beberapa menit.
- `kubectl get pods` tepat setelah connect menampilkan `No resources found in default namespace`.
- Cloud Build bisa menampilkan pesan incompatibility. Abaikan selama statusnya `SUCCESS`.
- Status Pod bisa sementara `Pending` atau `ContainerCreating` sebelum menjadi `Running`.
- External IP bisa butuh 1 sampai 3 menit sebelum muncul.
- Browser bisa memperingatkan "connection not secure" karena Service memakai HTTP. Pilih Continue to Site.
- Menjalankan ulang script menampilkan pesan "sudah ada, dilewati" untuk bagian yang sudah selesai.

## Disclaimer

Repo ini hanya untuk tujuan edukasi dan tidak berafiliasi dengan Google. Gunakan hanya akun
student yang diberikan lab, jangan gunakan akun Google Cloud pribadi. Baca dan pahami script
sebelum menjalankannya, dan gunakan dengan risiko sendiri.

## Lisensi

MIT. Lihat berkas [LICENSE](LICENSE).
