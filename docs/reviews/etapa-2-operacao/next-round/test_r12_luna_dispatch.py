"""Focused handoff safety tests; no real model, git mutation or production access."""
import importlib.util
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('dispatch', Path(__file__).with_name('r12-luna-dispatch.py'))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class DispatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name)
        self.cfg = {'runId': 'a' * 32, 'test': False, 'codex': 'unused', 'expiresAt': time.time() + 30}
        d.write(self.state / 'config.json', self.cfg)
        d.write(self.state / 'ready.json', {'runId': self.cfg['runId'], 'test': False, 'sha': 'fixture'})
        self.usage = {'rateLimitsByLimitId': {'reserve': {'limitName': 'gpt-reserve',
                      'normalModelSlug': d.MODEL, 'primary': {'usedPercent': 17}}}}

    def execute(self, result, usage=None):
        with patch.object(d, 'validate_release', return_value='fixture'), \
             patch.object(d, 'quota', return_value=usage or self.usage), \
             patch.object(d, 'execute_model', return_value=result) as model:
            d.watch(self.state)
            return model.call_args_list

    def test_limit_retries_same_thread_once_using_real_reserve_alias(self):
        calls = self.execute({'failure': 'usage_limit', 'threadId': 'synthetic-id'})
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[1].args[2], 'synthetic-id')
        self.assertTrue(calls[1].kwargs['reserve'])
        self.assertEqual(d.read(self.state / 'retry.json')['model'], 'gpt-reserve')

    def test_other_failure_does_not_restart(self):
        self.assertEqual(len(self.execute({'failure': 'other', 'threadId': 'x'})), 1)

    def test_completed_run_does_not_restart(self):
        self.assertEqual(len(self.execute({'failure': None, 'threadId': 'x'})), 1)

    def test_explicit_checkpoint_transition_uses_reserve(self):
        d.write(self.state / 'continuation.json', {'status': 'needs_reserve'})
        calls = self.execute({'failure': None, 'threadId': 'x'})
        self.assertEqual(len(calls), 2)
        self.assertTrue((self.state / 'continuation-before-reserve.json').exists())

    def test_unavailable_reserve_does_not_retry(self):
        calls = self.execute({'failure': 'usage_limit', 'threadId': 'x'}, {'rateLimitsByLimitId': {}})
        self.assertEqual(len(calls), 1)
        self.assertTrue(d.read(self.state / 'status.json')['reserveBlocked'])

    def test_test_signal_cannot_start_product(self):
        d.write(self.state / 'ready.json', {'runId': self.cfg['runId'], 'test': True, 'sha': 'fixture'})
        self.assertEqual(len(self.execute({})), 0)
        self.assertEqual(d.read(self.state / 'status.json')['status'], 'blocked')

    def test_cancel_wins_over_ready(self):
        (self.state / 'cancel').touch()
        self.assertEqual(len(self.execute({})), 0)
        self.assertEqual(d.read(self.state / 'status.json')['status'], 'cancelled')

    def test_gate_failure_blocks_dispatch(self):
        with patch.object(d, 'validate_release', side_effect=RuntimeError('gate')), \
             patch.object(d, 'execute_model') as model:
            d.watch(self.state)
            model.assert_not_called()
        self.assertEqual(d.read(self.state / 'status.json')['status'], 'blocked')

    def test_second_watcher_cannot_acquire_claim(self):
        self.execute({'failure': None, 'threadId': 'x'})
        with self.assertRaises(FileExistsError):
            d.watch(self.state)

    def test_authorized_reopening_preserves_thread_in_normal_phase(self):
        self.cfg.update(resumeThread='existing-thread', normalThreshold=99)
        d.write(self.state / 'config.json', self.cfg)
        calls = self.execute({'failure': None, 'threadId': 'existing-thread'})
        self.assertEqual(calls[0].kwargs.get('resume_id'), 'existing-thread')

    def test_exhaust_normal_does_not_honor_early_reserve_request(self):
        self.cfg['normalThreshold'] = 99
        d.write(self.state / 'config.json', self.cfg)
        d.write(self.state / 'continuation.json', {'status': 'needs_reserve'})
        calls = self.execute({'failure': None, 'threadId': 'x'},
                             dict(self.usage, ordinaryUsageAllowed=True,
                                  rateLimits={'primary': {'usedPercent': 98}}))
        self.assertFalse(any(c.kwargs.get('reserve') for c in calls))
        self.assertEqual(len(calls), 2)  # Continue once in normal, no reserve purchase/early switch.

    def test_exhaust_normal_service_denial_can_transition(self):
        self.cfg['normalThreshold'] = 99
        d.write(self.state / 'config.json', self.cfg)
        d.write(self.state / 'continuation.json', {'status': 'needs_reserve'})
        calls = self.execute({'failure': None, 'threadId': 'x'},
                             dict(self.usage, ordinaryUsageAllowed=False))
        self.assertTrue(calls[1].kwargs['reserve'])

    def test_owner_threshold_99_switches_without_waiting_for_hard_denial(self):
        self.cfg['normalThreshold'] = 99
        d.write(self.state / 'config.json', self.cfg)
        d.write(self.state / 'continuation.json', {'status': 'needs_reserve'})
        calls = self.execute({'failure': None, 'threadId': 'x'},
                             dict(self.usage, ordinaryUsageAllowed=True,
                                  rateLimits={'primary': {'usedPercent': 99}}))
        self.assertTrue(calls[1].kwargs['reserve'])

    def test_reopening_allows_reserve_until_99_and_no_old_time_cutoff(self):
        self.cfg['normalThreshold'] = 99
        d.write(self.state / 'config.json', self.cfg)
        self.usage['rateLimitsByLimitId']['reserve']['primary']['usedPercent'] = 98
        calls = self.execute({'failure': 'usage_limit', 'threadId': 'x'})
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0].args[1]['executionDeadline'], 0)

    def test_reopening_does_not_enter_reserve_already_at_99(self):
        self.cfg['normalThreshold'] = 99
        d.write(self.state / 'config.json', self.cfg)
        self.usage['rateLimitsByLimitId']['reserve']['primary']['usedPercent'] = 99
        calls = self.execute({'failure': 'usage_limit', 'threadId': 'x'})
        self.assertEqual(len(calls), 1)


if __name__ == '__main__':
    unittest.main()
