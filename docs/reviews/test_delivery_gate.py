import copy
import unittest
from delivery_gate import validate


class DeliveryGateTests(unittest.TestCase):
    def setUp(self):
        self.facts = dict(dirty=[], divergence=[0, 0], stash=[], worktrees=['target'],
                          branches={'old': {'sha': 'abc', 'exclusive': ['abc']}},
                          changedActions=['chat.attach'], missingSkillFiles=[])
        self.report = dict(completion='partial', target='target', protectedWorktrees={},
                           residualBranches={'old': dict(sha='abc', exclusive=['abc'],
                               disposition='retained-review', reason='Historical candidate',
                               evidence='review.md', owner='C0', nextGate='Compare current successor')},
                           ownerItems=[dict(id='owner.photo', status='open', actionIds=['chat.attach'],
                               evidence='review.md', owner='C0', nextGate='Normal upload',
                               fe='open', be='open', e2e='open')],
                           trackerActionIds=['chat.attach'], evidenceFiles=['review.md'],
                           memory=dict(status='no-op', reason='No durable change'),
                           deployment=dict(status='not-requested', evidence='review.md'))

    def errors(self, report=None, facts=None):
        return validate(report or self.report, facts or self.facts)

    def test_explicit_partial_is_valid_but_not_complete(self):
        self.assertEqual(self.errors(), [])

    def test_unclassified_historical_branch_blocks_delivery(self):
        self.report['residualBranches'] = {}
        self.assertTrue(self.errors())

    def test_missing_exclusive_commit_blocks_delivery(self):
        self.report['residualBranches']['old']['exclusive'] = []
        self.assertTrue(self.errors())

    def test_missing_owner_item_blocks_changed_action(self):
        self.report['ownerItems'] = []
        self.assertTrue(self.errors())

    def test_missing_evidence_blocks_done_item(self):
        self.report['ownerItems'][0]['evidence'] = 'absent.md'
        self.assertTrue(self.errors())

    def test_open_item_forbids_complete_claim(self):
        self.report['completion'] = 'complete'
        self.assertTrue(self.errors())

    def test_retained_review_forbids_complete_consolidation(self):
        self.report['completion'] = 'complete'
        self.report['ownerItems'][0]['status'] = 'done'
        self.assertTrue(self.errors())

    def test_dirty_or_ahead_worktree_forbids_delivery(self):
        for change in [dict(dirty=['file.dart']), dict(divergence=[1, 0]),
                       dict(divergence=[0, 1]), dict(worktrees=['target', 'forgotten'])]:
            facts = {**self.facts, **change}
            self.assertTrue(self.errors(facts=facts))

    def test_missing_target_skill_forbids_delivery(self):
        self.facts['missingSkillFiles'] = ['coelo-ui/SKILL.md']
        self.assertTrue(self.errors())

    def test_unreported_stash_forbids_delivery(self):
        self.facts['stash'] = ['stash@{0}']
        self.assertTrue(self.errors())

    def test_missing_layer_or_tracker_action_forbids_delivery(self):
        del self.report['ownerItems'][0]['be']
        self.assertTrue(self.errors())
        self.report['ownerItems'][0]['be'] = 'open'
        self.report['trackerActionIds'] = []
        self.assertTrue(self.errors())

    def test_protected_checkout_requires_reason(self):
        self.facts['worktrees'].append('main')
        self.report['protectedWorktrees'] = {'main': ''}
        self.assertTrue(self.errors())
        self.report['protectedWorktrees']['main'] = 'Owner forbids editing main'
        self.assertEqual(self.errors(), [])


if __name__ == '__main__':
    unittest.main()
