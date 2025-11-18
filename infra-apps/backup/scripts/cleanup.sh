#!/bin/bash
set -e

# 设置默认保留天数
BACKUP_RETENTION_LOCAL=${BACKUP_RETENTION_LOCAL:-3}
BACKUP_RETENTION_S3=${BACKUP_RETENTION_S3:-30}

echo "[$(date)] Starting cleanup process"

# 清理本地旧备份
echo "[$(date)] Cleaning local backups older than ${BACKUP_RETENTION_LOCAL} days"

# 清理 Postgres 备份
if [ -d "/backups/postgres" ]; then
    DELETED_POSTGRES=$(find /backups/postgres -name "*.sql.gz" -mtime +${BACKUP_RETENTION_LOCAL} -delete -print | wc -l)
    echo "[$(date)] Deleted ${DELETED_POSTGRES} old Postgres backup(s)"
fi

# 清理 Redis 备份
if [ -d "/backups/redis" ]; then
    DELETED_REDIS=$(find /backups/redis -name "*.rdb" -mtime +${BACKUP_RETENTION_LOCAL} -delete -print | wc -l)
    echo "[$(date)] Deleted ${DELETED_REDIS} old Redis backup(s)"
fi

# 清理 S3 旧备份（如果配置了）
if [ -n "$S3_BUCKET" ] && [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo "[$(date)] Cleaning S3 backups older than ${BACKUP_RETENTION_S3} days"

    # 计算截止日期
    CUTOFF_DATE=$(date -d "${BACKUP_RETENTION_S3} days ago" +%Y%m%d 2>/dev/null || date -v-${BACKUP_RETENTION_S3}d +%Y%m%d 2>/dev/null || echo "")

    if [ -z "$CUTOFF_DATE" ]; then
        echo "[$(date)] WARNING: Could not calculate cutoff date, skipping S3 cleanup"
    else
        echo "[$(date)] Cutoff date: $CUTOFF_DATE"

        AWS_ARGS=""
        [ -n "$S3_ENDPOINT" ] && AWS_ARGS="$AWS_ARGS --endpoint-url $S3_ENDPOINT"
        [ -n "$S3_REGION" ] && AWS_ARGS="$AWS_ARGS --region $S3_REGION"

        # 清理 Postgres S3 备份
        echo "[$(date)] Checking Postgres S3 backups..."
        aws s3 ls "s3://${S3_BUCKET}/postgres/" $AWS_ARGS 2>/dev/null | \
            awk '{print $2}' | grep '^[0-9]' | \
            while read folder; do
                folder_date=${folder%/}
                if [ "$folder_date" -lt "$CUTOFF_DATE" ]; then
                    echo "[$(date)] Deleting S3 folder: postgres/$folder"
                    aws s3 rm "s3://${S3_BUCKET}/postgres/$folder" --recursive $AWS_ARGS
                fi
            done || echo "[$(date)] No old Postgres backups to delete"

        # 清理 Redis S3 备份
        echo "[$(date)] Checking Redis S3 backups..."
        aws s3 ls "s3://${S3_BUCKET}/redis/" $AWS_ARGS 2>/dev/null | \
            awk '{print $2}' | grep '^[0-9]' | \
            while read folder; do
                folder_date=${folder%/}
                if [ "$folder_date" -lt "$CUTOFF_DATE" ]; then
                    echo "[$(date)] Deleting S3 folder: redis/$folder"
                    aws s3 rm "s3://${S3_BUCKET}/redis/$folder" --recursive $AWS_ARGS
                fi
            done || echo "[$(date)] No old Redis backups to delete"
    fi
else
    echo "[$(date)] S3 cleanup skipped (S3_BUCKET or AWS credentials not set)"
fi

echo "[$(date)] Cleanup completed"
