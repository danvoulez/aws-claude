import { withPg, sql as createSql, insertSpan, signSpan, hex, toU8, now } from '../db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

export async function main(ctx) {
  const { sql, insertSpan, now } = ctx;
  
  console.log('Kernel provider_exec executing...');
  
  // Execute provider-specific operations (API calls, external integrations)
  const { rows } = await sql`
    SELECT * FROM ledger.visible_timeline
    WHERE entity_type = 'provider_request'
      AND status = 'pending'
    ORDER BY at ASC
    LIMIT 5
  `;
  
  for (const request of rows) {
    try {
      const provider = request.input?.provider;
      const operation = request.input?.operation;
      
      if (!provider) {
        throw new Error('No provider specified');
      }
      
      let result;
      
      // Handle different providers
      switch (provider) {
        case 'openai':
          result = await handleOpenAI(request, ctx);
          break;
        case 'anthropic':
          result = await handleAnthropic(request, ctx);
          break;
        case 'http':
          result = await handleHTTP(request, ctx);
          break;
        default:
          result = { message: `Provider ${provider} not implemented` };
      }
      
      // Record completion
      await insertSpan({
        id: request.id,
        seq: (request.seq || 0) + 1,
        entity_type: 'provider_result',
        who: 'kernel:provider_exec',
        did: 'executed',
        this: request.this || 'provider',
        at: now(),
        status: 'complete',
        output: result,
        owner_id: request.owner_id,
        tenant_id: request.tenant_id,
        visibility: request.visibility || 'private',
        related_to: [request.id]
      });
      
      console.log(`Executed provider request ${request.id} for ${provider}`);
    } catch (error) {
      // Record error
      await insertSpan({
        id: request.id,
        seq: (request.seq || 0) + 1,
        entity_type: 'provider_result',
        who: 'kernel:provider_exec',
        did: 'failed',
        this: request.this || 'provider',
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
      
      console.error(`Failed to execute provider ${request.id}:`, error);
    }
  }
  
  return { success: true, kernel: 'provider_exec', processed: rows.length };
}

async function handleOpenAI(request, ctx) {
  // Placeholder for OpenAI integration
  const model = request.input?.model || 'gpt-4';
  const messages = request.input?.messages || [];
  
  return {
    provider: 'openai',
    model,
    message: 'OpenAI integration requires API key configuration',
    input: { messages }
  };
}

async function handleAnthropic(request, ctx) {
  // Placeholder for Anthropic integration
  const model = request.input?.model || 'claude-3-sonnet';
  const messages = request.input?.messages || [];
  
  return {
    provider: 'anthropic',
    model,
    message: 'Anthropic integration requires API key configuration',
    input: { messages }
  };
}

async function handleHTTP(request, ctx) {
  // Placeholder for HTTP requests
  const url = request.input?.url;
  const method = request.input?.method || 'GET';
  
  if (!url) {
    throw new Error('URL required for HTTP provider');
  }
  
  return {
    provider: 'http',
    url,
    method,
    message: 'HTTP provider ready (implementation pending)'
  };
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
    console.error('provider_exec error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
}
