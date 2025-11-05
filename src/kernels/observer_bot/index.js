import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function handler(event) {
  console.log('observer_bot kernel invoked:', JSON.stringify(event, null, 2));
  
  try {
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
    
    const result = await main(ctx, event);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        success: true,
        kernel: 'observer_bot',
        result
      })
    };
  } catch (error) {
    console.error('observer_bot error:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
}

export async function main(ctx, event) {
  console.log('observer_bot kernel executing...');
  
  // Query recent activity
  const result = await ctx.sql`
    SELECT entity_type, COUNT(*) as count, MAX(at) as latest
    FROM ledger.visible_timeline
    WHERE at > NOW() - INTERVAL '1 hour'
    GROUP BY entity_type
    ORDER BY count DESC
    LIMIT 10
  `;
  
  // Log observation to ledger
  const observationSpan = {
    id: ctx.crypto.randomUUID(),
    seq: 0,
    entity_type: 'observation',
    who: 'kernel:observer_bot',
    did: 'observed',
    this: 'timeline_activity',
    at: ctx.now(),
    status: 'complete',
    output: {
      activity_summary: result.rows,
      observation_time: ctx.now()
    },
    owner_id: ctx.env.APP_USER_ID,
    tenant_id: ctx.env.APP_TENANT_ID,
    visibility: 'private'
  };
  
  await ctx.insertSpan(observationSpan);
  
  return {
    success: true,
    observations: result.rows,
    span_id: observationSpan.id
  };
}
