MATCH (sg:EC2SecurityGroup {groupid:'sg-0ec2ce5f8c425cb4a'})<-[:MEMBER_OF_EC2_SECURITY_GROUP]-(r:IpRule)
WHERE r.ruleid CONTAINS 'IpPermissionsEgress'
OPTIONAL MATCH (r)-[:MEMBER_OF_IP_RULE]-(rng:IpRange)
OPTIONAL MATCH (sg)<-[:MEMBER_OF_EC2_SECURITY_GROUP]-(ni:NetworkInterface)
RETURN sg.name AS group, r.protocol AS protocol, r.fromport AS fromport, rng.range AS destination, ni.description AS attached_to;
