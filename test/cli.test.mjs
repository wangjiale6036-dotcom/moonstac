import test from 'node:test';
import assert from 'node:assert/strict';
import {search, validateText} from '../cli.mjs';

function item(id) {
  return {
    stac_version: '1.0.0', type: 'Feature', id,
    geometry: null, properties: {datetime: '2026-11-01T00:00:00Z'},
    links: [], assets: {visual: {href: `${id}.tif`}},
  };
}

function page(id, next = null) {
  return JSON.stringify({type: 'FeatureCollection', features: [item(id)], links: next ? [next] : []});
}

test('MoonBit validates and extracts an ItemCollection', () => {
  const parsed = validateText(page('scene-1', {rel: 'next', href: '?page=2'}));
  assert.equal(parsed.items[0].assets[0].href, 'scene-1.tif');
  assert.equal(parsed.next.method, 'GET');
  assert.throws(() => validateText('{"type":"FeatureCollection","features":[{"id":"bad"}]}'), /Invalid STAC/);
});

test('GET search follows relative next link', async () => {
  const seen = [];
  const transport = async (url, request) => {
    seen.push({url, request});
    return {ok: true, text: async () => url.searchParams.has('page')
      ? page('scene-2') : page('scene-1', {rel: 'next', href: '?page=2'})};
  };
  const result = await search({url: 'https://example.com/search', bbox: '120,30,121,31', collections: ['sentinel-2-l2a'], 'max-pages': '3'}, transport);
  assert.deepEqual(result.items.map(x => x.id), ['scene-1', 'scene-2']);
  assert.equal(result.pages, 2);
  assert.equal(result.hasMore, false);
  assert.equal(seen[0].url.searchParams.get('collections'), 'sentinel-2-l2a');
  assert.equal(seen[0].url.searchParams.get('bbox'), '120,30,121,31');
  assert.equal(seen[1].request.method, 'GET');
});

test('POST search follows a POST next link body', async () => {
  const seen = [];
  const transport = async (_url, request) => {
    seen.push({method: request.method, body: JSON.parse(request.body)});
    return {ok: true, text: async () => seen.length === 1 ? page('scene-1', {
      rel: 'next', href: '/search', method: 'POST', body: {token: 'second-page'},
    }) : page('scene-2')};
  };
  const result = await search({url: 'https://example.com/search', bbox: '120,30,121,31', method: 'POST'}, transport);
  assert.equal(result.items.length, 2);
  assert.equal(seen[0].body.limit, 10);
  assert.deepEqual(seen[1], {method: 'POST', body: {token: 'second-page'}});
});

test('POST pagination merges body and headers when requested', async () => {
  const seen = [];
  const transport = async (_url, request) => {
    seen.push({body: JSON.parse(request.body), headers: request.headers});
    return {ok: true, text: async () => seen.length === 1 ? page('one', {
      rel: 'next', href: '/search', method: 'POST', merge: true,
      body: {token: 'page-2'}, headers: {'x-page-token': 'page-2'},
    }) : page('two')};
  };
  const result = await search({url: 'https://example.com/search', bbox: '120,30,121,31', method: 'POST'}, transport);
  assert.deepEqual(result.items.map(x => x.id), ['one', 'two']);
  assert.deepEqual(seen[1].body, {...seen[0].body, token: 'page-2'});
  assert.equal(seen[1].headers['x-page-token'], 'page-2');
});

test('rejects invalid query and pagination cycle', async () => {
  await assert.rejects(() => search({url: 'https://example.com/search', bbox: '181,0,182,1'}), /Invalid search/);
  const repeating = async () => ({ok: true, text: async () => page('repeat', {rel: 'next', href: '/search?bbox=120%2C30%2C121%2C31&limit=10'})});
  await assert.rejects(() => search({url: 'https://example.com/search', bbox: '120,30,121,31'}, repeating), /Pagination cycle/);
});
