import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function main(ctx) {
  const { sql, insertSpan, now } = ctx;
  
  console.log('Kernel observer_bot executing...');
  
  // Check for anomalies or policy violations
  const { rows } = await sql`
    SELECT * FROM ledger.visible_timeline
    WHERE at > NOW() - INTERVAL '30 seconds'
    ORDER BY at DESC
    LIMIT 100
  `;
  
  let anomalies = 0;
  
  for (const span of rows) {
    // Check for unsigned spans that should be signed
    if (span.entity_type === 'function' && !span.signature) {
      await insertSpan({
        id: ctx.crypto.randomUUID(),
        seq: 0,
        entity_type: 'observation',
        who: 'kernel:observer_bot',
        did: 'detected_unsigned',
        this: 'anomaly',
        at: now(),
        status: 'alert',
        input: { span_id: span.id, issue: 'unsigned_function' },
        owner_id: span.owner_id,
        tenant_id: span.tenant_id,
        visibility: 'private',
        related_to: [span.id]
      });
      anomalies++;
    }
    
    // Check for failed operations
    if (span.status === 'error' || span.status === 'failed') {
      await insertSpan({
        id: ctx.crypto.randomUUID(),
        seq: 0,
        entity_type: 'observation',
        who: 'kernel:observer_bot',
        did: 'detected_failure',
        this: 'anomaly',
        at: now(),
        status: 'alert',
        input: { span_id: span.id, issue: 'operation_failed', error: span.error },
        owner_id: span.owner_id,
        tenant_id: span.tenant_id,
        visibility: 'private',
        related_to: [span.id]
      });
      anomalies++;
    }
  }
  
  return { success: true, kernel: 'observer_bot', checked: rows.length, anomalies };
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
    console.error('observer_bot error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
}
