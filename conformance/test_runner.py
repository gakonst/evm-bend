import unittest
import runner as R
class GateTests(unittest.TestCase):
 def test_absent_adapter_is_not_pass(self):
  self.assertEqual(R.execute({'format':'state_test'},None,set(),1)['status'],'not_run')
 def test_missing_capability_is_blocked(self):
  self.assertEqual(R.execute({'format':'state_test'},['unused'],set(),1)['status'],'blocked')
 def test_wrong_commitment_fails(self):
  post={'hash':'0x1','logs':'0x2'}
  self.assertEqual(len(R.compare_state({},post,{'state_root':'0x3','logs_hash':'0x2'})),1)
 def test_missing_commitments_fail(self):
  self.assertEqual(len(R.compare_state({},{'hash':'0x1','logs':'0x2'},{})),2)
 def test_wrong_exception_fails(self):
  post={'hash':'0x1','logs':'0x2','expectException':'wanted'}
  self.assertTrue(R.compare_state({},post,{'exception':'other','state_root':'0x1','logs_hash':'0x2'}))
 def test_index_selection_no_expected_results(self):
  unit={'env':{},'pre':{},'transaction':{'sender':'0x1','secretKey':'public-test-key','data':['0x00','0x01'],'gasLimit':['0x5','0x6'],'value':['0x7','0x8'],'accessLists':[[],[{'address':'0x2','storageKeys':[]}]]},'post':{'Amsterdam':[{'hash':'must-not-be-visible'}]},'out':'must-not-be-visible','_info':{'hash':'must-not-be-visible'}}
  req=R.state_input(unit,{'indexes':{'data':1,'gas':0,'value':1}})
  self.assertEqual(req['transaction']['data'],'0x01');self.assertEqual(req['transaction']['gasLimit'],'0x5');self.assertEqual(req['transaction']['value'],'0x8')
  self.assertNotIn('secretKey',req['transaction']);self.assertNotIn('post',req);self.assertNotIn('out',req);self.assertNotIn('_info',req)
 def test_zero_storage_canonicalization(self):
  a={'0x01':{'nonce':'0x00','balance':'0x0','code':'0x','storage':{'0x02':'0x00'}}};b={'0x1':{'nonce':0,'balance':0,'code':'','storage':{}}}
  self.assertEqual(R.canonical_alloc(a),R.canonical_alloc(b))
 def test_missing_account_not_equal_empty_account(self):
  self.assertNotEqual(R.canonical_alloc({}),R.canonical_alloc({'0x1':{'nonce':0,'balance':0,'code':'','storage':{}}}))
if __name__=='__main__':unittest.main()
