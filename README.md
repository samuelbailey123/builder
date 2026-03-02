# Builder

![Validation](https://img.shields.io/github/actions/workflow/status/decima-cloud/builder/build.yaml?branch=main&label=build)

Pre-configured Docker image for debugging, building other images, and working with cloud infrastructure. Ships with pinned versions of cloud CLIs, container tools, languages, and debugging utilities.

## Quick Start

```sh
docker pull ghcr.io/decima-cloud/builder:latest
docker run --rm -it ghcr.io/decima-cloud/builder:latest
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
docker run --rm -it \
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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Update tool versions by changing the `ARG` values in the Dockerfile
4. Run validation locally: `docker build -t builder:test . && docker run --rm builder:test validate-tools.sh`
5. Open a pull request — CI will lint, build, scan, and test automatically

## License

MIT. See [LICENSE](LICENSE).
