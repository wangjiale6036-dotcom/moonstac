import test from 'node:test';
import assert from 'node:assert/strict';
import {assetManifest, discover, listCollections, search, validateText} from '../cli.mjs';

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

test('discover resolves relative search and collections links', async () => {
  const landing = JSON.stringify({
    stac_version: '1.0.0', type: 'Catalog', id: 'demo', description: 'Demo catalog',
    links: [{rel: 'search', href: './search'}, {rel: 'data', href: './collections'}],
    conformsTo: ['https://api.stacspec.org/v1.0.0/item-search'],
  });
  const transport = async () => ({ok: true, text: async () => landing});
  const result = await discover('https://example.com/v1/', transport);
  assert.equal(result.search, 'https://example.com/v1/search');
  assert.equal(result.collections, 'https://example.com/v1/collections');
  assert.equal(result.conformsTo.length, 1);
});

test('lists STAC Collections across pages', async () => {
  const collection = id => ({
    stac_version: '1.0.0', type: 'Collection', id, description: `${id} data`,
    license: 'CC-BY-4.0', links: [],
    extent: {spatial: {bbox: [[-180, -90, 180, 90]]}, temporal: {interval: [[null, null]]}},
  });
  const seen = [];
  const transport = async url => {
    seen.push(url.href);
    return {ok: true, text: async () => JSON.stringify({
      collections: [collection(seen.length === 1 ? 'a' : 'b')],
      links: seen.length === 1 ? [{rel: 'next', href: '?page=2'}] : [],
    })};
  };
  const result = await listCollections('https://example.com/collections', 3, transport);
  assert.deepEqual(result.collections.map(x => x.id), ['a', 'b']);
  assert.equal(result.pages, 2);
  assert.equal(result.hasMore, false);
  assert.equal(seen[1], 'https://example.com/collections?page=2');
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

test('searches by item ID without a bounding box', async () => {
  let requestUrl;
  const transport = async url => {
    requestUrl = url;
    return {ok: true, text: async () => page('scene-1')};
  };
  const result = await search({url: 'https://example.com/search', ids: ['scene-1']}, transport);
  assert.equal(result.items[0].id, 'scene-1');
  assert.equal(requestUrl.searchParams.get('ids'), 'scene-1');
  assert.equal(requestUrl.searchParams.has('bbox'), false);
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

test('POST search builds CQL2 JSON filter in MoonBit', async () => {
  let sent;
  const transport = async (_url, request) => {
    sent = JSON.parse(request.body);
    return {ok: true, text: async () => page('scene-1')};
  };
  const filter = {op: '<=', args: [{property: 'eo:cloud_cover'}, 20]};
  await search({url: 'https://example.com/search', bbox: '120,30,121,31', method: 'POST', filter}, transport);
  assert.deepEqual(sent.filter, filter);
  assert.equal(sent['filter-lang'], 'cql2-json');
  await assert.rejects(() => search({url: 'https://example.com/search', filter}), /requires --method POST/);
  await assert.rejects(() => search({url: 'https://example.com/search', method: 'POST', filter: {op: 'eval', args: []}}), /unsupported CQL2 operator/);
});

test('rejects invalid query and pagination cycle', async () => {
  await assert.rejects(() => search({url: 'https://example.com/search', bbox: '181,0,182,1'}), /Invalid search/);
  await assert.rejects(() => search({url: 'https://example.com/search', limit: '1.5'}), /Invalid search/);
  const repeating = async () => ({ok: true, text: async () => page('repeat', {rel: 'next', href: '/search?bbox=120%2C30%2C121%2C31&limit=10'})});
  await assert.rejects(() => search({url: 'https://example.com/search', bbox: '120,30,121,31'}, repeating), /Pagination cycle/);
  const external = async () => ({ok: true, text: async () => page('one', {rel: 'next', href: 'https://other.example/search'})});
  await assert.rejects(() => search({url: 'https://example.com/search', bbox: '120,30,121,31'}, external), /Cross-origin pagination blocked/);
});

test('POST intersects search accepts GeoJSON and rejects a simultaneous bbox', async () => {
  const intersects = {type: 'Polygon', coordinates: [[[120, 30], [121, 30], [121, 31], [120, 30]]]};
  let sent;
  const transport = async (_url, request) => {
    sent = JSON.parse(request.body);
    return {ok: true, text: async () => page('inside')};
  };
  await search({url: 'https://example.com/search', method: 'POST', intersects}, transport);
  assert.deepEqual(sent.intersects, intersects);
  await assert.rejects(() => search({url: 'https://example.com/search', intersects}, transport), /requires --method POST/);
  await assert.rejects(() => search({url: 'https://example.com/search', method: 'POST', intersects, bbox: '120,30,121,31'}, transport), /mutually exclusive/);
  await assert.rejects(() => search({url: 'https://example.com/search', method: 'POST', intersects: {type: 'Polygon', coordinates: [[[120,30],[121,30],[121,31],[120,31]]]}}, transport), /linear ring is not closed/);
});

test('asset manifest resolves links against Item self and filters role', async () => {
  const feature = item('scene-1');
  feature.links = [{rel: 'self', href: '../items/scene-1.json'}];
  feature.assets = {
    visual: {href: 'preview.png', type: 'image/png', title: 'Preview', roles: ['overview']},
    data: {href: '../raster/data.tif', type: 'image/tiff', roles: ['data']},
  };
  const transport = async () => ({ok: true, text: async () => JSON.stringify({type: 'FeatureCollection', features: [feature], links: []})});
  const result = await search({url: 'https://example.com/api/search'}, transport);
  const manifest = assetManifest(result, {roles: ['data']});
  assert.equal(manifest.assets.length, 1);
  assert.equal(manifest.assets[0].key, 'data');
  assert.equal(manifest.assets[0].href, 'https://example.com/raster/data.tif');
  assert.equal(manifest.assets[0].type, 'image/tiff');
  assert.equal(manifest.pages, 1);
  assert.equal(assetManifest(result, {assets: ['visual']}).assets[0].href, 'https://example.com/items/preview.png');
});
