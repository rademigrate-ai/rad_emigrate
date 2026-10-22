// Synthetic transport fixtures only; no immigration claims.
const fixtureId = 'c1111111-1111-4111-8111-111111111111';

Map<String, dynamic> contractMeta({String locale = 'en'}) => {
  'request_id': fixtureId,
  'contract_version': '1',
  'server_time': '2026-10-21T00:00:00Z',
  'requested_locale': locale,
  'resolved_locale': locale,
  'fallback_used': false,
};

Map<String, dynamic> validAiEnvelope() => {
  'data': {
    'reply': 'SYNTHETIC no immigration claim',
    'request_id': fixtureId,
    'session_id': null,
    'evidence_state': 'unavailable',
    'uncertain': true,
    'refused': false,
    'truncated': false,
    'citations': [],
    'suggested_actions': [],
    'tool_outcomes': [],
    'quota': {'remaining': 1, 'reset_at': null},
  },
  'meta': contractMeta(),
};
