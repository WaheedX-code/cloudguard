MATCH (b:S3Bucket)-[:TAGGED]->(:AWSTag {key:'DataClassification', value:'sensitive'})
MATCH (k:KMSKey) WHERE k.arn = b.encryption_key_id
MATCH (k)-[:HAS_POLICY_STATEMENT]->(ks:KMSKeyPolicyStatement)
WHERE ks.effect = 'Allow' AND any(a IN ks.action WHERE a IN ['kms:*','kms:Decrypt'])
MATCH (p:AWSPrincipal)
WHERE EXISTS {
    MATCH (p)-[:POLICY]->(:AWSPolicy)-[:STATEMENT]->(sb:AWSPolicyStatement)
    WHERE sb.effect = 'Allow'
      AND ((sb.action IS NOT NULL AND any(a IN sb.action WHERE a IN ['*','s3:*','s3:GetObject']))
        OR (sb.notaction IS NOT NULL AND NOT any(a IN sb.notaction WHERE a IN ['*','s3:*','s3:GetObject'])))
      AND any(r IN coalesce(sb.resource,[]) WHERE r = '*' OR r STARTS WITH b.arn)
  }
  AND ( p.arn IN ks.principal
        OR ( any(x IN ks.principal WHERE x ENDS WITH ':root')
             AND EXISTS {
               MATCH (p)-[:POLICY]->(:AWSPolicy)-[:STATEMENT]->(sk:AWSPolicyStatement)
               WHERE sk.effect = 'Allow'
                 AND ((sk.action IS NOT NULL AND any(a IN sk.action WHERE a IN ['*','kms:*','kms:Decrypt','kms:GenerateDataKey']))
                   OR (sk.notaction IS NOT NULL AND NOT any(a IN sk.notaction WHERE a IN ['*','kms:*','kms:Decrypt','kms:GenerateDataKey'])))
                 AND any(r IN coalesce(sk.resource,[]) WHERE r = '*' OR r CONTAINS k.key_id)
             } ) )
OPTIONAL MATCH chain = (f:AWSLambda)-[:STS_ASSUMEROLE_ALLOW*1..3]->(p)
RETURN p.name AS principal, ks.sid AS key_policy_statement, b.name AS data,
       collect(DISTINCT [n IN nodes(chain) | coalesce(n.name, n.arn)]) AS reached_from_function
ORDER BY principal, key_policy_statement;
