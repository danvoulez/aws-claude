import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function handler(event) {
  console.log('provider_exec kernel invoked:', JSON.stringify(event, null, 2));
  
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
        kernel: 'provider_exec',
        result
      })
    };
  } catch (error) {
    console.error('provider_exec error:', error);
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
  console.log('provider_exec kernel executing...');
  
  // Extract provider action from event
  const action = event.action || 'status';
  const provider = event.provider || 'default';
  
  // Log provider execution
  const providerSpan = {
    id: ctx.crypto.randomUUID(),
    seq: 0,
    entity_type: 'provider_action',
    who: 'kernel:provider_exec',
    did: action,
    this: provider,
    at: ctx.now(),
    status: 'complete',
    input: {
      action,
      provider,
      event_data: event
    },
    output: {
      action_performed: action,
      provider_name: provider,
      executed_at: ctx.now()
    },
    owner_id: ctx.env.APP_USER_ID,
    tenant_id: ctx.env.APP_TENANT_ID,
    visibility: 'private'
  };
  
  await ctx.insertSpan(providerSpan);
  
  return {
    success: true,
    action,
    provider,
    span_id: providerSpan.id
  };
}
