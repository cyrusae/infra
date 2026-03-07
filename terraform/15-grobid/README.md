# GROBID Terraform Module

Scientific document parser (PDF → structured XML/TEI) with Deep Learning acceleration.

## Overview

This module deploys GROBID as a **persistent StatefulSet** on Babbage (GPU-enabled node), making it suitable for use as project infrastructure with model caching. The full image includes Python and TensorFlow libraries with automatic GPU support, and the module enforces `TF_FORCE_GPU_ALLOW_GROWTH=true` to prevent TensorFlow from hogging all GPU VRAM on the time-sliced GTX 1070.

**Image:** `grobid/grobid:0.8.2-full` (latest stable; official repo, not the `lfoppiano/grobid` mirror which has confusing tag conventions starting in 0.8.2)

**Key behaviors:**
- Runs only on Babbage (`gpu=true` node selector)
- Requests 1 GPU time-slice from the 8-slice pool
- Persistent storage (15GB by default) for model cache and working directory
- TensorFlow is configured not to pre-allocate all 8GB VRAM, allowing concurrent workloads (Ollama, etc.)
- Exposed via Traefik Ingress (`grobid.dawnfire.casa`) and LoadBalancer (port 8070)
- StatefulSet ensures stable pod identity for persistent cache

## Prerequisites

