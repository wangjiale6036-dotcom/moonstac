#!/usr/bin/env node
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {assetManifest, discover, listCollections, search} from '../cli.mjs';

const earthRoot = 'https://earth-search.aws.element84.com/v1/';
const pcRoot = 'https://planetarycomputer.microsoft.com/api/stac/v1/';
const bbox = '120,30,121,31';
const collection = 'sentinel-2-l2a';
const geometry = JSON.parse(await readFile(new URL('../test-fixtures/search-area.geojson', import.meta.url), 'utf8'));
const filter = JSON.parse(await readFile(new URL('../test-fixtures/cloud-cover-filter.json', import.meta.url), 'utf8'));

const landing = await discover(earthRoot);
assert.equal(landing.search, new URL('search', earthRoot).href);
assert.equal(landing.collections, new URL('collections', earthRoot).href);
const collections = await listCollections(landing.collections, 2);
assert.ok(collections.collections.some(entry => entry.id === collection));

const base = {url: landing.search, bbox, collections: [collection], limit: 1, 'max-pages': 2};
const get = await search({...base, method: 'GET'});
const post = await search({...base, method: 'POST'});
assert.ok(get.items.length > 0);
assert.ok(post.items.length > 0);

const area = await search({url: landing.search, method: 'POST', intersects: geometry,
  collections: [collection], limit: 1, 'max-pages': 1});
assert.ok(area.items.length > 0);
const assets = assetManifest(area, {roles: ['data']});
assert.ok(assets.assets.length > 0);
assert.ok(assets.assets.some(asset => new URL(asset.href).protocol === 'https:'));

const earthFilter = await search({url: landing.search, method: 'POST', bbox,
  collections: [collection], filter, queryFallback: true, limit: 10, 'max-pages': 5});
assert.ok(earthFilter.items.length > 0);
assert.ok(earthFilter.items.every(item => item.properties['eo:cloud_cover'] <= 20));
assert.equal(earthFilter.queryFallbackUsed, true);

const pcLanding = await discover(pcRoot);
assert.ok(pcLanding.conformsTo.some(value => value.includes('cql2-json')));
const pcFilter = await search({url: pcLanding.search, method: 'POST', bbox,
  collections: [collection], filter, limit: 3, 'max-pages': 1});
assert.ok(pcFilter.items.length > 0);
assert.ok(pcFilter.items.every(item => item.properties['eo:cloud_cover'] <= 20));

console.log(JSON.stringify({
  earthSearch: {collections: collections.collections.length, getPages: get.pages,
    postPages: post.pages, areaItems: area.items.length, dataAssets: assets.assets.length,
    filteredItems: earthFilter.items.length, queryFallbackUsed: earthFilter.queryFallbackUsed,
    filterHasMore: earthFilter.hasMore},
  planetaryComputer: {filteredItems: pcFilter.items.length},
}, null, 2));
