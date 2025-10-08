#!/bin/bash

# AWS Free Tier Usage Monitor
# Run this script to check current usage against free tier limits

echo "=== AWS Free Tier Usage Monitor ==="
echo "Date: $(date)"
echo ""

# Get current month
CURRENT_MONTH=$(date +%Y-%m)
START_DATE="${CURRENT_MONTH}-01"
END_DATE=$(date +%Y-%m-%d)

echo "Monitoring period: $START_DATE to $END_DATE"
echo ""

# EC2 Usage
echo "📊 EC2 Instance Usage:"
INSTANCES=$(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,InstanceType,LaunchTime]' --output table)
echo "$INSTANCES"

RUNNING_COUNT=$(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text | wc -w)
HOURS_THIS_MONTH=$(($(date +%d) * 24 * $RUNNING_COUNT))
echo "Estimated hours this month: $HOURS_THIS_MONTH / 750 (Free Tier)"

if [ $HOURS_THIS_MONTH -gt 750 ]; then
    echo "⚠️  WARNING: Exceeding free tier EC2 hours!"
else
    echo "✅ Within free tier limits"
fi
echo ""

# S3 Usage
echo "📊 S3 Storage Usage:"
BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
TOTAL_SIZE=0

for BUCKET in $BUCKETS; do
    SIZE=$(aws s3api list-objects-v2 --bucket "$BUCKET" --query 'sum(Contents[].Size)' --output text 2>/dev/null || echo "0")
    if [ "$SIZE" != "None" ] && [ "$SIZE" != "0" ]; then
        SIZE_MB=$((SIZE / 1024 / 1024))
        echo "  $BUCKET: ${SIZE_MB} MB"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE_MB))
    fi
done

echo "Total S3 usage: ${TOTAL_SIZE} MB / 5120 MB (Free Tier)"
if [ $TOTAL_SIZE -gt 5120 ]; then
    echo "⚠️  WARNING: Exceeding free tier S3 storage!"
else
    echo "✅ Within free tier limits"
fi
echo ""

# Data Transfer (approximate from CloudWatch)
echo "📊 Data Transfer (last 7 days):"
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name NetworkOut \
    --dimensions Name=InstanceId,Value=$(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text | head -1) \
    --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 86400 \
    --statistics Sum \
    --query 'Datapoints[].Sum' \
    --output text 2>/dev/null | awk '{
        total = 0
        for(i=1; i<=NF; i++) total += $i
        gb = total / 1024 / 1024 / 1024
        printf "Network out (7 days): %.2f GB\n", gb
        if(gb > 25) print "⚠️  High data transfer - monitor monthly usage"
        else print "✅ Data transfer looks normal"
    }' || echo "Unable to fetch network metrics"

echo ""

# Cost estimate
echo "💰 Estimated Monthly Costs (if exceeding free tier):"
echo "  EC2 t2.micro: \$8.50/month"
echo "  EBS 30GB: \$3.00/month"
echo "  S3 (per GB): \$0.023/month"
echo "  Data transfer (per GB): \$0.09/month"
echo ""

echo "🔍 For detailed billing info, check AWS Cost Explorer:"
echo "https://console.aws.amazon.com/cost-management/home"