**Cluster infrastructure (Layer 3):**
- Longhorn storage (for 15Gi PVC)
- MetalLB (for LoadBalancer IP)
- cert-manager (for TLS via Let's Encrypt)
- Traefik (for Ingress routing)
- **nvidia-gpu module applied** (device plugin + time-slicing ConfigMap)

**Host configuration (Ansible Layer 1):**
- All three nodes must have `nvidia-container-toolkit` installed (in `roles/common`)
- Babbage must have `/etc/containerd/config.toml` updated with nvidia runtime (via `nvidia-ctk runtime configure`)
- Verify: `grep -A5 "nvidia" /etc/containerd/config.toml` should show `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]` block

**K3s cluster:**
- `RuntimeClass` named `nvidia` must exist (created by nvidia-gpu module)
- Babbage labeled with `gpu=true` (created by nvidia-gpu module)

## Module Location and Application

Place this module in your Terraform structure:

```
terraform/
├── grobid/
│   ├── main.tf          # This file
│   ├── variables.tf     # (optional; variables are inline here)
│   ├── terraform.tfvars # (optional; for environment-specific overrides)
│   └── outputs.tf       # (optional; outputs are inline here)
├── metallb/
├── longhorn/
├── nvidia-gpu/
└── main.tf              # Root module tying it all together
```

## Apply Sequence

**Layer 3 order matters:**

```bash
# 1. Storage
cd terraform/longhorn && terraform apply

# 2. Networking
cd terraform/metallb && terraform apply

# 3. TLS
cd terraform/cert-manager && terraform apply

# 4. Routing
cd terraform/traefik && terraform apply

# 5. GPU infrastructure
cd terraform/nvidia-gpu && terraform apply

# 6. Applications (GROBID, etc.)
cd terraform/grobid && terraform apply
```

The nvidia-gpu module **must** be applied before GROBID. GROBID cannot schedule until:
- The `nvidia` RuntimeClass exists
- Babbage is labeled `gpu=true`
- The `nvidia.com/gpu` resource is advertised in node capacity

## Variables and Tuning

### Default Configuration

```hcl
grobid_version              = "0.8.2-full"
grobid_replicas             = 1
grobid_storage_size         = "15Gi"
grobid_worker_threads       = 4
grobid_max_concurrent_requests = 5
grobid_namespace            = "grobid"
domain                      = "dawnfire.casa"
```

### Override Examples

**Scale for higher throughput (if running on CPU-only or with lighter load):**

```bash
cd terraform/grobid
terraform apply \
  -var="grobid_worker_threads=8" \
  -var="grobid_max_concurrent_requests=10"
```

**Use development version (0.8.3-SNAPSHOT) if testing new features:**

```bash
terraform apply -var="grobid_version=0.8.3-SNAPSHOT"
```

**Multiple replicas (if scaling across nodes):**

```bash
terraform apply -var="grobid_replicas=3"
# Note: requires PVCs per replica; adjust PVC setup
```

### Memory and CPU Tuning

Current defaults:
- **Requests:** 1000m CPU, 3Gi RAM (leaves room for GPU context overhead)
- **Limits:** 3000m CPU, 6Gi RAM (soft ceiling to prevent other pods starving)
- **GPU:** 1 time-slice (out of 8 available)

If GROBID pod OOMs:
- Increase `memory` limit in the container spec
- Reduce `grobid_worker_threads` (fewer concurrent PDFs)
- Check if Ollama is also running; consider scheduling them at different times

If VRAM errors appear in logs (`CUDA out of memory`):
- This is rare with `TF_FORCE_GPU_ALLOW_GROWTH=true`, but possible if Ollama is running a large model
- Reduce `grobid_max_concurrent_requests` to serialize processing
- Or: run GROBID on CPU fallback temporarily (slower, but works)

## Usage

### Web UI

After deployment:

1. **Wait for startup** (5-10 minutes): GROBID loads Deep Learning models and embeddings on first run.
   ```bash
   # Watch pod startup
   kubectl -n grobid logs -f grobid-0
   ```

2. **Access the web UI:**
   - Via Traefik Ingress: https://grobid.dawnfire.casa
   - Direct LoadBalancer: `kubectl get svc -n grobid grobid-lb` → grab EXTERNAL-IP, then `http://EXTERNAL-IP:8070`

3. **Test with a PDF:** Use the web form to upload a PDF and see extracted bibliographic data.

### REST API

The GROBID API is available at `http://grobid.dawnfire.casa/api` (or `http://LOADBALANCER-IP:8070/api`).

**Example: Process a PDF via the API**

```bash
# Check if service is alive
curl http://grobid.dawnfire.casa/api/isalive

# Process a PDF (fulltext + references)
curl -X POST \
  -F "input=@/path/to/paper.pdf" \
  http://grobid.dawnfire.casa/api/processFulltextDocument \
  > result.xml
```

See https://grobid.readthedocs.io/en/latest/Grobid-service/ for full API documentation.

### Caching and Persistent Storage

The 15Gi PVC (`grobid-data`) holds:
- Working directory for PDF processing (`/tmp/grobid`)
- Model cache (loaded on startup; persistent across pod restarts)
- Temporary ALTO files from PDF parsing

**Persistent storage benefits:**
- Model cache survives pod restarts (no re-download/re-initialization)
- Faster restarts after cluster maintenance
- Can inspect processing artifacts if debugging

To check PVC usage:
```bash
kubectl -n grobid exec grobid-0 -- df -h /opt/grobid/data
```

## Deep Learning Models

The `-full` image includes:
- **Header extraction** (DL model, +2-4 F1-score vs CRF)
- **Reference/citation parsing** (DL model, +2-4 F1-score vs CRF)
- **Full text extraction** (CRF default, DL optional)

See the ConfigMap in the module for `deepLearning.models` section; you can enable additional DL models by editing `grobid.yaml` and restarting the pod.

**VRAM footprint per model:**
- ~1-2GB per active DL model
- 2-3GB for embeddings
- 1-2GB Java/OS overhead
- **Total:** ~4-6GB typical, peaks to 8GB under heavy load

With `TF_FORCE_GPU_ALLOW_GROWTH=true`, unused memory is released back to the GPU, allowing Ollama or other workloads to coexist.

## Production Tuning

### Thread Count

Default is 4 threads (conservative). Increase if:
- Pod CPU is idle but queue is growing: set `grobid_worker_threads=8`
- Pod CPU is maxed and documents queue: set `grobid_worker_threads=2` (or increase CPU limits)

Threads are Java threads, not GPU threads; increasing helps with concurrent PDF parsing.

### Request Backpressure

Default `grobid_max_concurrent_requests=5` means the API returns HTTP 503 (Service Unavailable) when 5 documents are being processed simultaneously. This is intentional—it prevents queue explosion and memory bloat.

For more throughput: increase to 10-15, but monitor memory usage.

### Cold Startup

On first boot, GROBID downloads and loads DL models + embeddings. This takes 3-5 minutes.

**Subsequent restarts:** ~30 seconds (models cached in PVC).

To speed up cold startup:
- Pre-warm the cache by uploading a PDF before production traffic arrives
- Use a larger PVC (more disk I/O for model loading)

### Monitoring

Check pod logs for issues:
```bash
kubectl -n grobid logs grobid-0

# Watch realtime
kubectl -n grobid logs -f grobid-0
```

Key log markers:
- `[INFO] DeLFT model loaded` → Deep Learning models ready
- `Grobid is up` → Service is alive
- `CUDA out of memory` → GPU VRAM exhausted (rare; check Ollama)
- `RuntimeException: timeout in pooled PDF processing` → PDF processing hung (document too complex)

### Health Checks

The module includes startup, liveness, and readiness probes via `/api/isalive`:

```bash
# Manual check
curl http://grobid.dawnfire.casa/api/isalive
# Returns: {"status": "alive", "version": "0.8.2"}
```

If readiness probe fails:
- Wait for startup probe (5-minute window by default)
- Check logs for model loading errors
- Verify GPU is accessible (see Troubleshooting below)

## Troubleshooting

### Pod Won't Start

**Symptom:** `CrashLoopBackOff` or `Pending`

**Check node selector:**
```bash
kubectl get node babbage --show-labels
# Should show: gpu=true
```

If missing, re-apply nvidia-gpu module:
```bash
cd terraform/nvidia-gpu && terraform apply
```

**Check image pull:**
```bash
kubectl -n grobid describe pod grobid-0 | grep -A5 "Events"
```

If `ImagePullBackOff`: the image doesn't exist or registry is down. Use official image:
```bash
docker pull grobid/grobid:0.8.2-full
```

### GPU Not Detected

**Symptom:** Logs show `Using CPU. TensorFlow will be slow.`

**Verify runtime class:**
```bash
kubectl get runtimeclass nvidia
# Should exist and be associated with nvidia container runtime
```

**Verify containerd config:**
```bash
ssh babbage
grep -A5 "nvidia" /etc/containerd/config.toml
```

Should show:
```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
  runtime_engine = ""
  runtime_root = ""
  ...
```

If missing, run on Babbage:
```bash
sudo nvidia-ctk runtime configure --runtime=containerd --config=/etc/containerd/config.toml
sudo systemctl restart containerd
```

Then restart the GROBID pod:
```bash
kubectl -n grobid delete pod grobid-0
```

### CUDA Out of Memory

**Symptom:** Pod logs show `CUDA out of memory` during PDF processing

**Likely causes:**
1. **Ollama is running** a large model (4-6GB), leaving <2GB for GROBID
2. **TF_FORCE_GPU_ALLOW_GROWTH not set** (shouldn't happen with this module, but check env vars)
3. **Too many concurrent requests** (`grobid_max_concurrent_requests` too high)

**Resolution:**
- Check Ollama: `kubectl get pod -A | grep ollama`
- If running: schedule GROBID jobs when Ollama is idle, or reduce Ollama model size
- Lower `grobid_max_concurrent_requests` to 2-3 to serialize processing
- Check GROBID env vars: `kubectl -n grobid exec grobid-0 -- env | grep TF_`

### Slow PDF Processing

**Symptom:** Processing takes 30+ seconds per PDF

**Check if DL models loaded:**
```bash
kubectl -n grobid logs grobid-0 | grep -i "delft"
```

Should show `DeLFT model loaded for...` for each active model.

**If using CPU fallback:**
- Wait 3-5 minutes on first boot for model warmup
- Or check GPU availability (see "GPU Not Detected" above)

**If GPU is active but slow:**
- `grobid_worker_threads=4` may be bottleneck; try `=2` for fewer concurrent jobs with less context switching
- Or increase CPU limits: `cpu = "4000m"` in container spec

### PVC Not Mounting

**Symptom:** `Volume not found` or `FailedAttachVolume`

**Check PVC:**
```bash
kubectl -n grobid get pvc
kubectl -n grobid describe pvc grobid-data
```

If `Pending`: Longhorn is down or full.

```bash
# Check Longhorn
kubectl -n longhorn-system get all

# Check storage available
kubectl get pv
```

Ensure Longhorn is applied and has available capacity before applying GROBID.

### Ingress Not Accessible

**Symptom:** `https://grobid.dawnfire.casa` returns 404 or connection refused

**Check Ingress status:**
```bash
kubectl -n grobid get ingress
kubectl -n grobid describe ingress grobid
```

If `Ingress endpoints` is empty: Traefik is not routing yet.

**Check service endpoints:**
```bash
kubectl -n grobid get svc grobid-lb
kubectl -n grobid get endpoints grobid-lb
```

If no endpoints: pod is not running or readiness probe is failing.

**Check cert-manager:**
```bash
kubectl -n grobid get cert
kubectl -n grobid describe cert grobid-tls
```

If TLS cert is not issued: cert-manager may be down. Re-apply cert-manager Terraform module.

## Cost and Resource Considerations

**Disk:** 15Gi PVC (Longhorn). Models + embeddings = ~7GB; working space = ~8GB.

**Memory:** 
- Request: 3Gi (typical, allows 2 more pods per 8Gi on Babbage)
- Limit: 6Gi (safety ceiling)

**CPU:**
- Request: 1 core (allows other workloads)
- Limit: 3 cores (PDF parsing is CPU-intensive for text extraction)

**GPU:**
- 1 of 8 time-slices on GTX 1070
- Leaves 7 slices for Ollama, other workloads, or a second GROBID instance

**Network:** Minimal; API calls are typically <1MB per PDF upload/result.

## Future Enhancements

- **Horizontal scaling:** Deploy multiple GROBID instances behind a load balancer, with shared Longhorn storage for model cache
- **Batch processing:** Use the GROBID Python client for parallel document processing (see https://github.com/kermitt2/grobid-client-python)
- **Task queue:** Integrate with Celery + Redis for async PDF processing (deferred; current persistent instance is sufficient for bursty loads)
- **Metrics:** Instrument pod with Prometheus metrics (processing time, queue depth, GPU utilization)

## References

- **GROBID Documentation:** https://grobid.readthedocs.io/
- **Docker Images:** https://hub.docker.com/r/grobid/grobid (official repo)
- **GitHub:** https://github.com/kermitt2/grobid
- **REST API:** https://grobid.readthedocs.io/en/latest/Grobid-service/
- **GPU Troubleshooting:** https://grobid.readthedocs.io/en/latest/Frequently-asked-questions/#gpu-configuration

---

**Module last updated:** March 6, 2026  
**GROBID version:** 0.8.2-full (latest stable)  
**GPU time-slicing:** 8 slices, 1 requested per GROBID instance
