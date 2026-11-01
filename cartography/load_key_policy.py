import json, sys
key_id = sys.argv[1]
pol = json.load(open('/tmp/keypolicy.json'))
def aslist(x): return x if isinstance(x, list) else [x]
kid = json.dumps(key_id)
print('MATCH (k:KMSKey {key_id:' + kid + '})-[:HAS_POLICY_STATEMENT]->(s) DETACH DELETE s;')
for i, st in enumerate(pol['Statement']):
    if 'NotAction' in st or 'NotPrincipal' in st:
        raise SystemExit('NotAction/NotPrincipal in key policy: loader needs extending')
    sid = st.get('Sid', 'stmt%d' % i)
    pr = st.get('Principal', {})
    plist = ['*'] if pr == '*' else [v for x in pr.values() for v in aslist(x)]
    props = ('{id:%s, sid:%s, effect:%s, principal:%s, action:%s, resource:%s, source:"aws kms get-key-policy"}'
             % (json.dumps(key_id + '/' + sid), json.dumps(sid), json.dumps(st['Effect']),
                json.dumps(plist), json.dumps(aslist(st.get('Action', []))), json.dumps(aslist(st.get('Resource', [])))))
    print('MATCH (k:KMSKey {key_id:' + kid + '}) CREATE (k)-[:HAS_POLICY_STATEMENT]->(:KMSKeyPolicyStatement ' + props + ');')
