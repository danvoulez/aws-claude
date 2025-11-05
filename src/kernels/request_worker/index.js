import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function handler(event) {
  console.log('request_worker kernel invoked:', JSON.stringify(event, null, 2));
  
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
        kernel: 'request_worker',
        result
      })
    };
  } catch (error) {
    console.error('request_worker error:', error);
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
  console.log('request_worker kernel executing...');
  
  // Query pending requests
  const result = await ctx.sql`
    SELECT id, entity_type, who, status, at
    FROM ledger.visible_timeline
    WHERE entity_type = 'request' AND status = 'pending'
    ORDER BY at ASC
    LIMIT 10
  `;
  
  const processed = [];
  
  // Process each pending request
  for (const request of result.rows) {
    // Log processing action
    const processingSpan = {
      id: ctx.crypto.randomUUID(),
      seq: 0,
      entity_type: 'processing',
      who: 'kernel:request_worker',
      did: 'processed',
      this: 'request',
      at: ctx.now(),
      status: 'complete',
      parent_id: request.id,
      related_to: [request.id],
      output: {
        request_id: request.id,
        processed_at: ctx.now()
      },
      owner_id: ctx.env.APP_USER_ID,
      tenant_id: ctx.env.APP_TENANT_ID,
      visibility: 'private'
    };
    
    await ctx.insertSpan(processingSpan);
    processed.push(request.id);
  }
  
  return {
    success: true,
    processed_count: processed.length,
    processed_ids: processed
  };
}
