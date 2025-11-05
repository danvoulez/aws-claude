import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function handler(event) {
  console.log('run_code kernel invoked:', JSON.stringify(event, null, 2));
  
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
        kernel: 'run_code',
        result
      })
    };
  } catch (error) {
    console.error('run_code error:', error);
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
  console.log('run_code kernel executing...');
  
  // Extract code to execute from event
  const code = event.code || event.body?.code;
  
  if (!code) {
    throw new Error('No code provided to execute');
  }
  
  // Execute code in sandboxed context
  const startTime = Date.now();
  let output, error;
  
  try {
    const factory = new Function('ctx', `"use strict";\n${code}\n;return (typeof main !== 'undefined' ? main : globalThis.main);`);
    const userMain = factory(ctx);
    
    if (typeof userMain === 'function') {
      output = await userMain(ctx);
    } else {
      output = userMain;
    }
  } catch (err) {
    error = {
      message: err.message,
      stack: err.stack
    };
  }
  
  const duration_ms = Date.now() - startTime;
  
  // Log execution to ledger
  const executionSpan = {
    id: ctx.crypto.randomUUID(),
    seq: 0,
    entity_type: 'execution',
    who: ctx.env.APP_USER_ID || 'kernel:run_code',
    did: error ? 'failed' : 'executed',
    this: 'run_code',
    at: ctx.now(),
    status: error ? 'error' : 'complete',
    input: { code: code.substring(0, 1000) }, // Truncate for storage
    output: error ? null : output,
    error: error,
    duration_ms,
    owner_id: ctx.env.APP_USER_ID,
    tenant_id: ctx.env.APP_TENANT_ID,
    visibility: 'private'
  };
  
  await ctx.insertSpan(executionSpan);
  
  return {
    success: !error,
    output,
    error,
    duration_ms,
    span_id: executionSpan.id
  };
}
