Bloom = require('bloomfilter').BloomFilter
bloom = new Bloom(8957440, 7); null
lazy = require('lazy')

lazy(process.stdin)
  .lines
  .forEach (line) -> bloom.add(line)
  .on 'pipe', ->
    buffer = new Buffer(new Uint8Array(bloom.buckets.buffer))
    process.stdout.write(buffer)