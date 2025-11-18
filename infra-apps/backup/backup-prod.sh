#!/bin/bash
# 生产环境备份快捷脚本

set -e

cd "$(dirname "$0")"

case "$1" in
  all)
    echo "🔄 Backing up all services (PRODUCTION)..."
    docker compose -f docker-compose.prod.yml run --rm backup /usr/local/bin/backup-all.sh
    ;;
  postgres)
    echo "🔄 Backing up PostgreSQL (PRODUCTION)..."
    docker compose -f docker-compose.prod.yml run --rm backup /usr/local/bin/backup-postgres.sh
    ;;
  redis)
    echo "🔄 Backing up Redis (PRODUCTION)..."
    docker compose -f docker-compose.prod.yml run --rm backup /usr/local/bin/backup-redis.sh
    ;;
  cleanup)
    echo "🧹 Cleaning up old backups (PRODUCTION)..."
    docker compose -f docker-compose.prod.yml run --rm backup /usr/local/bin/cleanup.sh
    ;;
  test)
    echo "🔍 Testing database connections (PRODUCTION)..."
    docker compose -f docker-compose.prod.yml run --rm backup /usr/local/bin/test-connection.sh
    ;;
  logs)
    echo "📋 Viewing backup logs (PRODUCTION)..."
    if docker compose -f docker-compose.prod.yml ps backup | grep -q "Up"; then
      docker compose -f docker-compose.prod.yml exec backup tail -f /var/log/backup.log
    else
      echo "⚠️  Backup service is not running. Start it with: docker compose -f docker-compose.prod.yml up -d"
    fi
    ;;
  list)
    echo "📁 PostgreSQL backups:"
    ls -lh /data/backups/postgres/ 2>/dev/null || echo "  No backups found"
    echo ""
    echo "📁 Redis backups:"
    ls -lh /data/backups/redis/ 2>/dev/null || echo "  No backups found"
    ;;
  stats)
    echo "💾 Backup storage statistics:"
    du -sh /data/backups/* 2>/dev/null || echo "  No backups found"
    echo ""
    echo "💽 Disk usage:"
    df -h /data/backups 2>/dev/null || df -h /data
    ;;
  status)
    echo "📊 Backup service status (PRODUCTION):"
    docker compose -f docker-compose.prod.yml ps backup
    ;;
  *)
    echo "Usage: $0 {all|postgres|redis|cleanup|test|logs|list|stats|status}"
    echo ""
    echo "Commands:"
    echo "  all      - Backup all services (PostgreSQL + Redis)"
    echo "  postgres - Backup PostgreSQL only"
    echo "  redis    - Backup Redis only"
    echo "  cleanup  - Clean up old backups"
    echo "  test     - Test database connections"
    echo "  logs     - View backup logs (requires service running)"
    echo "  list     - List backup files"
    echo "  stats    - Show storage statistics"
    echo "  status   - Show backup service status"
    exit 1
    ;;
esac
