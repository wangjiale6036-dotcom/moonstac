#!/usr/bin/env node
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {collections_summary, landing_summary, page_summary, search_request} from './_build/js/release/build/bridge/bridge.js';

function options(args) {
  const result = {collections: [], ids: []};
  for (let i = 0; i < args.length; i++) {
    const key = args[i];
    if (!key.startsWith('--')) throw new Error(`Unexpected argument: ${key}`);
    const value = args[++i];
    if (value === undefined || value.startsWith('--')) throw new Error(`Missing value for ${key}`);
    if (key === '--collection') result.collections.push(value);
    else if (key === '--id') result.ids.push(value);
    else result[key.slice(2)] = value;
  }
  return result;
}

export function validateText(text) {
  const result = JSON.parse(page_summary(text));
  if (result.status !== 'ok') throw new Error(`Invalid STAC ItemCollection: ${result.message}`);
  return result;
}

export async function discover(url, fetchImpl = fetch) {
  const target = new URL(url);
  if (!['http:', 'https:'].includes(target.protocol)) throw new Error('URL must use HTTP or HTTPS');
  const response = await fetchImpl(target);
  if (!response.ok) throw new Error(`STAC API returned HTTP ${response.status} at ${target.href}`);
  const result = JSON.parse(landing_summary(await response.text()));
  if (result.status !== 'ok') throw new Error(`Invalid STAC landing page: ${result.message}`);
  for (const key of ['search', 'collections']) {
    if (result[key]) result[key] = new URL(result[key], target).href;
  }
  return result;
}

export async function listCollections(url, maxPages = 5, fetchImpl = fetch) {
  const start = new URL(url);
  if (!['http:', 'https:'].includes(start.protocol)) throw new Error('URL must use HTTP or HTTPS');
  if (!Number.isSafeInteger(maxPages) || maxPages < 1 || maxPages > 100) {
    throw new Error('--max-pages must be an integer from 1 to 100');
  }
  const seen = new Set();
  const collections = [];
  let next = start;
  let pages = 0;
  while (next && pages < maxPages) {
    if (!['http:', 'https:'].includes(next.protocol)) throw new Error('Pagination URL must use HTTP or HTTPS');
    if (seen.has(next.href)) throw new Error('Collection pagination cycle detected');
    seen.add(next.href);
    const response = await fetchImpl(next);
    if (!response.ok) throw new Error(`STAC API returned HTTP ${response.status} at ${next.href}`);
    const page = JSON.parse(collections_summary(await response.text()));
    if (page.status !== 'ok') throw new Error(`Invalid STAC Collections page: ${page.message}`);
    pages++;
    collections.push(...page.collections);
    next = page.next ? new URL(page.next, next) : null;
  }
  return {collections, pages, hasMore: next !== null};
}

function queryBody(opts) {
  const bbox = opts.bbox?.split(',').map(Number);
  if (bbox?.some(n => !Number.isFinite(n))) throw new Error('Invalid bbox number');
  const result = JSON.parse(search_request(JSON.stringify({
    bbox, collections: opts.collections, ids: opts.ids?.length ? opts.ids : undefined, datetime: opts.datetime,
    limit: opts.limit === undefined ? 10 : Number(opts.limit),
  })));
  if (result.status !== 'ok') throw new Error(`Invalid search: ${result.message}`);
  return JSON.parse(result.body);
}

export async function search(opts, fetchImpl = fetch) {
  const method = (opts.method ?? 'GET').toUpperCase();
  if (method !== 'GET' && method !== 'POST') throw new Error('Method must be GET or POST');
  const maxPages = opts['max-pages'] === undefined ? 5 : Number(opts['max-pages']);
  if (!Number.isSafeInteger(maxPages) || maxPages < 1 || maxPages > 100) {
    throw new Error('--max-pages must be an integer from 1 to 100');
  }
  const url = new URL(opts.url);
  if (!['http:', 'https:'].includes(url.protocol)) throw new Error('URL must use HTTP or HTTPS');
  const body = queryBody(opts);
  if (method === 'GET') {
    if (body.bbox) url.searchParams.set('bbox', body.bbox.join(','));
    url.searchParams.set('limit', String(body.limit));
    if (body.datetime) url.searchParams.set('datetime', body.datetime);
    if (body.collections) url.searchParams.set('collections', body.collections.join(','));
    if (body.ids) url.searchParams.set('ids', body.ids.join(','));
  }
  let next = {href: url.href, method, body: method === 'POST' ? body : null, headers: null, merge: false};
  const seen = new Set();
  const items = [];
  let pages = 0;
  let previousBody = null;
  let previousHeaders = {};
  while (next && pages < maxPages) {
    const pageUrl = new URL(next.href, url);
    if (!['http:', 'https:'].includes(pageUrl.protocol)) throw new Error('Pagination URL must use HTTP or HTTPS');
    const requestMethod = next.method.toUpperCase();
    const currentBody = requestMethod === 'POST'
      ? (next.merge ? {...previousBody, ...next.body} : next.body) : null;
    const requestBody = currentBody === null ? undefined : JSON.stringify(currentBody);
    const headers = next.merge ? {...previousHeaders, ...next.headers} : {...next.headers};
    if (requestBody && !Object.keys(headers).some(key => key.toLowerCase() === 'content-type')) {
      headers['content-type'] = 'application/json';
    }
    const marker = `${requestMethod} ${pageUrl.href} ${requestBody ?? ''} ${JSON.stringify(headers)}`;
    if (seen.has(marker)) throw new Error('Pagination cycle detected');
    seen.add(marker);
    const response = await fetchImpl(pageUrl, {
      method: requestMethod,
      headers,
      body: requestBody,
    });
    if (!response.ok) throw new Error(`STAC API returned HTTP ${response.status} at ${pageUrl.href}`);
    const page = validateText(await response.text());
    pages++;
    items.push(...page.items);
    previousBody = currentBody;
    previousHeaders = headers;
    next = page.next && {
      href: new URL(page.next.href, pageUrl).href,
      method: page.next.method,
      body: page.next.body,
      headers: page.next.headers,
      merge: page.next.merge,
    };
  }
  return {items, pages, hasMore: next !== null};
}

export async function main(args) {
  const [command, ...rest] = args;
  if (command === 'validate') {
    if (rest.length !== 1) throw new Error('Usage: node cli.mjs validate <item-collection.json>');
    const page = validateText(await readFile(rest[0], 'utf8'));
    console.log(JSON.stringify({valid: true, items: page.items.length, hasNext: page.next !== null}));
  } else if (command === 'discover') {
    const opts = options(rest);
    if (!opts.url) throw new Error('Usage: node cli.mjs discover --url <stac-api-root>');
    console.log(JSON.stringify(await discover(opts.url), null, 2));
  } else if (command === 'collections') {
    const opts = options(rest);
    if (!opts.url) throw new Error('Usage: node cli.mjs collections --url <collections-endpoint> [--max-pages N]');
    const maxPages = opts['max-pages'] === undefined ? 5 : Number(opts['max-pages']);
    console.log(JSON.stringify(await listCollections(opts.url, maxPages), null, 2));
  } else if (command === 'search') {
    const opts = options(rest);
    if (!opts.url) throw new Error('Usage: node cli.mjs search --url <search-endpoint> [--bbox west,south,east,north] [--datetime ...] [--collection ...] [--id ...] [--limit N] [--method GET|POST] [--max-pages N]');
    console.log(JSON.stringify(await search(opts), null, 2));
  } else {
    throw new Error('Usage: node cli.mjs <discover|collections|validate|search> ...');
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv.slice(2)).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
