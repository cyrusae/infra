# terraform/nvidia-gpu

Deploys NVIDIA GPU time-slicing support into the K3s cluster.

## What This Does

- **Time-slicing ConfigMap** — tells the device plugin to expose N virtual GPUs per physical GPU
- **NVIDIA device plugin** (Helm) — advertises `nvidia.com/gpu` resources to the scheduler; DaemonSet runs only on nodes with NVIDIA hardware (Babbage)
- **RuntimeClass `nvidia`** — workloads request this to get proper GPU container runtime injection

## Prerequisites

**Host-side (Ansible Layer 1, already handled):**

- `nvidia-container-toolkit` installed on ALL nodes (in `roles/common`)
- `nvidia-ctk runtime configure --runtime=containerd` must have run on Babbage (configures `/etc/containerd/config.toml`)

If the containerd config hasn't been updated post-toolkit-install, the RuntimeClass handler will fail to match. Verify on Babbage:

```bash
grep -A5 "nvidia" /etc/containerd/config.toml
```

Should show a `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]` block.

**Cluster (apply before this module):**

- K3s running (Layer 2)
- Longhorn (Layer 3, first in sequence -- nvidia-gpu can be applied alongside other Layer 3 modules)

## Apply

```bash
cd terraform/nvidia-gpu
terraform init
terraform apply  # uses default 8 slices

# Or explicitly set slice count:
TF_VAR_gpu_time_slices=4 terraform apply
```

## Verify

After apply, check Babbage is advertising GPU resources:

```bash
kubectl describe node babbage | grep -A5 "nvidia.com/gpu"
# Capacity:    nvidia.com/gpu: 8    (or whatever var.gpu_time_slices is)
# Allocatable: nvidia.com/gpu: 8
```

Check the device plugin pod is running:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=nvidia-device-plugin
```

## Using GPU in a Pod

Minimal pod spec to request one GPU slice:

```yaml
apiVersion: v1
kind: Pod
spec:
  runtimeClassName: nvidia          # required
  containers:
    - name: app
      image: your-image
      resources:
        limits:
          nvidia.com/gpu: "1"       # request one time-slice
```

**Ollama example:**

```yaml
resources:
  limits:
    nvidia.com/gpu: "1"
runtimeClassName: nvidia
```

## VRAM Considerations

The GTX 1070 has 8 GB VRAM. Time-slicing does NOT partition VRAM — all
virtual GPU slices share the physical pool. Expected workload footprints:

| Workload         | VRAM est. | Pattern        |
|------------------|-----------|----------------|
| Ollama (7B q4)   | 4-6 GB    | Long-lived     |
| GROBID GPU model | 2-4 GB    | Bursty         |
| Whisper large-v2 | 3-4 GB    | Bursty         |
| OCR (easyocr)    | 1-2 GB    | Bursty         |

Running Ollama and GROBID simultaneously may cause GPU OOM errors.
Watch for: `CUDA out of memory` in pod logs.

If OOM becomes a problem, reduce `gpu_time_slices` (→ fewer concurrent
schedulable GPU pods = more honest resource accounting) or run Ollama at
a smaller quantization level.

## Tuning Time-Slice Count

| Slices | Best for                                               |
|--------|--------------------------------------------------------|
| 8      | Many bursty workloads, mostly non-concurrent (current) |
| 4      | Mix of always-on + bursty, more honest scheduling      |
| 2      | Mostly exclusive, near-sequential GPU workloads        |
| 1      | Exclusive access, no sharing (equivalent to no slicing)|

## Node Taint (Optional)

If you want to reserve Babbage's CPU/RAM for GPU workloads only:

```bash
kubectl taint nodes babbage nvidia.com/gpu=present:NoSchedule
```

Then every GPU pod needs:

```yaml
tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

Not recommended for homelab scale unless Babbage is being crowded out.