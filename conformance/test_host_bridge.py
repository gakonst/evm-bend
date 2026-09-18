#!/usr/bin/env python3
"""Fixture-backed bridge regressions. No native EVM invocation."""
import copy,importlib.util,json,pathlib,subprocess,unittest
from unittest.mock import patch
import audit_host_bridge as B
A=B.A;R=B.R
class Capture(Exception):
 def __init__(self,transaction,authorities,binary):self.transaction=transaction;self.authorities=authorities;self.binary=binary
class HostBridgeTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.cs=list(B.cases());raws=list(dict.fromkeys(p['txbytes'] for _,_,_,p in cls.cs));cls.decoded=B.decode_cache(raws)
  cls.wire=[c for c in cls.cs if 'error' in cls.decoded[c[3]['txbytes']]]
  cls.auth=[c for c in cls.cs if cls.decoded[c[3]['txbytes']].get('decoded',{}).get('authorizationList')]
  cls.invalid_auth=next(c for c in cls.auth if any(x['authority'] is None for x in cls.decoded[c[3]['txbytes']]['decoded']['authorizationList']))
  cls.valid_auth=next(c for c in cls.auth if any(x['authority'] is not None for x in cls.decoded[c[3]['txbytes']]['decoded']['authorizationList']))
 def request(self,c):return R.state_input(c[2],c[3])
 def capture(self,request):
  original=A.encode_transaction
  def encode(tx,authorities=None):raise Capture(copy.deepcopy(tx),authorities,original(tx,authorities))
  with patch.object(A,'encode_transaction',encode):
   with self.assertRaises(Capture) as caught:A.execute(request)
  return caught.exception
 def fake_envelope(self,envelope):
  real=A.subprocess.run
  def run(command,*args,**kw):
   if command==[str(A.ENVELOPE)]:return subprocess.CompletedProcess(command,0,json.dumps(envelope),'')
   return real(command,*args,**kw)
  return patch.object(A.subprocess,'run',run)
 def test_raw_only_wire_rejection_matches_all_20_fixture_commitments(self):
  self.assertEqual(len(self.wire),20)
  for c in self.wire:
   req=self.request(c);req.pop('transaction');before=copy.deepcopy(req['pre'])
   actual=A.execute(req)
   self.assertEqual(actual['status'],'rejected');self.assertEqual(actual['post_state'],before)
   self.assertEqual(req['pre'],before);self.assertEqual(R.compare_state(c[2],c[3],actual),[])
 def test_wide_gas_signed_fixtures_serialize_without_narrowing(self):
  count=0
  for out in self.decoded.values():
   t=out.get('decoded')
   if t and B.N(t['gasLimit'])>=2**48:
    authorities=A.signed_authorities(t);B.compare_tx(t,authorities)
    self.assertEqual(B.read_tx(A.encode_transaction(t,authorities))['gasLimit'],B.N(t['gasLimit']));count+=1
  self.assertEqual(count,2)
 def test_raw_only_valid_authorization_transaction_serializes_exact_signed_fields(self):
  req=self.request(self.valid_auth);req.pop('transaction');got=self.capture(req)
  decoded=self.decoded[req['txbytes']]['decoded'];self.assertEqual(got.transaction,decoded)
  B.compare_tx(got.transaction,got.authorities)
  wire=B.read_tx(got.binary)
  self.assertEqual(wire['sender'],B.N(decoded['sender']))
  self.assertTrue(any(a['authority'] is not None for a in wire['authorizationList']))
 def test_signed_bytes_override_poisoned_fixture_sender_and_authority_annotations(self):
  req=self.request(self.valid_auth);clean=self.capture(req)
  req['transaction']={'sender':'0x'+'ff'*20,'nonce':'0xffff','gasLimit':'0x0','authorizationList':[{'signer':'0x'+'aa'*20,'authority':'0x'+'bb'*20}]}
  poisoned=self.capture(req);self.assertEqual(poisoned.binary,clean.binary)
 def test_null_recovery_is_preserved_and_never_replaced_by_fixture_signer(self):
  req=self.request(self.invalid_auth);got=self.capture(req);wire=B.read_tx(got.binary)
  expected=self.decoded[req['txbytes']]['decoded']['authorizationList']
  for a,e in zip(wire['authorizationList'],expected):
   self.assertEqual(a['authority'],B.N(e['authority']) if e['authority'] is not None else None)
  self.assertTrue(any(a['authority'] is None for a in wire['authorizationList']))
 def test_missing_or_inconsistent_recovery_is_host_error_not_skipped_authority(self):
  req=self.request(self.valid_auth);out=self.decoded[req['txbytes']]
  for change in ('missing_authority','missing_error','false_failure','missing_list','invented_error'):
   mutated=copy.deepcopy(out);auth=next(a for a in mutated['decoded']['authorizationList'] if a['authority'] is not None)
   if change=='missing_authority':auth.pop('authority')
   elif change=='missing_error':auth.pop('recoveryError')
   elif change=='false_failure':auth['authority']=None
   elif change=='missing_list':mutated['decoded'].pop('authorizationList')
   else:auth.update(authority=None,recoveryError={'category':'wire','exception':'TransactionException.NONCE_MISMATCH_TOO_HIGH'})
   with self.fake_envelope(mutated):
    with self.assertRaises((KeyError,ValueError)):A.execute(req)
 def test_semantic_or_invented_helper_errors_never_become_wire_rejections(self):
  req=self.request(self.valid_auth)
  for ex in ('TransactionException.INSUFFICIENT_ACCOUNT_FUNDS','TransactionException.INTRINSIC_GAS_TOO_LOW','TransactionException.RLP_MADE_UP'):
   with self.fake_envelope({'error':{'category':'wire','exception':ex}}):
    with patch.object(A,'crypto',side_effect=AssertionError('must not commit a fabricated rejection')):
     with self.assertRaisesRegex(ValueError,'envelope host input error'):A.execute(req)
 def test_extreme_corpus_contexts_preserve_all_256_bit_words(self):
  choices={max(self.cs,key=lambda c:B.N(c[2]['env'].get(key,0)))[0] for key in ('currentGasLimit','currentRandom','slotNumber')}
  for c in self.cs:
   if c[0] in choices:B.compare_context(c[2]['env'])
if __name__=='__main__':unittest.main(verbosity=2)
