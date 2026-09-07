import unittest
from sync_reset_credits import credit_snapshot


class CreditSyncTests(unittest.TestCase):
    def test_extracts_only_display_metadata(self):
        result = credit_snapshot({'accountId': 'private', 'rateLimitResetCredits': {
            'availableCount': 1, 'credits': [
                {'id': 'private-credit', 'status': 'available', 'expiresAt': 1800000000},
                {'status': 'consumed', 'expiresAt': 1700000000}]}})
        self.assertEqual(result['availableCount'], 1)
        self.assertEqual(len(result['expirations']), 1)
        self.assertNotIn('private', str(result))

    def test_missing_metadata_is_not_zero(self):
        with self.assertRaises(ValueError):
            credit_snapshot({})

    def test_older_cli_can_provide_count_without_expiry(self):
        result = credit_snapshot({'rateLimitResetCredits': {'availableCount': 2}})
        self.assertEqual(result['availableCount'], 2)
        self.assertEqual(result['expirations'], [])


if __name__ == '__main__':
    unittest.main()
