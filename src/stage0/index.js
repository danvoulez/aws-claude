import { withPg, sql as createSql, insertSpan, signSpan, verifySpan, hex, toU8, now } from './db.js';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

// Fetch latest manifest
async function latestManifest() {
  return withPg(async (client) => {
    const sqlQuery = createSql(client);
    const { rows } = await sqlQuery`
      SELECT * FROM ledger.visible_timeline 
      WHERE entity_type='manifest' 
      ORDER BY "when" DESC LIMIT 1
    `;
    return rows[0] || { metadata: {} };
  });
}

// Fetch latest version of a function
async function fetchLatestFunction(id) {
  return withPg(async (client) => {
    const sqlQuery = createSql(client);
    const { rows } = await sqlQuery`
      SELECT * FROM ledger.visible_timeline
      WHERE id=${id} AND entity_type='function'
      ORDER BY "when" DESC, seq DESC LIMIT 1
    `;
    
    if (!rows[0]) {
      throw new Error(`Function ${id} not found`);
    }
    
    return rows[0];
  });
}

// Main handler
export async function handler(event) {
  console.log('Stage-0 invoked:', JSON.stringify(event, null, 2));
  
  try {
    // Extract boot function ID from event
    const BOOT_FUNCTION_ID = process.env.BOOT_FUNCTION_ID || 
                            event.boot_function_id || 
                            event.queryStringParameters?.boot_function_id ||
                            event.pathParameters?.function_id;
    
    if (!BOOT_FUNCTION_ID) {
      // If no boot function specified, treat as timeline query
      if (event.httpMethod === 'GET' && event.path?.includes('/timeline')) {
        return await handleTimelineQuery(event);
      }
      
      // If POST to /api/spans, handle span insertion
      if (event.httpMethod === 'POST' && event.path?.includes('/spans')) {
        return await handleSpanIngest(event);
      }
      
      throw new Error('BOOT_FUNCTION_ID required or use /api/timeline or /api/spans');
    }
    
    // Fetch and verify manifest
    const manifest = await latestManifest();
    const allowedIds = manifest.metadata?.allowed_boot_ids || [];
    
    if (!allowedIds.includes(BOOT_FUNCTION_ID)) {
      throw new Error(`Function ${BOOT_FUNCTION_ID} not in manifest allowlist`);
    }
    
    // Fetch function span
    const fnSpan = await fetchLatestFunction(BOOT_FUNCTION_ID);
    await verifySpan(fnSpan);
    
    console.log(`Executing function: ${fnSpan.name || BOOT_FUNCTION_ID}`);
    
    // Emit boot event
    const bootEvent = {
      id: crypto.randomUUID(),
      seq: 0,
      entity_type: 'boot_event',
      who: 'edge:stage0',
      did: 'booted',
      this: 'stage0',
      at: now(),
      status: 'complete',
      input: {
        boot_id: BOOT_FUNCTION_ID,
        event,
        env: {
          user: process.env.APP_USER_ID,
          tenant: process.env.APP_TENANT_ID
        }
      },
      owner_id: fnSpan.owner_id,
      tenant_id: fnSpan.tenant_id,
      visibility: fnSpan.visibility || 'private',
      related_to: [BOOT_FUNCTION_ID]
    };
    
    await insertSpan(bootEvent);
    
    // Build context for kernel
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
    
    // Execute function code
    const factory = new Function('ctx', `"use strict";\n${fnSpan.code}\n;return (typeof main !== 'undefined' ? main : globalThis.main);`);
    const main = factory(ctx);
    
    if (typeof main !== 'function') {
      throw new Error('Kernel must export a main function');
    }
    
    const result = await main(ctx);
    
    console.log('Execution complete');
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: true,
        function_id: BOOT_FUNCTION_ID,
        result
      })
    };
    
  } catch (error) {
    console.error('Stage-0 error:', error);
    
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: false,
        error: error.message,
        stack: error.stack
      })
    };
  }
}

// Handle timeline query
async function handleTimelineQuery(event) {
  const params = event.queryStringParameters || {};
  const limit = Math.min(parseInt(params.limit || '100'), 1000);
  const entityType = params.entity_type;
  const ownerId = params.owner_id;
  const tenantId = params.tenant_id;
  const since = params.since;
  const until = params.until;
  
  return withPg(async (client) => {
    const sqlQuery = createSql(client);
    
    let query = `SELECT * FROM ledger.visible_timeline WHERE 1=1`;
    const queryParams = [];
    let paramIndex = 1;
    
    if (entityType) {
      query += ` AND entity_type = $${paramIndex++}`;
      queryParams.push(entityType);
    }
    if (ownerId) {
      query += ` AND owner_id = $${paramIndex++}`;
      queryParams.push(ownerId);
    }
    if (tenantId) {
      query += ` AND tenant_id = $${paramIndex++}`;
      queryParams.push(tenantId);
    }
    if (since) {
      query += ` AND at >= $${paramIndex++}`;
      queryParams.push(since);
    }
    if (until) {
      query += ` AND at <= $${paramIndex++}`;
      queryParams.push(until);
    }
    
    query += ` ORDER BY at DESC LIMIT $${paramIndex}`;
    queryParams.push(limit);
    
    const result = await client.query(query, queryParams);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        spans: result.rows,
        count: result.rows.length,
        has_more: result.rows.length === limit
      })
    };
  });
}

// Handle span ingestion
async function handleSpanIngest(event) {
  const span = JSON.parse(event.body || '{}');
  
  // Set defaults
  span.id = span.id || crypto.randomUUID();
  span.seq = span.seq ?? 0;
  span.at = span.at || now();
  span.owner_id = span.owner_id || process.env.APP_USER_ID || 'anonymous';
  span.tenant_id = span.tenant_id || process.env.APP_TENANT_ID || null;
  span.visibility = span.visibility || 'private';
  span.is_deleted = false;
  
  // Validate required fields
  if (!span.entity_type || !span.who || !span.this) {
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: false,
        error: 'Missing required fields: entity_type, who, this'
      })
    };
  }
  
  try {
    const inserted = await insertSpan(span);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: true,
        span: inserted
      })
    };
  } catch (error) {
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
}
