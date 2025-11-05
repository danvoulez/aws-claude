import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function main(ctx) {
  // Use ctx.sql, ctx.insertSpan, etc.
  const { sql, insertSpan, now, crypto } = ctx;
  
  console.log('Kernel run_code executing...');
  
  // Fetch pending code execution requests
  const { rows } = await sql`
    SELECT * FROM ledger.visible_timeline
    WHERE entity_type = 'code_request'
      AND status = 'pending'
    ORDER BY at ASC
    LIMIT 10
  `;
  
  for (const request of rows) {
    try {
      // Execute the code
      const code = request.code || request.input?.code;
      if (!code) {
        throw new Error('No code provided in request');
      }
      
      // Create execution context
      const execCtx = { ...ctx };
      const factory = new Function('ctx', `"use strict";\n${code}\n;return (typeof main !== 'undefined' ? main : globalThis.main);`);
      const fn = factory(execCtx);
      
      const startTime = Date.now();
      const result = await fn(execCtx);
      const duration = Date.now() - startTime;
      
      // Record completion
      await insertSpan({
        id: request.id,
        seq: (request.seq || 0) + 1,
        entity_type: 'code_execution',
        who: 'kernel:run_code',
        did: 'executed',
        this: request.this || 'code',
        at: now(),
        status: 'complete',
        output: { result },
        duration_ms: duration,
        owner_id: request.owner_id,
        tenant_id: request.tenant_id,
        visibility: request.visibility || 'private',
        related_to: [request.id]
      });
      
      console.log(`Executed code request ${request.id} in ${duration}ms`);
    } catch (error) {
      // Record error
      await insertSpan({
        id: request.id,
        seq: (request.seq || 0) + 1,
        entity_type: 'code_execution',
        who: 'kernel:run_code',
        did: 'failed',
        this: request.this || 'code',
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
      
      console.error(`Failed to execute ${request.id}:`, error);
    }
  }
  
  return { success: true, kernel: 'run_code', processed: rows.length };
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
    console.error('run_code error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
}
