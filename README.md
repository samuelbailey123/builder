# Builder

![Validation](https://img.shields.io/github/actions/workflow/status/decima-cloud/builder/build.yaml?branch=main&label=build)

Pre-configured Docker image for debugging, building other images, and working with cloud infrastructure. Ships with pinned versions of cloud CLIs, container tools, languages, and debugging utilities.

## Quick Start

```sh
docker pull ghcr.io/decima-cloud/builder:latest
docker run --rm -it ghcr.io/decima-cloud/builder:latest
```

To run as root (required for some debugging tools like `strace` and `tcpdump`):

```sh
docker run --rm -it --user root ghcr.io/decima-cloud/builder:latest
```

## Supported Platforms

| OS    | Architecture |
|-------|-------------|
| Linux | amd64       |
| Linux | arm64       |

## Tool Inventory

All versions are pinned via `ARG` in the Dockerfile for reproducibility.

### Cloud CLIs

| Tool      | Version | Purpose            |
|-----------|---------|--------------------|
| AWS CLI   | 2.24.4  | AWS management     |
| gcloud    | 514.0.0 | GCP management     |
| Azure CLI | latest  | Azure management   |
| Vault     | 1.18.4  | Secrets management |

### Languages & Runtimes

| Tool    | Version | Purpose          |
|---------|---------|------------------|
| Go      | 1.23.5  | Go development   |
| Python  | 3.x     | Python scripting |
| Node.js | 22.x    | JS runtime       |
| pip     | latest  | Python packages  |

### Container & Image Tools

| Tool     | Version | Purpose               |
|----------|---------|-----------------------|
| Docker   | latest  | Container CLI         |
| buildx   | latest  | Multi-platform builds |
| Trivy    | 0.69.2  | Vulnerability scanner |
| hadolint | 2.12.0  | Dockerfile linter     |
| dive     | 0.12.0  | Image layer explorer  |

### Kubernetes & IaC

| Tool      | Version | Purpose              |
|-----------|---------|----------------------|
| kubectl   | 1.32.1  | Cluster management   |
| Helm      | 3.17.0  | Chart management     |
| Terraform | 1.10.5  | Infrastructure as code |

### Debugging

| Tool     | Purpose                  |
|----------|--------------------------|
| strace   | System call tracing      |
| ltrace   | Library call tracing     |
| tcpdump  | Packet capture           |
| net-tools| netstat, ifconfig, etc.  |
| dnsutils | dig, nslookup            |
| htop     | Process monitoring       |

### Build & Dev Utilities

| Tool       | Purpose                |
|------------|------------------------|
| git        | Version control        |
| make       | Build automation       |
| curl       | HTTP client            |
| wget       | File downloads         |
| jq         | JSON processing        |
| yq         | YAML processing        |
| vim        | Text editor            |
| shellcheck | Shell script linter    |
| unzip      | Archive extraction     |

## Usage Examples

### CI Pipeline Base Image

```yaml
jobs:
  deploy:
    container:
      image: ghcr.io/decima-cloud/builder:latest
    steps:
      - run: terraform init && terraform apply -auto-approve
```

### Debugging a Running Container

```sh
docker run --rm -it --user root \
  --pid=host --net=host \
  ghcr.io/decima-cloud/builder:latest
```

### Building and Scanning Images

```sh
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/decima-cloud/builder:latest \
  sh -c "docker build -t myapp . && trivy image myapp"
```

### Linting Dockerfiles

```sh
docker run --rm -v "$(pwd)":/work -w /work \
  ghcr.io/decima-cloud/builder:latest \
  hadolint Dockerfile
```

## Configuration

### Tool Versions

All tool versions are controlled via `ARG` declarations at the top of the Dockerfile. To pin a different version, update the corresponding `ARG` value:

```dockerfile
ARG KUBECTL_VERSION=1.32.1
ARG HELM_VERSION=3.17.0
ARG TERRAFORM_VERSION=1.10.5
```

### Environment Variables

| Variable            | Default                                          | Purpose                        |
|---------------------|--------------------------------------------------|--------------------------------|
| `DEBIAN_FRONTEND`   | `noninteractive`                                 | Suppresses apt prompts         |
| `PATH`              | Includes `/opt/google-cloud-sdk/bin`, `/usr/local/go/bin` | Tool discovery          |

### Running as Root

The image defaults to a non-root `builder` user (UID 1000). Some debugging tools (`strace`, `tcpdump`, `ltrace`) require elevated privileges. Override with `--user root` when needed.

For CI systems that manage their own user context (GitHub Actions, GitLab CI), the user is typically overridden automatically.

## Image Tags

| Tag Format   | Example          | Description                     |
|-------------|------------------|---------------------------------|
| `latest`    | `latest`         | Latest build from main          |
| `YYYYMMDD`  | `20260301`       | Date-stamped build              |
| `vX.Y.Z`    | `v1.0.0`         | Semantic version release        |
| `vX.Y`      | `v1.0`           | Minor version (tracks patches)  |
| `<sha>`     | `a1b2c3d`        | Specific commit                 |

## Image Size

Target: ~1 GB (down from 3.5-5.5 GB). Achieved through:
- Multi-stage build (download stage discarded)
- Removed unused languages (Java 11, Ruby, Rust)
- `--no-install-recommends` on all apt installs
- Apt lists cleaned in the same layer as installs

## Security

### Non-Root Default

The container runs as user `builder` (UID 1000) by default. This limits the blast radius if a tool or script is compromised. Override with `--user root` only when necessary.

### Image Scanning

Every push to `main` triggers a Trivy vulnerability scan. Results are uploaded as SARIF to GitHub Security so that CRITICAL and HIGH findings appear in the repository's Security tab.

### Supply Chain

- All binary downloads use HTTPS with `curl -fsSL` (fail on HTTP errors, follow redirects, silent).
- Tool versions are pinned by exact version number, not `latest` tags.
- The weekly scheduled rebuild picks up OS-level security patches from the Ubuntu base image.
- Multi-stage build ensures download-stage tools (extra curl, unzip) are not present in the final image.

### Secrets Handling

This image does not embed any credentials. Cloud CLI authentication should be provided at runtime via:
- Mounted service account keys or token files
- Environment variables (`AWS_ACCESS_KEY_ID`, `GOOGLE_APPLICATION_CREDENTIALS`, etc.)
- CI-native secret injection (GitHub Actions secrets, GitLab CI variables)

Never bake credentials into derived images.

## Observability

### Validation Script

The built-in `validate-tools.sh` script checks every installed tool and reports pass/fail counts. Run it to verify image integrity:

```sh
docker run --rm ghcr.io/decima-cloud/builder:latest validate-tools.sh
```

### Health Check

The Dockerfile includes a `HEALTHCHECK` instruction that verifies core tools (`aws`, `kubectl`, `terraform`) are present. Container orchestrators that support health checks will monitor this automatically.

### CI Pipeline Reporting

The CI workflow produces:
- **Lint results** from hadolint (Dockerfile) and shellcheck (shell scripts)
- **Trivy SARIF** uploaded to GitHub Security for vulnerability tracking
- **Image size report** in the GitHub Actions step summary
- **Tool validation output** from `validate-tools.sh`

## Scalability

### Multi-Platform Builds

The image is built for both `linux/amd64` and `linux/arm64` using Docker Buildx with QEMU emulation. This allows the same image tag to run on x86 servers, ARM-based CI runners, and Apple Silicon development machines.

### Build Caching

The CI pipeline uses GitHub Actions cache (`type=gha`) for Docker layer caching. This significantly reduces rebuild times when only a few tool versions change, since earlier layers are reused.

### Extending the Image

To add tools to the image, follow the established pattern:

1. **Add a pinned version ARG** at the top of the Dockerfile:
   ```dockerfile
   ARG NEWTOOL_VERSION=1.2.3
   ```

2. **Download in the downloader stage** using the architecture-aware pattern:
   ```dockerfile
   RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
       && curl -fsSL "https://example.com/newtool-v${NEWTOOL_VERSION}-linux-${ARCH_SUFFIX}.tar.gz" \
          | tar -xz -C /usr/local/bin newtool
   ```

3. **Copy into the final stage**:
   ```dockerfile
   COPY --from=downloader /usr/local/bin/newtool /usr/local/bin/newtool
   ```

4. **Add a validation check** in `scripts/validate-tools.sh`:
   ```bash
   check "newtool" newtool --version
   ```

5. **Update the tool inventory** table in this README.

### Deriving Custom Images

For project-specific tooling, create a downstream Dockerfile:

```dockerfile
FROM ghcr.io/decima-cloud/builder:latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends <package> \
    && rm -rf /var/lib/apt/lists/*
USER builder
```

## Disaster Recovery

### Rebuild from Source

The image is fully reproducible from the Dockerfile alone. If the GHCR registry is unavailable or the image is corrupted:

```sh
git clone https://github.com/decima-cloud/builder.git
cd builder
docker build -t builder:local .
docker run --rm builder:local validate-tools.sh
```

### Pinned Versions

All tool versions are pinned in the Dockerfile. This means a rebuild from the same commit will produce a functionally identical image (OS packages may differ due to apt updates, which is intentional for security patches).

### Rollback

To roll back to a previous version, pull by date tag or commit SHA:

```sh
docker pull ghcr.io/decima-cloud/builder:20260301
docker pull ghcr.io/decima-cloud/builder:a1b2c3d
```

### Weekly Scheduled Rebuild

The CI pipeline runs a weekly scheduled build (Monday 06:00 UTC) to pick up base image security patches. This ensures the image stays current even without code changes.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Update tool versions by changing the `ARG` values in the Dockerfile
4. Run validation locally: `docker build -t builder:test . && docker run --rm builder:test validate-tools.sh`
5. Open a pull request — CI will lint, build, scan, and test automatically

## License

MIT. See [LICENSE](LICENSE).
