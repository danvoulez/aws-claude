import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function main(ctx) {
  const { sql, insertSpan, now } = ctx;
  
  console.log('Kernel policy_agent executing...');
  
  // Check for policy violations
  const { rows } = await sql`
    SELECT * FROM ledger.visible_timeline
    WHERE at > NOW() - INTERVAL '1 minute'
      AND entity_type NOT IN ('observation', 'policy_check')
    ORDER BY at DESC
    LIMIT 50
  `;
  
  let violations = 0;
  
  for (const span of rows) {
    // Check visibility policy
    if (!span.visibility || !['public', 'private', 'shared'].includes(span.visibility)) {
      await insertSpan({
        id: crypto.randomUUID(),
        seq: 0,
        entity_type: 'policy_check',
        who: 'kernel:policy_agent',
        did: 'detected_violation',
        this: 'policy',
        at: now(),
        status: 'violation',
        input: { 
          span_id: span.id, 
          violation: 'invalid_visibility',
          visibility: span.visibility
        },
        owner_id: span.owner_id,
        tenant_id: span.tenant_id,
        visibility: 'private',
        related_to: [span.id]
      });
      violations++;
    }
    
    // Check required fields
    if (!span.entity_type || !span.who || !span.this) {
      await insertSpan({
        id: crypto.randomUUID(),
        seq: 0,
        entity_type: 'policy_check',
        who: 'kernel:policy_agent',
        did: 'detected_violation',
        this: 'policy',
        at: now(),
        status: 'violation',
        input: { 
          span_id: span.id, 
          violation: 'missing_required_fields',
          missing: {
            entity_type: !span.entity_type,
            who: !span.who,
            this: !span.this
          }
        },
        owner_id: span.owner_id,
        tenant_id: span.tenant_id,
        visibility: 'private',
        related_to: [span.id]
      });
      violations++;
    }
    
    // Check ownership
    if (span.entity_type === 'function' && !span.owner_id) {
      await insertSpan({
        id: crypto.randomUUID(),
        seq: 0,
        entity_type: 'policy_check',
        who: 'kernel:policy_agent',
        did: 'detected_violation',
        this: 'policy',
        at: now(),
        status: 'violation',
        input: { 
          span_id: span.id, 
          violation: 'function_without_owner'
        },
        owner_id: 'system',
        tenant_id: span.tenant_id,
        visibility: 'private',
        related_to: [span.id]
      });
      violations++;
    }
  }
  
  return { success: true, kernel: 'policy_agent', checked: rows.length, violations };
}

export async function handler(event) {
  const ctx = {
    env: {
      APP_USER_ID: process.env.APP_USER_ID,
      APP_TENANT_ID: process.env.APP_TENANT_ID,
      SIGNING_KEY_HEX: process.env.SIGNING_KEY_HEX
    },
    sql: async (strings, ...vals) => {
      return withPg(async (client) => {
        const sqlQuery = createSql(client);
        return sqlQuery(strings, ...vals);
      });
    },
    insertSpan,
    signSpan,
    now,
    crypto: {
      blake3,
      ed25519: ed,
      hex,
      toU8,
      randomUUID: () => crypto.randomUUID()
    }
  };
  
  try {
    const result = await main(ctx);
    return {
      statusCode: 200,
      body: JSON.stringify(result)
    };
  } catch (error) {
    console.error('policy_agent error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
}
