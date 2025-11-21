#!/bin/bash
set -e

echo "[$(date)] Starting smart S3 cleanup (3-2-1 strategy)"
echo ""

# 检查 S3 配置
if [ -z "$S3_BUCKET" ] || [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "[$(date)] S3 cleanup skipped (S3_BUCKET or AWS credentials not set)"
    exit 0
fi

AWS_ARGS=""
[ -n "$S3_ENDPOINT" ] && AWS_ARGS="$AWS_ARGS --endpoint-url $S3_ENDPOINT"
[ -n "$S3_REGION" ] && AWS_ARGS="$AWS_ARGS --region $S3_REGION"

# 计算关键日期（使用 UTC 时区）
TODAY=$(date -u +%Y%m%d)
SEVEN_DAYS_AGO=$(date -u -d "7 days ago" +%Y%m%d 2>/dev/null || date -u -v-7d +%Y%m%d)
THIRTY_DAYS_AGO=$(date -u -d "30 days ago" +%Y%m%d 2>/dev/null || date -u -v-30d +%Y%m%d)
NINETY_DAYS_AGO=$(date -u -d "90 days ago" +%Y%m%d 2>/dev/null || date -u -v-90d +%Y%m%d)

echo "Retention Strategy:"
echo "  📅 Last 7 days ($SEVEN_DAYS_AGO - $TODAY): Keep ALL"
echo "  📅 7-30 days ($THIRTY_DAYS_AGO - $SEVEN_DAYS_AGO): Keep WEEKLY (Sundays)"
echo "  📅 30-90 days ($NINETY_DAYS_AGO - $THIRTY_DAYS_AGO): Keep MONTHLY (1st of month)"
echo "  📅 >90 days: DELETE"
echo ""

cleanup_database() {
    local DB_TYPE=$1
    echo "=========================================="
    echo "Cleaning up ${DB_TYPE} backups"
    echo "=========================================="
    echo ""

    # 获取所有日期目录
    DATES=$(aws s3 ls "s3://${S3_BUCKET}/${DB_TYPE}/" $AWS_ARGS 2>/dev/null | \
        grep "PRE" | awk '{print $2}' | sed 's/\///' | grep '^[0-9]' || true)

    if [ -z "$DATES" ]; then
        echo "No backups found for ${DB_TYPE}"
        return
    fi

    echo "$DATES" | while read folder_date; do
        # 90天以上：直接删除
        if [ "$folder_date" -lt "$NINETY_DAYS_AGO" ]; then
            echo "❌ DELETE: $folder_date (>90 days old)"
            aws s3 rm "s3://${S3_BUCKET}/${DB_TYPE}/${folder_date}/" --recursive $AWS_ARGS

        # 最近7天：保留所有
        elif [ "$folder_date" -ge "$SEVEN_DAYS_AGO" ]; then
            echo "✅ KEEP: $folder_date (last 7 days)"

        # 7-30天：只保留周日
        elif [ "$folder_date" -ge "$THIRTY_DAYS_AGO" ]; then
            # 计算是星期几 (0=Sunday)，使用 UTC 时区
            DAY_OF_WEEK=$(date -u -d "$folder_date" +%w 2>/dev/null || \
                          date -u -j -f "%Y%m%d" "$folder_date" +%w 2>/dev/null || echo "")

            if [ "$DAY_OF_WEEK" = "0" ]; then
                echo "✅ KEEP: $folder_date (Sunday backup, 7-30 days)"
            else
                echo "❌ DELETE: $folder_date (not Sunday, 7-30 days)"
                aws s3 rm "s3://${S3_BUCKET}/${DB_TYPE}/${folder_date}/" --recursive $AWS_ARGS
            fi

        # 30-90天：只保留每月1号
        else
            # 提取日期的 day 部分
            DAY=$(echo "$folder_date" | cut -c7-8)

            if [ "$DAY" = "01" ]; then
                echo "✅ KEEP: $folder_date (1st of month, 30-90 days)"
            else
                echo "❌ DELETE: $folder_date (not 1st of month, 30-90 days)"
                aws s3 rm "s3://${S3_BUCKET}/${DB_TYPE}/${folder_date}/" --recursive $AWS_ARGS
            fi
        fi
    done

    echo ""
}

# 清理 PostgreSQL 备份
cleanup_database "postgres"

# 清理 Redis 备份
cleanup_database "redis"

echo "=========================================="
echo "[$(date)] Smart S3 cleanup completed!"
echo "=========================================="
