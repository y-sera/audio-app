# audio-app Margo package

Packages audio-app (USB microphone → Silero VAD → transcription by Gemma on LiteRT-LM)
as a Margo application, following `specification/src/specification/applications/`
and `specification/system-design/specification/applications/application-registry.md`.

> The registry `ghcr.io/y-sera/audio-app` is provisional. See [Changing the registry](#changing-the-registry).

## Layout

```text
margo/
├── application-description/       # Margo Application Package
│   ├── margo.yaml                 #   ApplicationDescription (helm + compose profiles)
│   └── resources/                 #   icon, description, release notes, license
├── helm/audio-app/                # Helm component "audio-app" (Chart API v2)
├── compose/audio-app-compose/     # Compose component "audio-app-compose"
│   └── compose.yaml               #   MUST be named compose.yaml inside the archive
└── scripts/                       # build / package / push
```

## Published artifacts

| Artifact | Reference | Media / artifact type |
| --- | --- | --- |
| audio-app image | `ghcr.io/y-sera/audio-app/audio-app:0.1.1` | container image |
| litert-lm image | `ghcr.io/y-sera/audio-app/litert-lm:0.1.1` | container image |
| Helm chart | `oci://ghcr.io/y-sera/audio-app/charts/audio-app:0.1.1` | Helm OCI chart |
| Compose archive | `oci://ghcr.io/y-sera/audio-app/compose/audio-app-compose:0.1.1` | `application/vnd.org.margo.component.compose+json` |
| Application package | `ghcr.io/y-sera/audio-app/margo-package:0.1.1` | `application/vnd.margo.app.v1+json` |

The Application Package tag is `metadata.version` of `margo.yaml`, and every component
`revision` equals its chart version / OCI tag, as the spec requires.

## Build and publish

Requires `docker` (buildx), `helm`, `oras` and `yq`, and a login to the registry
(`docker login ghcr.io`, `helm registry login ghcr.io`, `oras login ghcr.io`).

```bash
cd audio-app/margo
scripts/build_images.sh        # container images
scripts/package_helm.sh        # helm package + helm push
scripts/package_compose.sh     # Margo Compose Archive + oras push
scripts/push_app_package.sh    # margo.yaml + resources + oras push
```

`PUSH=false` builds/packages locally without pushing. `REGISTRY`, `VERSION` and
`PLATFORMS` (default `linux/amd64,linux/arm64`; a single platform with `PUSH=false`) can be overridden; the scripts refuse to run when the
versions in `Chart.yaml`, `margo.yaml` and `compose.yaml` don't match `VERSION`.

### GitHub Actions

Both workflows run only on manual dispatch (Actions tab → *Run workflow*).

| Workflow | What it does |
| --- | --- |
| `ci.yml` | Static checks (versions, Helm render rules, Compose, `margo.yaml` schema) → builds both images natively on amd64 and arm64 runners and smoke-tests the audio-app image (`test/smoke/`: PortAudio, Silero VAD on onnxruntime, WAV helpers, OpenAI client) → E2E on k3s per architecture |
| `release.yml` | From `main` only: runs `ci.yml`, then pushes the **tested** images as a multi-arch manifest, plus the chart, Compose archive and application package (`release` environment) |

The E2E test (`test/e2e/`) deploys only the LiteRT-LM server (`app.enabled=false`, CPU
backend), sends `test/e2e/fixtures/sample.wav` to it and passes when the transcription
contains every keyword in `expected-keywords.txt`. Until those fixtures exist it only checks
that the server starts and lists the model. The model is kept in the Actions cache and
mounted through `llm.persistence.existingClaim`, so it is downloaded only on a cache miss.

Validate the application description against the spec schema:

```bash
uvx -p 3.12 --from linkml linkml validate \
  --schema ../../specification/src/specification/applications/application-description.linkml.yaml \
  --target-class ApplicationDescription application-description/margo.yaml
```

## Margo constraints applied

- **Helm**: Chart API v2; no `lookup`, hooks or CRDs; no `metadata.namespace` (the WFM
  chooses the namespace). The LLM server address is derived from the release name.
- **Compose**: one top-level directory containing `compose.yaml`, published with
  `oras` using the Margo artifact type, layer media type and required annotations.
  `docker compose publish` is not used (incompatible with Margo).
- **Parameters**: Helm targets use `--set` dot notation; Compose targets are environment
  variables consumed via `${VAR:-default}` interpolation in `compose.yaml`.
- **Device constraints**: amd64 or arm64, 2.5 cores, 4096Mi memory, 10Gi storage, plus an
  eligibility rule requiring a `microphone` peripheral. No GPU is required.

## Device prerequisites

- **Kubernetes**: a device plugin advertising `/dev/snd` as `devic.es/audio`
  (e.g. `../deploy/generic-device-plugin.yaml`). The plugin is a cluster-wide privileged
  DaemonSet, so it is not part of the application package. Without a plugin, set
  `app.audioDevice.mode=hostPath` (mounts `/dev/snd`, runs privileged).
- **Compose**: `/dev/snd` on the host.
- **Both**: access to Hugging Face on first start (model download into a persistent volume).

## Inference backend

LiteRT-LM runs on the CPU by default. The Helm chart switches to the GPU with
`llm.model.backend=gpu` (Margo parameter `llmBackend`), which also applies the settings
under `llm.gpu` to the LiteRT-LM pod:

| Value | Default | Effect with `backend: gpu` |
| --- | --- | --- |
| `llm.gpu.runtimeClassName` | `nvidia` | Pod `runtimeClassName` (empty: cluster default) |
| `llm.gpu.resources` | `{}` | Merged into the container's resource limits, e.g. `nvidia.com/gpu: 1` |
| `llm.gpu.env` | `[]` | Extra container environment, e.g. `NVIDIA_DRIVER_CAPABILITIES` |

With `backend: cpu` none of these are rendered. The Compose profile is CPU only, since
Compose cannot add or drop the GPU device reservation based on a parameter.

## Changing the registry

Update `REGISTRY` in `scripts/env.sh` and the references in:

- `helm/audio-app/values.yaml` — `app.image.repository`, `llm.image.repository`
- `compose/audio-app-compose/compose.yaml` — `services.*.image`
- `application-description/margo.yaml` — `deploymentProfiles[].components[].properties.repository`
