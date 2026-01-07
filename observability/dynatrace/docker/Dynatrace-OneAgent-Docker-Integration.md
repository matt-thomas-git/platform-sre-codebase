# Dynatrace OneAgent Integration with Docker Container

## Overview
This guide documents the implementation of Dynatrace OneAgent in a Docker container, transitioning from a problematic ActiveGate-based approach to a direct API installation method.

**Author:** Platform Engineering Team  
**Last Updated:** 2025-05-29

---

## Original Issue vs Solution

### ❌ Original Problematic Approach
The original Dockerfile attempted to integrate Dynatrace OneAgent using a direct COPY instruction from an ActiveGate, which failed:

```dockerfile
# Original problematic approach
COPY --from=activegate.example.local:9999/linux/oneagent-codemodules:all / /
ENV LD_PRELOAD=/opt/dynatrace/oneagent/agent/lib64/liboneagentproc.so
```

**Why it failed:**
- Required direct access to the ActiveGate
- Authentication issues with the registry
- Incorrect path assumptions for the OneAgent library
- Not portable across environments

### ✅ Solution Implementation
Direct API-based installation using Dynatrace PaaS token.

---

## Prerequisites

- Docker installed
- Access to Dynatrace environment
- Dynatrace PaaS token with proper permissions
- Docker environment with proper network access

---

## Implementation

### Dockerfile

```dockerfile
FROM python:3.11-slim-buster
ENV ACCEPT_EULA=Y

#  ╭────────────────────────────────╮
#  │ Install Microsoft ODBC 18 deps │
#  ╰────────────────────────────────╯
RUN apt update \
  && apt upgrade -yqq \
  && apt install -yqq --no-install-recommends curl \
  gnupg2 \
  wget \
  procps

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
  && curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list

RUN apt update \
  && apt upgrade -yqq \
  && apt install -yqq msodbcsql18 \
  mssql-tools18 \
  build-essential \
  unixodbc-dev

#  ╭──────────────────────────────────────────╮
#  │ Make mssql-tools available for debugging │
#  ╰──────────────────────────────────────────╯
RUN echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc

#  ╭─────────────────────╮
#  │ Setup python things │
#  ╰─────────────────────╯
WORKDIR /usr/src/exporter
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir -r requirements.txt

#  ╭──────────────╮
#  │ Cleanup deps │
#  ╰──────────────╯
RUN apt remove -yqq \
  build-essential \
  g++ \
  gcc \
  gnupg2 \
  python2 \
  unixodbc-dev \
  && apt autoremove -yqq \
  && apt autoclean -yqq

#  ╭────────────────────────╮
#  │ Dynatrace OneAgent    │
#  ╰────────────────────────╯
ENV DT_API_URL="https://YOUR-ENVIRONMENT-ID.live.dynatrace.com/api"
ENV DT_ONEAGENT_OPTIONS="APP_LOG_CONTENT_ACCESS=1"
ENV DT_LOGSTREAM=stdout
ENV DT_LOGLEVELCON=INFO
ARG DT_PAAS_TOKEN

# Install required dependencies
RUN apt-get update && apt-get install -y wget curl

# OneAgent installation with debugging
RUN curl -L -o /tmp/oneagent.sh "${DT_API_URL}/v1/deployment/installer/agent/unix/default/latest?Api-Token=${DT_PAAS_TOKEN}&arch=x86&flavor=default" && \
    echo "OneAgent installer downloaded. Contents:" && \
    cat /tmp/oneagent.sh && \
    echo "Running OneAgent installer:" && \
    sh -x /tmp/oneagent.sh --set-host-group=app-exporter-group && \
    echo "OneAgent installation complete. Checking installation:" && \
    find / -type f -executable -name "oneagent" 2>/dev/null && \
    find / -name "liboneagentproc.so" 2>/dev/null && \
    echo "Checking /opt directory:" && \
    ls -R /opt && \
    mkdir -p /var/log/dynatrace/oneagent && \
    touch /var/log/dynatrace/oneagent/oneagent.log && \
    chmod 777 /var/log/dynatrace/oneagent/oneagent.log && \
    rm /tmp/oneagent.sh

# Set the LD_PRELOAD based on found library
RUN AGENT_LIB=$(find / -name "liboneagentproc.so" 2>/dev/null | head -n 1) && \
    if [ ! -z "$AGENT_LIB" ]; then \
        echo "OneAgent library found at: $AGENT_LIB" && \
        echo "export LD_PRELOAD=$AGENT_LIB" >> /etc/environment; \
    else \
        echo "OneAgent library not found"; \
    fi

# Locate OneAgent binary with more specific search
RUN ONEAGENT_BIN=$(find / -type f -executable -name "oneagent" 2>/dev/null | grep -v "/var/log" | head -n 1) && \
    if [ ! -z "$ONEAGENT_BIN" ]; then \
        echo "OneAgent binary found at: $ONEAGENT_BIN" && \
        $ONEAGENT_BIN --version && \
        $ONEAGENT_BIN --set-host-group=app-exporter-group start; \
    else \
        echo "OneAgent binary not found" && \
        find / -type f -name "oneagent*" 2>/dev/null; \
    fi

#  ╭───────────────────────────────────────────╮
#  │ Finally, copy the exporter app files over │
#  ╰───────────────────────────────────────────╯
COPY *.py .
COPY ./clients/* /usr/src/exporter/clients/
COPY ./monitors/* /usr/src/exporter/monitors/
COPY ./helpers/* /usr/src/exporter/helpers/
COPY ./config/* /usr/src/exporter/config/

EXPOSE 9000

# Modified ENTRYPOINT to use found OneAgent binary
ENTRYPOINT ["/bin/bash", "-c", "ONEAGENT_BIN=$(find / -type f -executable -name oneagent 2>/dev/null | grep -v '/var/log' | head -n 1) && if [ ! -z \"$ONEAGENT_BIN\" ]; then $ONEAGENT_BIN --set-host-group=app-exporter-group start; fi && python main.py"]
```

