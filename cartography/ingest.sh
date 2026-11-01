#!/usr/bin/env bash
set -euo pipefail
LOG="${1:?usage: ingest.sh <log-file>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
neo() { docker exec -i cartography-neo4j cypher-shell -u neo4j -p "$(cat ~/.cartography-neo4j-pw)"; }

run_cartography() {
  read -r AK SK ST <<< "$(aws sts assume-role \
    --role-arn arn:aws:iam::113410693155:role/cloudguard-cartography-read \
    --role-session-name cartography \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)"
  AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_SESSION_TOKEN="$ST" \
  NEO4J_PASSWORD="$(cat ~/.cartography-neo4j-pw)" \
  docker run --rm --network cartography-net \
    -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN \
    -e AWS_DEFAULT_REGION=us-east-1 -e NEO4J_PASSWORD \
    cartography-local \
    --neo4j-uri bolt://cartography-neo4j:7687 --neo4j-user neo4j \
    --neo4j-password-env-var NEO4J_PASSWORD \
    --selected-modules aws --aws-regions us-east-1 --aws-best-effort-mode > "$LOG" 2>&1
}

for attempt in 1 2 3; do
  run_cartography
  if ! grep -q "EndpointConnectionError" "$LOG"; then break; fi
  cp "$LOG" "$LOG.attempt$attempt"
  echo "attempt $attempt hit EndpointConnectionError, retrying" >&2
done
if grep -q "EndpointConnectionError" "$LOG"; then
  echo "SANITY FAIL: EndpointConnectionError after 3 attempts" >> "$LOG"; exit 1
fi

for KEY in $(aws kms list-keys --query 'Keys[].KeyId' --output text); do
  MGR=$(aws kms describe-key --key-id "$KEY" --query KeyMetadata.KeyManager --output text)
  [ "$MGR" = CUSTOMER ] || continue
  aws kms get-key-policy --key-id "$KEY" --policy-name default --query Policy --output text > /tmp/keypolicy.json
  python3 "$HERE/load_key_policy.py" "$KEY" | neo >> "$LOG" 2>&1
done

{
  echo "MATCH (:S3Bucket)-[r:ENCRYPTED_WITH_KMS]->() DELETE r;"
  for B in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
    K=$(aws s3api get-bucket-encryption --bucket "$B" \
      --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID' \
      --output text 2>/dev/null || true)
    if [ -n "$K" ] && [ "$K" != "None" ]; then
      echo "MATCH (b:S3Bucket {name:'$B'}), (k:KMSKey {arn:'$K'}) MERGE (b)-[r:ENCRYPTED_WITH_KMS]->(k) SET r.source='aws s3api get-bucket-encryption';"
    fi
  done
} | neo >> "$LOG" 2>&1

COUNTS="$(neo <<< "MATCH (n) UNWIND labels(n) AS l WITH l, count(*) AS c WHERE l IN ['AWSLambda','S3Bucket','KMSKey','AWSRole','EC2SecurityGroup','AWSPolicyStatement','KMSKeyPolicyStatement'] RETURN l, c ORDER BY l;")"
echo "$COUNTS" >> "$LOG"
for L in AWSLambda S3Bucket KMSKey AWSRole EC2SecurityGroup AWSPolicyStatement KMSKeyPolicyStatement; do
  echo "$COUNTS" | grep -q "\"$L\"" || { echo "SANITY FAIL: no $L nodes" >> "$LOG"; exit 1; }
done
echo "SANITY OK" >> "$LOG"
echo "ingest finished $(date -u +%FT%TZ)" >> "$LOG"
