# Stable Diffusion WebUI Docker Stack

AUTOMATIC1111 Stable Diffusion Web UI running in a Docker container with GPU support.

## Prerequisites

- Docker and Docker Compose installed
- AMD GPU present with latest `amdgpu` driver in the kernel

## Accessing the Web UI

- Web UI: http://localhost:7860 (default bound to 127.0.0.1)
- Jupyter: http://localhost:8888 (optional)
- SSH: Port 2222 (optional)

Default credentials:
- Username: `user`
- Password: Set in `WEB_PASSWORD` environment variable

To expose externally, change `BIND_IP=0.0.0.0` in `.env`

## Directory Structure

```
stable-diffusion-webui/
├── docker-compose.yml
├── .env.dist
├── .env (created from .env.dist)
├── .gitignore
├── README.md
├── nginx/
│   └── stable-diffusion.conf.dist
├── config/              # Configuration files
└── data/
    ├── workspace/       # Main workspace directory
    ├── models/          # Model files
    ├── outputs/         # Generated images
    ├── extensions/      # WebUI extensions
    └── cache/           # Cache directories
        ├── huggingface/
        └── pip/
```

## Model Management

Place your models in the appropriate subdirectories:
- Checkpoints: `data/models/Stable-diffusion/`
- VAE: `data/models/VAE/`
- LoRA: `data/models/Lora/`
- Embeddings: `data/models/embeddings/`

## GPU Configuration

The stack uses all available NVIDIA GPUs by default. To limit to specific GPUs:

```env
# Use only GPU 0
CUDA_VISIBLE_DEVICES=0

# Use GPUs 0 and 1
CUDA_VISIBLE_DEVICES=0,1
```

## Performance Optimization

### For 16GB+ VRAM:
```env
WEBUI_ARGS=--xformers --api
```

### For 8GB VRAM:
```env
WEBUI_ARGS=--xformers --api --medvram
```

### For 4GB VRAM:
```env
WEBUI_ARGS=--xformers --api --lowvram
```

### For CPU only:
```env
IMAGE_TAG=latest-cpu
WEBUI_ARGS=--api --no-half --precision full
```

## Useful Commands

```bash
# View logs
docker-compose logs -f

# Restart service
docker-compose restart

# Stop service
docker-compose down

# Update image
docker-compose pull
docker-compose up -d

# Access container shell
docker-compose exec stable-diffusion-webui bash

# Check GPU usage
docker-compose exec stable-diffusion-webui nvidia-smi
```

## Troubleshooting

### Container fails to start
```bash
# Check NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# Check logs
docker-compose logs
```

### Out of memory errors
- Add `--medvram` or `--lowvram` to `WEBUI_ARGS`
- Reduce batch size in WebUI settings
- Close other GPU-using applications

### Permission issues
- Ensure UID/GID in `.env` match your user: `id -u` and `id -g`
- Fix ownership: `sudo chown -R $(id -u):$(id -g) data/`

### Models not appearing
- Check file permissions in `data/models/`
- Restart the container after adding models
- Verify model format compatibility

## Security Notes

- Default configuration binds to localhost only
- Set a strong `WEB_PASSWORD` before deployment
- Use reverse proxy with SSL for internet exposure
- Keep the image updated for security patches

## References

- [AUTOMATIC1111 WebUI](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
- [AI-Dock Image Documentation](https://github.com/ai-dock/stable-diffusion-webui)
- [Base Image Wiki](https://github.com/ai-dock/base-image/wiki)