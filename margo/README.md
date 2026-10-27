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
| audio-app image | `ghcr.io/y-sera/audio-app/audio-app:0.1.0` | container image |
| litert-lm image | `ghcr.io/y-sera/audio-app/litert-lm:0.1.0` | container image |
| Helm chart | `oci://ghcr.io/y-sera/audio-app/charts/audio-app:0.1.0` | Helm OCI chart |
| Compose archive | `oci://ghcr.io/y-sera/audio-app/compose/audio-app-compose:0.1.0` | `application/vnd.org.margo.component.compose+json` |
| Application package | `ghcr.io/y-sera/audio-app/margo-package:0.1.0` | `application/vnd.margo.app.v1+json` |

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
`PLATFORMS` (default `linux/amd64`) can be overridden; the scripts refuse to run when the
versions in `Chart.yaml`, `margo.yaml` and `compose.yaml` don't match `VERSION`.

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
- **Device constraints**: amd64, 2.5 cores, 4096Mi memory, 10Gi storage, plus eligibility
  rules requiring a `microphone` peripheral and an NVIDIA `gpu` peripheral.

## Device prerequisites

- **Kubernetes**: the `nvidia` RuntimeClass, and a device plugin advertising `/dev/snd` as
  `devic.es/audio` (e.g. `../deploy/generic-device-plugin.yaml`). The plugin is a
  cluster-wide privileged DaemonSet, so it is not part of the application package.
  Without a plugin, set `app.audioDevice.mode=hostPath` (mounts `/dev/snd`, runs privileged).
- **Compose**: NVIDIA Container Toolkit; `/dev/snd` on the host.
- **Both**: access to Hugging Face on first start (model download into a persistent volume).

## Changing the registry

Update `REGISTRY` in `scripts/env.sh` and the references in:

- `helm/audio-app/values.yaml` — `app.image.repository`, `llm.image.repository`
- `compose/audio-app-compose/compose.yaml` — `services.*.image`
- `application-description/margo.yaml` — `deploymentProfiles[].components[].properties.repository`
