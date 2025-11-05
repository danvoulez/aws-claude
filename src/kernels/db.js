import pg from 'pg';
import { blake3 } from '@noble/hashes/blake3';
import * as ed from '@noble/ed25519';

const { Client } = pg;

export const hex = (u8) => Array.from(u8).map(b => b.toString(16).padStart(2, '0')).join('');
export const toU8 = (hexStr) => Uint8Array.from(hexStr.match(/.{1,2}/g).map(x => parseInt(x, 16)));
export const now = () => new Date().toISOString();

export async function withPg(fn) {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
  });
  
  try {
    await client.connect();
    await client.query('SET app.user_id = $1', [process.env.APP_USER_ID || 'edge:kernel']);
    if (process.env.APP_TENANT_ID) {
      await client.query('SET app.tenant_id = $1', [process.env.APP_TENANT_ID]);
    }
    return await fn(client);
  } finally {
    await client.end();
  }
}

export function sql(client) {
  return async function sqlQuery(strings, ...values) {
    const queryText = strings.reduce((prev, curr, i) => {
      return prev + (i > 0 ? `$${i}` : '') + curr;
    }, '');
    return client.query(queryText, values);
  };
}

export async function insertSpan(span) {
  return withPg(async (client) => {
    if (process.env.SIGNING_KEY_HEX && !span.signature) {
      await signSpan(span);
    }
    
    const cols = Object.keys(span).filter(k => span[k] !== undefined);
    const vals = cols.map(k => span[k]);
    const placeholders = cols.map((_, i) => `$${i + 1}`).join(',');
    
    const query = `
      INSERT INTO ledger.universal_registry (${cols.map(c => `"${c}"`).join(',')})
      VALUES (${placeholders})
      RETURNING *
    `;
    
    const result = await client.query(query, vals);
    return result.rows[0];
  });
}

export async function signSpan(span) {
  const clone = structuredClone(span);
  delete clone.signature;
  delete clone.curr_hash;
  
  const canonical = JSON.stringify(clone, Object.keys(clone).sort());
  const msg = new TextEncoder().encode(canonical);
  const h = hex(blake3(msg));
  span.curr_hash = h;
  
  if (process.env.SIGNING_KEY_HEX) {
    const privKey = toU8(process.env.SIGNING_KEY_HEX);
    const pubKey = await ed.getPublicKey(privKey);
    const signature = await ed.sign(toU8(h), privKey);
    
    span.signature = hex(signature);
    span.public_key = hex(pubKey);
  }
}

export async function verifySpan(span) {
  const clone = structuredClone(span);
  delete clone.signature;
  delete clone.curr_hash;
  
  const canonical = JSON.stringify(clone, Object.keys(clone).sort());
  const msg = new TextEncoder().encode(canonical);
  const computedHash = hex(blake3(msg));
  
  if (span.curr_hash && span.curr_hash !== computedHash) {
    throw new Error(`Hash mismatch`);
  }
  
  if (span.signature && span.public_key) {
    const sigValid = await ed.verify(toU8(span.signature), toU8(computedHash), toU8(span.public_key));
    if (!sigValid) throw new Error('Invalid signature');
  }
}
