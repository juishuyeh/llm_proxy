# CLAUDE.md - AI Assistant Guide for LLM Proxy Service

This document provides comprehensive guidance for AI assistants working with the LLM Proxy codebase. It covers project structure, conventions, workflows, and best practices.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Key Configuration Files](#key-configuration-files)
5. [Development Workflows](#development-workflows)
6. [Model Configuration](#model-configuration)
7. [Deployment](#deployment)
8. [Testing and Validation](#testing-and-validation)
9. [Common Tasks](#common-tasks)
10. [Conventions and Best Practices](#conventions-and-best-practices)

---

## Project Overview

### What is This Project?

This is a **LiteLLM-based AI model proxy service** that provides:

- **Unified API Gateway**: OpenAI-compatible API for multiple LLM providers
- **Multi-Model Support**: Access to OpenRouter, Google Gemini, GitHub Models, GitHub Copilot, and local LM Studio models
- **Monitoring & Tracking**: MLflow integration for experiment tracking and metrics
- **Rate Limiting**: Built-in rate limiting to respect API quotas
- **Production Deployment**: Docker Compose orchestration

### Technology Stack

- **Core**: LiteLLM (Python-based LLM proxy)
- **Database**: PostgreSQL 16 (stores proxy metadata and MLflow data)
- **Monitoring**: MLflow 3.8.0 (experiment tracking)
- **Auth Proxy**: Nginx (basic auth proxy for MLflow)
- **Containerization**: Docker & Docker Compose
- **Python**: 3.13+ (managed via pyproject.toml)

### Current State (as of 2026-03-29)

- **Branch**: `main`
- **Recent Commits**: Model configuration updates, Dockerfile and MLflow version updates
- **Status**: Clean working tree

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────┐
│                   User / Application                    │
└───────────────────┬─────────────────────────────────────┘
                    │ HTTP (Port 4000)
                    ▼
┌─────────────────────────────────────────────────────────┐
│          LiteLLM Proxy Service (Port 4000)              │
│  - OpenAI-compatible API endpoints                      │
│  - Model routing and load balancing                     │
│  - API key authentication                               │
│  - Request/response logging                             │
└───┬─────────────────┬───────────────────┬───────────────┘
    │                 │                   │
    │ Store Logs      │ Export Metrics    │ Forward Requests
    ▼                 ▼                   ▼
┌──────────┐    ┌──────────┐      ┌──────────────────┐
│ MLflow   │    │PostgreSQL│      │  LLM Providers:  │
│(Port 5000│◄───┤(Port 5432│      │  - OpenRouter    │
│          │    │          │      │  - Google Gemini │
│          │    │          │      │  - GitHub Models │
└────┬─────┘    └──────────┘      │  - GitHub Copilot│
     │                            │  - LM Studio     │
     │ Nginx Auth Proxy           └──────────────────┘
     │ (Port 5001, basic auth)
     ▼
┌──────────┐
│  Nginx   │
│(Port 5001│
│  basic   │
│  auth)   │
└──────────┘
```

Note: Nginx serves only as a basic auth proxy for MLflow on port 5001. Users connect directly to LiteLLM on port 4000.

### Service Dependencies

```yaml
db (PostgreSQL)
  ↓ depends_on
mlflow
  ↓ depends_on        ↓ depends_on
litellm              nginx (MLflow auth proxy)
```

### Data Flow

1. **Request**: Client → LiteLLM (HTTP, Port 4000)
2. **Authentication**: LiteLLM validates `LITELLM_MASTER_KEY`
3. **Routing**: LiteLLM selects appropriate model/provider based on `model` parameter
4. **Rate Limiting**: LiteLLM enforces model-specific RPM limits
5. **Logging**: Request/response logged to MLflow and PostgreSQL
6. **Response**: LLM Provider → LiteLLM → Client

---

## Directory Structure

```
llm_proxy/
├── .git/                       # Git repository metadata
├── .env.example                # Environment variable template
├── .env                        # Environment variables (gitignored)
├── .gitignore                  # Git ignore patterns
├── .python-version             # Python version specification (3.13+)
├── .dockerignore               # Docker build ignore patterns
│
├── README.md                   # Main project documentation (Chinese)
├── CLAUDE.md                   # This file - AI assistant guide
│
├── config.yaml                 # LiteLLM model configuration ⭐
├── pyproject.toml              # Python project dependencies
├── uv.lock                     # UV package lock (gitignored)
│
├── Dockerfile                  # LiteLLM container image
├── Dockerfile.mlflow           # MLflow container image
├── docker-compose.yml          # Service orchestration ⭐
├── init-db.sql                 # PostgreSQL initialization
│
├── .htpasswd                   # MLflow basic auth credentials (gitignored)
```

### Important Files for AI Assistants

| File | Purpose | Modify Frequency |
|------|---------|------------------|
| `config.yaml` | Model list, rate limits, callbacks | High |
| `docker-compose.yml` | Service definitions, resource limits | Medium |
| `.env.example` | Environment variable documentation | Low |
| `README.md` | User-facing documentation | Medium |
| `.htpasswd` | MLflow basic auth credentials | Low |

### Files Never to Modify

- `.env` - User-specific secrets (gitignored)
- `.htpasswd` - MLflow basic auth credentials (gitignored)
- `uv.lock` - Auto-generated (gitignored)

---

## Key Configuration Files

### config.yaml

**Purpose**: Define available models, rate limits, and LiteLLM behavior

**Structure**:
```yaml
model_list:
  - model_name: "public/model-name"    # User-facing name
    litellm_params:
      model: "provider/actual-model"   # Provider-specific identifier
      api_key: "os.environ/KEY_NAME"   # Reference to env var
      rpm: 18                           # Requests per minute
      tpm: 125000                       # Tokens per minute (optional)
      rpd: 50                           # Requests per day (optional)
      extra_headers:                    # Provider-specific headers
        Header-Name: "value"

litellm_settings:
  drop_params: true                     # Drop unsupported params
  success_callback: ["mlflow"]          # Log successful requests
  failure_callback: ["mlflow"]          # Log failed requests

general_settings:
  master_key: "os.environ/LITELLM_MASTER_KEY"
  store_model_in_db: true              # Allow UI model management
```

**Conventions**:
- **Model Naming**: Use `provider/model-name` format (e.g., `google/gemini-2.5-pro`)
- **API Keys**: Always use `os.environ/KEY_NAME` references, never hardcode
- **Rate Limits**: Set RPM 10-20% below provider limits for safety margin
- **GitHub Copilot Models**: Require specific `extra_headers` to mimic VSCode

### docker-compose.yml

**Purpose**: Define Docker services, networking, volumes, and resource limits

**Services**:

1. **nginx** (MLflow auth proxy):
   - Ports: 5001:80
   - Volumes: `.htpasswd`
   - Resources: 0.5 CPU / 512M RAM
   - Depends on: `mlflow`

2. **litellm**:
   - Build: `Dockerfile`
   - Ports: 4000 (HTTP)
   - Volumes: `config.yaml`, `github_copilot_auth_data`
   - Environment: `DATABASE_URL`, `STORE_MODEL_IN_DB`
   - Resources: 2.0 CPU / 4G RAM
   - Depends on: `db`, `mlflow`

3. **db** (PostgreSQL):
   - Image: `postgres:16`
   - Ports: 5432 (exposed for external tools)
   - Volumes: `postgres_data`, `init-db.sql`
   - Environment: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
   - Resources: 1.0 CPU / 2G RAM

4. **mlflow**:
   - Build: `Dockerfile.mlflow`
   - Port: 5000 (internal, accessed via Nginx auth proxy on port 5001)
   - Volumes: `mlflow_data`
   - Command: MLflow server with PostgreSQL backend
   - Resources: 1.0 CPU / 2G RAM
   - Depends on: `db`

**Volumes**:
- `postgres_data` - PostgreSQL database persistence
- `mlflow_data` - MLflow artifacts and experiments
- `github_copilot_auth_data` - GitHub Copilot authentication cache

### .env.example

**Purpose**: Document required environment variables

**Categories**:

1. **UI Credentials**:
   ```bash
   UI_USERNAME='admin'
   UI_PASSWORD='your_secure_password_here'
   ```

2. **Database**:
   ```bash
   POSTGRES_DB='litellm'
   POSTGRES_USER='llmproxy'
   POSTGRES_PASSWORD='your_secure_db_password_here'
   ```

3. **LiteLLM**:
   ```bash
   LITELLM_MASTER_KEY='sk-your-master-key-here'
   ```

4. **LLM Providers**:
   ```bash
   OPENROUTER_API_KEY='your_openrouter_api_key_here'
   GEMINI_API_KEY='your_gemini_api_key_here'
   GITHUB_API_KEY='your_github_token_here'
   ```

5. **Local Models** (optional):
   ```bash
   LM_STUDIO_API_KEY='lm-studio'
   LM_STUDIO_API_BASE='http://host.docker.internal:1234/v1'
   OLLAMA_API_KEY='your_ollama_api_key'
   OLLAMA_API_BASE='http://host.docker.internal:11434'
   ```

6. **MLflow**:
   ```bash
   MLFLOW_TRACKING_URI='http://mlflow:5000'
   MLFLOW_EXPERIMENT_NAME='litellm-local-experiment'
   ```

**Important**: Docker Compose uses `host.docker.internal` to access services running on the Docker host.

---

## Development Workflows

### Setting Up Development Environment

```bash
# 1. Clone repository
git clone <repository-url>
cd llm_proxy

# 2. Create and configure .env
cp .env.example .env
# Edit .env with your API keys and passwords

# 3. Start services
docker compose up -d

# 4. Verify services
docker compose ps

# 5. Check logs
docker compose logs -f litellm
```

### Making Configuration Changes

#### Adding a New Model

1. **Edit config.yaml**:
   ```yaml
   model_list:
     - model_name: provider/new-model-name
       litellm_params:
         model: provider/actual-model-id
         api_key: "os.environ/PROVIDER_API_KEY"
         rpm: 10
   ```

2. **Add API key to .env** (if new provider):
   ```bash
   PROVIDER_API_KEY='your_api_key_here'
   ```

3. **Update .env.example** with placeholder:
   ```bash
   # New Provider API Key
   PROVIDER_API_KEY='your_provider_api_key_here'
   ```

4. **Restart LiteLLM**:
   ```bash
   docker compose restart litellm
   ```

5. **Test the model**:
   ```bash
   curl -X POST http://localhost:4000/v1/chat/completions \
     -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "provider/new-model-name",
       "messages": [{"role": "user", "content": "Hello"}]
     }'
   ```

#### Modifying Rate Limits

1. **Edit config.yaml**:
   ```yaml
   - model_name: google/gemini-2.5-flash
     litellm_params:
       model: gemini/gemini-2.5-flash
       rpm: 20  # Changed from 10
       tpm: 500000  # Changed from 250000
   ```

2. **Restart LiteLLM**:
   ```bash
   docker compose restart litellm
   ```

#### Adjusting Resource Limits

1. **Edit docker-compose.yml**:
   ```yaml
   litellm:
     deploy:
       resources:
         limits:
           cpus: '4.0'  # Increased from 2.0
           memory: 8G   # Increased from 4G
   ```

2. **Recreate container**:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Rebuilding Docker Images

**When to rebuild**:
- After modifying `Dockerfile` or `Dockerfile.mlflow`
- When updating base images
- After changing Python dependencies in `pyproject.toml`

**How to rebuild**:
```bash
# Rebuild all images
docker compose down
docker compose build --no-cache
docker compose up -d

# Rebuild specific service
docker compose build --no-cache litellm
docker compose up -d litellm
```

### Viewing Logs and Debugging

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f litellm

# Last N lines
docker compose logs --tail=100 litellm

# Search for errors
docker compose logs litellm | grep -i error

# Follow logs with timestamps
docker compose logs -f -t litellm
```

---

## Model Configuration

### Supported Providers

#### 1. OpenRouter (Free Models)

```yaml
- model_name: openai/gpt-oss-20b-or
  litellm_params:
    model: openrouter/openai/gpt-oss-20b:free
    api_key: "os.environ/OPENROUTER_API_KEY"
    rpm: 18  # OpenRouter free tier is 20 RPM
```

**Notes**:
- Free tier: 20 RPM limit
- Use `:free` suffix for free models
- Set RPM to 18 for safety margin

#### 2. Google Gemini

```yaml
- model_name: google/gemini-2.5-pro
  litellm_params:
    model: gemini/gemini-2.5-pro
    api_key: "os.environ/GEMINI_API_KEY"
    rpm: 2
    tpm: 125000
    rpd: 50
```

**Notes**:
- Supports rpm, tpm (tokens per minute), rpd (requests per day)
- Different models have different quota limits
- Vision models: `gemini-2.0-flash`, `gemini-2.5-flash`
- TTS model: `gemini-2.5-flash-tts` (very low RPM)

#### 3. GitHub Models

```yaml
- model_name: openai/gpt-4o-mini
  litellm_params:
    model: github/gpt-4o-mini
    api_key: "os.environ/GITHUB_API_KEY"
    rpm: 2
```

**Notes**:
- Requires GitHub Personal Access Token
- Very low rate limits (2 RPM)
- Free for GitHub users
- Prefix: `github/`

#### 4. GitHub Copilot

```yaml
- model_name: openai/gpt-4o-mini
  litellm_params:
    model: github_copilot/gpt-4o-mini-2024-07-18
    rpm: 10
    extra_headers:
      editor-version: "vscode/1.85.1"
      editor-plugin-version: "copilot/1.155.0"
      Copilot-Integration-Id: "vscode-chat"
      user-agent: "GithubCopilot/1.155.0"
```

**Notes**:
- Requires GitHub Copilot subscription
- Must include specific headers to mimic VSCode
- Higher RPM than GitHub Models (10 RPM)
- Vision models require: `Copilot-Vision-Request: "true"`
- Authentication cached in `github_copilot_auth_data` volume

#### 5. LM Studio (Local Models)

```yaml
- model_name: gemma-3-12b
  litellm_params:
    model: lm_studio/google/gemma-3-12b
```

**Notes**:
- No API key required
- Connects to LM Studio running on host: `http://host.docker.internal:1234/v1`
- No rate limits (local execution)
- Requires LM Studio to be running on Docker host
- Configure via `LM_STUDIO_API_BASE` in `.env`

### Rate Limiting Strategy

**Best Practices**:

1. **Set RPM below provider limits**: Use 80-90% of official limit
   - OpenRouter 20 RPM → set 18 RPM
   - GitHub 3 RPM → set 2 RPM

2. **Monitor with MLflow**: Check actual request rates via MLflow dashboard

---

## Deployment

### Local Development

```bash
# Start all services
docker compose up -d

# Access via localhost
curl http://localhost:4000/health/liveliness
```

**Use cases**:
- Development and testing
- Production deployment
- Access LiteLLM directly on port 4000
- Access MLflow UI via Nginx auth proxy on port 5001

---

## Testing and Validation

### Health Check

```bash
# Without authentication
curl http://localhost:4000/health/liveliness
# Expected: "I'm alive!"
```

### List Available Models

```bash
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

### Test Chat Completion

```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemini-2.5-flash",
    "messages": [
      {"role": "user", "content": "Say hello in 5 words"}
    ]
  }'
```

### Test with OpenAI Python SDK

```python
from openai import OpenAI

client = OpenAI(
    api_key="your-litellm-master-key",
    base_url="http://localhost:4000/v1"
)

response = client.chat.completions.create(
    model="google/gemini-2.5-flash",
    messages=[{"role": "user", "content": "Hello"}]
)

print(response.choices[0].message.content)
```

### Validate MLflow Tracking

1. **Access MLflow UI**: http://localhost:5001
2. **Check experiments**: Look for `litellm-local-experiment`
3. **View metrics**: Request counts, latencies, errors

---

## Common Tasks

### Update Model Configuration

**Scenario**: Need to add a new model or change rate limits

```bash
# 1. Edit config.yaml
nano config.yaml

# 2. Validate YAML syntax
docker run --rm -v $(pwd):/yaml alpine/yamllint /yaml/config.yaml

# 3. Restart LiteLLM
docker compose restart litellm

# 4. Verify changes
docker compose logs litellm --tail=50 | grep "model_name"

# 5. Test new model
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "new-model-name", "messages": [{"role": "user", "content": "Test"}]}'
```

### Backup Configuration and Data

```bash
# Create backup directory
mkdir -p backups

# Backup configuration files
tar -czf backups/config-$(date +%Y%m%d).tar.gz \
  config.yaml \
  docker-compose.yml \
  .env.example

# Backup PostgreSQL database
docker compose exec -T db pg_dump -U llmproxy litellm > backups/litellm-$(date +%Y%m%d).sql

# Backup MLflow database
docker compose exec -T db pg_dump -U llmproxy mlflow > backups/mlflow-$(date +%Y%m%d).sql
```

### Restore from Backup

```bash
# Restore configuration
tar -xzf backups/config-20260107.tar.gz

# Restore PostgreSQL
cat backups/litellm-20260107.sql | docker compose exec -T db psql -U llmproxy litellm
cat backups/mlflow-20260107.sql | docker compose exec -T db psql -U llmproxy mlflow

# Restart services
docker compose restart
```

### Update to Latest LiteLLM

```bash
# Pull latest images
docker compose pull

# Rebuild with latest base image
docker compose build --pull --no-cache litellm

# Restart with new image
docker compose up -d litellm

# Verify version
docker compose exec litellm pip show litellm
```

### Clean Up Docker Resources

```bash
# Stop services
docker compose down

# Remove unused images
docker image prune -a

# Remove unused volumes (CAUTION: This deletes data!)
docker volume prune

# Remove everything and start fresh
docker compose down -v  # -v removes volumes
docker compose up -d
```

### Monitor Resource Usage

```bash
# Docker stats
docker stats

# Specific service
docker stats litellm_proxy-litellm-1

# Disk usage
docker system df

# PostgreSQL database size
docker compose exec db psql -U llmproxy -d litellm -c "SELECT pg_size_pretty(pg_database_size('litellm'));"
```

### Add a New LLM Provider

**Complete workflow**:

1. **Research provider's LiteLLM integration**:
   - Check: https://docs.litellm.ai/docs/providers
   - Note: API key format, base URL, required headers

2. **Add API key to .env**:
   ```bash
   echo "NEW_PROVIDER_API_KEY='your_key_here'" >> .env
   ```

3. **Document in .env.example**:
   ```bash
   # New Provider API Key
   NEW_PROVIDER_API_KEY='your_new_provider_api_key_here'
   ```

4. **Add model to config.yaml**:
   ```yaml
   - model_name: provider/model-name
     litellm_params:
       model: provider/actual-model-id
       api_key: "os.environ/NEW_PROVIDER_API_KEY"
       rpm: 10
   ```

5. **Restart and test**:
   ```bash
   docker compose restart litellm

   curl -X POST http://localhost:4000/v1/chat/completions \
     -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model": "provider/model-name", "messages": [{"role": "user", "content": "Test"}]}'
   ```

6. **Update documentation**:
   - Add provider to README.md "支援的模型" section
   - Document any special requirements

---

## Conventions and Best Practices

### Code and Configuration

1. **YAML Formatting**:
   - Use 2-space indentation
   - Keep model definitions aligned
   - Add comments for non-obvious configurations

2. **Model Naming**:
   - Format: `provider/model-name`
   - Examples: `google/gemini-2.5-pro`, `openai/gpt-4o-mini`
   - Keep names consistent with provider documentation

3. **API Key Management**:
   - **NEVER** hardcode API keys in any file
   - Always use `os.environ/KEY_NAME` in config.yaml
   - Document all keys in .env.example
   - Keep .env file in .gitignore

4. **Rate Limit Safety**:
   - Set RPM 10-20% below provider's official limit
   - Test with small values first
   - Monitor actual usage via MLflow

5. **Docker Resources**:
   - Always set both `limits` and `reservations`
   - Leave headroom for traffic spikes
   - Monitor resource usage regularly

### Documentation

1. **README.md** (Chinese):
   - User-facing documentation
   - Getting started guide
   - Common troubleshooting

2. **CLAUDE.md** (English):
   - This file - AI assistant guidance
   - Architecture and internals
   - Development workflows

3. **Inline Comments**:
   - Use Chinese for user-facing configs (config.yaml, docker-compose.yml)
   - Use English for code comments
   - Explain "why", not "what"

### Git Workflow

1. **Branch Naming**:
   - Format: `claude/<task-description>-<session-id>`
   - Example: `claude/add-claude-documentation-rBkmr`
   - Must start with `claude/` for CI/CD compatibility

2. **Commit Messages**:
   - Use Chinese or English (project uses both)
   - Be descriptive: "更新 GitHub 模型配置,將 RPM 值從 10 調整為 2"
   - Reference issues when applicable

3. **Files to Never Commit**:
   - `.env` (secrets)
   - `.htpasswd` (MLflow auth credentials)
   - `uv.lock` (auto-generated)
   - `*_data/` (Docker volumes)

4. **Git Operations**:
   - Always push to feature branch: `git push -u origin claude/<branch-name>`
   - Retry network failures up to 4 times with exponential backoff
   - Create PRs against main branch when ready

### Security

1. **Secrets Management**:
   - Store all secrets in `.env` file
   - Never log secrets
   - Use strong passwords (min 16 chars)
   - Rotate API keys periodically

2. **Network Security**:
   - Protect MLflow UI with basic auth via Nginx proxy (port 5001)
   - Consider IP whitelisting for sensitive deployments

3. **Database Security**:
   - Use strong PostgreSQL passwords
   - Optionally remove port 5432 exposure if no external access needed
   - Regular backups

### Performance

1. **Resource Monitoring**:
   - Check `docker stats` regularly
   - Monitor PostgreSQL database size
   - Watch MLflow artifact storage growth

2. **Optimization**:
   - Adjust Docker resource limits based on actual usage
   - Consider PostgreSQL connection pooling for high traffic
   - Implement log rotation to prevent disk fill

3. **Scaling**:
   - Vertical: Increase CPU/memory limits in docker-compose.yml
   - Horizontal: Add multiple LiteLLM instances with load balancing
   - Database: Consider read replicas for MLflow queries

---

## Troubleshooting Guide

### Common Issues

#### 1. Service Won't Start

**Symptoms**: `docker compose up` fails

**Check**:
```bash
# View error logs
docker compose logs

# Check for port conflicts
lsof -i :4000 -i :5432 -i :5001

# Verify .env file exists and is valid
cat .env | grep -v '^#' | grep -v '^$'
```

#### 2. Database Connection Errors

**Symptoms**: LiteLLM logs show database connection failures

**Solutions**:
```bash
# Verify PostgreSQL is running
docker compose ps db

# Check database logs
docker compose logs db

# Verify credentials match between .env and docker-compose.yml
grep POSTGRES .env
grep POSTGRES docker-compose.yml

# Test database connection
docker compose exec db psql -U llmproxy -d litellm -c "SELECT 1;"
```

#### 3. Model Not Found

**Symptoms**: API returns "model not found" error

**Solutions**:
```bash
# List configured models
docker compose exec litellm cat /app/config.yaml | grep model_name

# Check LiteLLM startup logs for config errors
docker compose logs litellm | grep -i error

# Verify model name matches exactly
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq '.data[].id'
```

#### 4. Rate Limit Errors (429)

**Symptoms**: Requests fail with HTTP 429

**Identify source**:
- **LiteLLM**: "Rate limit exceeded for model X" in response
- **Provider**: Provider-specific error message

**Solutions**:
```bash
# Check model RPM limit (config.yaml)
grep -A 3 "model_name: google/gemini-2.5-flash" config.yaml

# View recent requests in logs
docker compose logs litellm --tail=100 | grep "429"
```

---

## Additional Resources

### External Documentation

- **LiteLLM**: https://docs.litellm.ai/
- **LiteLLM Providers**: https://docs.litellm.ai/docs/providers
- **MLflow**: https://mlflow.org/docs/latest/index.html
- **PostgreSQL**: https://www.postgresql.org/docs/16/
- **Docker Compose**: https://docs.docker.com/compose/

### Internal Documentation

- **README.md**: User guide and quick start (Chinese)
- **.env.example**: Environment variable reference

### Useful Commands Reference

```bash
# Quick service management
docker compose up -d              # Start all services
docker compose down               # Stop all services
docker compose restart litellm    # Restart specific service
docker compose ps                 # List running services
docker compose logs -f litellm    # Follow logs

# Configuration validation
docker compose config             # Validate docker-compose.yml
yamllint config.yaml             # Validate config.yaml

# Database operations
docker compose exec db psql -U llmproxy -d litellm    # PostgreSQL shell
docker compose exec db pg_dump -U llmproxy litellm    # Database backup

# Docker cleanup
docker compose down -v            # Remove everything including volumes
docker system prune -a            # Clean all unused Docker resources

# Testing
curl http://localhost:4000/health/liveliness                    # Health check
curl http://localhost:4000/v1/models -H "Authorization: Bearer $LITELLM_MASTER_KEY"  # List models
```

---

## AI Assistant Guidelines

### When Working with This Codebase

1. **Always read config files before modifying**: Use Read tool on config.yaml, docker-compose.yml before making changes

2. **Never hardcode secrets**: Use environment variables via `.env` file

3. **Test changes incrementally**:
   - Modify config.yaml → restart litellm → test
   - Don't change multiple things at once

4. **Maintain documentation**:
   - Update README.md when adding models
   - Update .env.example when adding new environment variables
   - Keep CLAUDE.md current with architecture changes

5. **Follow naming conventions**:
   - Git branches: `claude/<description>-<session-id>`
   - Models: `provider/model-name`
   - Environment variables: `UPPERCASE_WITH_UNDERSCORES`

6. **Security first**:
   - Never commit .env file
   - Never log API keys
   - Always validate user input

7. **Be explicit in commit messages**:
   - Explain what changed and why
   - Use Chinese or English consistently
   - Reference related changes

8. **Verify changes**:
   - Check logs after restart
   - Test API endpoints
   - Validate with health check
   - Monitor MLflow dashboard

---

**Document Version**: 1.1.0
**Last Updated**: 2026-03-29
**Maintained By**: AI Assistants working on this codebase
**Contact**: See repository issues for questions
