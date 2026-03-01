# syntax=docker/dockerfile:1
# ============================================================================
# Builder — pre-configured dev environment for debugging and building images
# ============================================================================

# ---------------------------------------------------------------------------
# Pinned tool versions — update these ARGs to bump versions
# ---------------------------------------------------------------------------
ARG UBUNTU_VERSION=24.04

ARG AWSCLI_VERSION=2.24.4
ARG GCLOUD_VERSION=514.0.0
ARG VAULT_VERSION=1.18.4
ARG GO_VERSION=1.23.5
ARG NODE_MAJOR=22
ARG KUBECTL_VERSION=1.32.1
ARG HELM_VERSION=3.17.0
ARG TERRAFORM_VERSION=1.10.5
ARG TRIVY_VERSION=0.58.2
ARG HADOLINT_VERSION=2.12.0
ARG DIVE_VERSION=0.12.0
ARG YQ_VERSION=4.45.1

# ============================================================================
# Stage 1: downloader — fetch and extract standalone binaries
# ============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS downloader

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH

ARG AWSCLI_VERSION
ARG GCLOUD_VERSION
ARG VAULT_VERSION
ARG GO_VERSION
ARG KUBECTL_VERSION
ARG HELM_VERSION
ARG TERRAFORM_VERSION
ARG TRIVY_VERSION
ARG HADOLINT_VERSION
ARG DIVE_VERSION
ARG YQ_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /staging

# --- AWS CLI v2 ---
RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_SUFFIX}-${AWSCLI_VERSION}.zip" -o awscli.zip \
    && unzip -oq awscli.zip \
    && ./aws/install --install-dir /opt/aws-cli --bin-dir /usr/local/bin \
    && rm -rf awscli.zip aws/

# --- Google Cloud CLI ---
RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm" || echo "x86_64") \
    && curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION}-linux-${ARCH_SUFFIX}.tar.gz" \
       | tar -xz -C /opt \
    && /opt/google-cloud-sdk/install.sh --quiet --path-update=false

# --- HashiCorp Vault ---
RUN curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip" -o vault.zip \
    && unzip -oq vault.zip -d /usr/local/bin \
    && rm vault.zip

# --- Go ---
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" \
       | tar -xz -C /usr/local

# --- kubectl ---
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
       -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# --- Helm ---
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
       | tar -xz --strip-components=1 -C /usr/local/bin linux-${TARGETARCH}/helm

# --- Terraform ---
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" -o terraform.zip \
    && unzip -oq terraform.zip -d /usr/local/bin \
    && rm terraform.zip

# --- Trivy ---
RUN curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TARGETARCH}.tar.gz" \
       | tar -xz -C /usr/local/bin trivy

# --- hadolint ---
RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x86_64") \
    && curl -fsSL "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-${ARCH_SUFFIX}" \
       -o /usr/local/bin/hadolint \
    && chmod +x /usr/local/bin/hadolint

# --- dive ---
RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -fsSL "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_${ARCH_SUFFIX}.tar.gz" \
       | tar -xz -C /usr/local/bin dive

# --- yq ---
RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH_SUFFIX}" \
       -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq


# ============================================================================
# Stage 2: final — assemble the runtime image
# ============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS final

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG NODE_MAJOR
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/google-cloud-sdk/bin:/usr/local/go/bin:${PATH}"

# --- System packages, debugging tools, and build utilities ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        # core utilities
        ca-certificates \
        curl \
        gnupg \
        unzip \
        jq \
        vim \
        git \
        make \
        wget \
        shellcheck \
        # debugging
        strace \
        ltrace \
        tcpdump \
        net-tools \
        dnsutils \
        htop \
        # python
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# --- Azure CLI via pip in a venv (no piped scripts) ---
RUN python3 -m venv /opt/azure-cli \
    && /opt/azure-cli/bin/pip install --no-cache-dir azure-cli \
    && ln -s /opt/azure-cli/bin/az /usr/local/bin/az

# --- Node.js via NodeSource (pinned major version) ---
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- Docker CLI + buildx from official Docker apt repo ---
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       | gpg --dearmor -o /usr/share/keyrings/docker.gpg \
    && echo "deb [arch=${TARGETARCH} signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

# --- Copy binaries from downloader stage ---
COPY --from=downloader /opt/aws-cli           /opt/aws-cli
COPY --from=downloader /usr/local/bin/aws     /usr/local/bin/aws
COPY --from=downloader /usr/local/bin/aws_completer /usr/local/bin/aws_completer
COPY --from=downloader /opt/google-cloud-sdk  /opt/google-cloud-sdk
COPY --from=downloader /usr/local/bin/vault   /usr/local/bin/vault
COPY --from=downloader /usr/local/go          /usr/local/go
COPY --from=downloader /usr/local/bin/kubectl  /usr/local/bin/kubectl
COPY --from=downloader /usr/local/bin/helm     /usr/local/bin/helm
COPY --from=downloader /usr/local/bin/terraform /usr/local/bin/terraform
COPY --from=downloader /usr/local/bin/trivy    /usr/local/bin/trivy
COPY --from=downloader /usr/local/bin/hadolint /usr/local/bin/hadolint
COPY --from=downloader /usr/local/bin/dive     /usr/local/bin/dive
COPY --from=downloader /usr/local/bin/yq       /usr/local/bin/yq

# --- Vault capability fix (https://github.com/hashicorp/vault/issues/10924) ---
RUN setcap -r /usr/local/bin/vault || true

# --- Validation script ---
COPY scripts/validate-tools.sh /usr/local/bin/validate-tools.sh

# --- OCI labels ---
LABEL org.opencontainers.image.title="builder" \
      org.opencontainers.image.description="Pre-configured dev environment for debugging and building images" \
      org.opencontainers.image.source="https://github.com/decima-cloud/builder" \
      org.opencontainers.image.licenses="MIT"

CMD ["bash"]
