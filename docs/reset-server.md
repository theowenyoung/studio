# Reset Server

## Complete Reset (One Command)

```bash
ssh deploy@5.78.126.18

# Stop all containers and clean everything
docker stop $(docker ps -aq) 2>/dev/null || true
docker system prune -a --volumes -f
rm -rf /srv/studio/*
docker network create shared
docker ps -a && docker images
```

## Deep Clean (Including Docker Data)

```bash
ssh deploy@5.78.126.18

sudo systemctl stop docker
sudo rm -rf /data/docker/*
sudo systemctl start docker
docker network create shared
```

## Clean Single Service

```bash
ssh deploy@5.78.126.18
cd /srv/studio/infra-apps/redis
docker compose down -v
cd .. && rm -rf redis
```

## Redeploy After Reset

```bash
mise run deploy-postgres
mise run deploy-redis
mise run deploy-caddy
```

**Note:** All data will be lost. Backup to S3 first if needed.