### Configuration File (cfg.json)

```json
{
  "availability_monitors": {
    "username": "monitoring@example.com",
    "password": "",
    "client_id": "app-client-id",
    "client_secret": "",
    "env": "dev"
  },
  "subscription_manager": {
    "tenant_names": ["Platform A"]
  },
  "sendgrid_monitor": {
    "url": "https://api.sendgrid.com/v3/stats"
  }
}
```

---

## Key Improvements in the Solution

### 1. Direct API Installation
- Downloads and installs directly from Dynatrace API
- Uses PaaS token for authentication
- Eliminates dependency on ActiveGate

### 2. Correct Library Path Configuration
- Uses actual installed path for `LD_PRELOAD`
- Ensures proper library loading
- Dynamic path discovery

### 3. Automatic Startup Management
- Implements proper startup sequence
- Ensures OneAgent starts before application
- Maintains monitoring across container restarts

### 4. Enhanced Logging and Debugging
- Creates dedicated log directory
- Sets appropriate permissions
- Enables verbose logging for troubleshooting

---

## Implementation Steps

### 1. Build the Docker Image

```bash
docker build --build-arg DT_PAAS_TOKEN=<your-paas-token> --tag app-exporter-local .
```

Replace `<your-paas-token>` with your Dynatrace PaaS token.

### 2. Run the Container

```bash
docker run -d -p 9000:9000 --env-file=.env --name app-exporter app-exporter-local
```

---

## Validation Steps

Execute these commands to verify the OneAgent installation and operation:

### Start OneAgent
```bash
docker exec app-exporter sh -c "/etc/init.d/oneagent start"
```

### Check OneAgent Binary Location
```bash
docker exec app-exporter sh -c "find / -type f -executable -name oneagent 2>/dev/null"
```

### Check OneAgent Library Location
```bash
docker exec app-exporter sh -c "find / -name liboneagentproc.so 2>/dev/null"
```

### Check Running Processes
```bash
docker exec app-exporter sh -c "ps aux | grep oneagent"
```

### Check OneAgent Logs
```bash
docker exec app-exporter sh -c "cat /var/log/dynatrace/oneagent/oneagent.log"
```

### Verify LD_PRELOAD Setting
```bash
docker exec app-exporter sh -c "echo $LD_PRELOAD"
```

### Check OneAgent Status
```bash
docker exec app-exporter sh -c "/etc/init.d/oneagent status"
```

---

## Verification in Dynatrace Portal

After implementation, verify that the container appears in your Dynatrace portal:

1. Navigate to your Dynatrace environment
2. Check under **"Hosts"** or **"Technologies & Processes"**
3. Look for the container name or host group **"app-exporter-group"**
4. Verify metrics are being collected

---

## Troubleshooting Guide

### Common Issues and Solutions

#### OneAgent Not Appearing in Dynatrace
- Check container logs: `docker logs app-exporter`
- Verify network connectivity to Dynatrace
- Confirm PaaS token permissions
- Review OneAgent logs for errors

#### Library Loading Issues
- Verify `LD_PRELOAD` path
- Check library file existence
- Confirm file permissions

#### Startup Problems
- Check init.d script execution
- Verify startup sequence in logs
- Confirm proper environment variables

---

## Best Practices

1. **Always use PaaS tokens with minimum required permissions**
2. **Maintain proper logging configuration**
3. **Regularly verify OneAgent status**
4. **Keep Dockerfile and configurations in version control**
5. **Document any environment-specific configurations**

---

## Notes and Considerations

- The OneAgent starts automatically with the container
- `LD_PRELOAD` environment variable is crucial for proper instrumentation
- Network access to Dynatrace environment is required
- PaaS token requires proper permissions (InstallerDownload)
- Solution is more portable across environments
- Removes dependency on ActiveGate access
- Provides better error handling and logging

---

## Security Considerations

- Store PaaS tokens securely (use Docker secrets or environment variables)
- Never commit tokens to version control
- Rotate tokens regularly
- Use minimal permissions for PaaS tokens
- Monitor token usage in Dynatrace

---

## Additional Resources

- [Dynatrace OneAgent Documentation](https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-oneagent)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Dynatrace API Documentation](https://www.dynatrace.com/support/help/dynatrace-api)
