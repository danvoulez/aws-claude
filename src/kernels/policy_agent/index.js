import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function handler(event) {
  console.log('policy_agent kernel invoked:', JSON.stringify(event, null, 2));
  
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
        kernel: 'policy_agent',
        result
      })
    };
  } catch (error) {
    console.error('policy_agent error:', error);
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
  console.log('policy_agent kernel executing...');
  
  // Fetch manifest to get policy configuration
  const manifest = await ctx.sql`
    SELECT metadata
    FROM ledger.visible_timeline
    WHERE entity_type = 'manifest'
    ORDER BY at DESC
    LIMIT 1
  `;
  
  const policy = manifest.rows[0]?.metadata?.policy || { slow_ms: 5000 };
  
  // Check for slow executions
  const slowExecutions = await ctx.sql`
    SELECT id, entity_type, who, duration_ms, at
    FROM ledger.visible_timeline
    WHERE entity_type = 'execution' 
      AND duration_ms > ${policy.slow_ms}
      AND at > NOW() - INTERVAL '1 hour'
    ORDER BY duration_ms DESC
    LIMIT 10
  `;
  
  // Log policy check
  const policySpan = {
    id: ctx.crypto.randomUUID(),
    seq: 0,
    entity_type: 'policy_check',
    who: 'kernel:policy_agent',
    did: 'checked',
    this: 'slow_executions',
    at: ctx.now(),
    status: 'complete',
    output: {
      slow_threshold_ms: policy.slow_ms,
      violations_found: slowExecutions.rows.length,
      violations: slowExecutions.rows
    },
    owner_id: ctx.env.APP_USER_ID,
    tenant_id: ctx.env.APP_TENANT_ID,
    visibility: 'private'
  };
  
  await ctx.insertSpan(policySpan);
  
  return {
    success: true,
    policy_threshold_ms: policy.slow_ms,
    violations_count: slowExecutions.rows.length,
    violations: slowExecutions.rows,
    span_id: policySpan.id
  };
}
