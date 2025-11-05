import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function main(ctx) {
  const { sql, insertSpan, now } = ctx;
  
  console.log('Kernel request_worker executing...');
  
  // Process pending requests
  const { rows } = await sql`
    SELECT * FROM ledger.visible_timeline
    WHERE entity_type = 'request'
      AND status = 'pending'
    ORDER BY at ASC
    LIMIT 10
  `;
  
  for (const request of rows) {
    try {
      // Process the request based on type
      const requestType = request.input?.type || 'generic';
      
      let result;
      switch (requestType) {
        case 'query':
          result = await handleQuery(request, ctx);
          break;
        case 'mutation':
          result = await handleMutation(request, ctx);
          break;
        default:
          result = { processed: true, type: requestType };
      }
      
      // Record completion
      await insertSpan({
        id: request.id,
        seq: (request.seq || 0) + 1,
        entity_type: 'request_result',
        who: 'kernel:request_worker',
        did: 'processed',
        this: request.this || 'request',
        at: now(),
        status: 'complete',
        output: result,
        owner_id: request.owner_id,
        tenant_id: request.tenant_id,
        visibility: request.visibility || 'private',
        related_to: [request.id]
      });
      
      console.log(`Processed request ${request.id}`);
    } catch (error) {
      // Record error
      await insertSpan({
        id: request.id,
        seq: (request.seq || 0) + 1,
        entity_type: 'request_result',
        who: 'kernel:request_worker',
        did: 'failed',
        this: request.this || 'request',
        at: now(),
        status: 'error',
        error: {
          message: error.message,
          stack: error.stack
        },
        owner_id: request.owner_id,
        tenant_id: request.tenant_id,
        visibility: request.visibility || 'private',
        related_to: [request.id]
      });
      
      console.error(`Failed to process ${request.id}:`, error);
    }
  }
  
  return { success: true, kernel: 'request_worker', processed: rows.length };
}

async function handleQuery(request, ctx) {
  const { sql } = ctx;
  const query = request.input?.query;
  
  if (!query) {
    throw new Error('No query provided');
  }
  
  // WARNING: This executes raw SQL queries. In production, this should:
  // 1. Validate queries against an allowlist of safe queries
  // 2. Use parameterized queries with proper input sanitization
  // 3. Implement additional access controls and query validation
  // Current implementation is for demonstration purposes only
  
  const result = await sql`${query}`;
  return { rows: result.rows };
}

async function handleMutation(request, ctx) {
  const { insertSpan } = ctx;
  const span = request.input?.span;
  
  if (!span) {
    throw new Error('No span provided for mutation');
  }
  
  const inserted = await insertSpan(span);
  return { inserted };
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
    console.error('request_worker error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
}
