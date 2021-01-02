# Implementation of the MicroMAP Preview format

'''
MicroMAP Preview Format
=======================

The MicroMAP Preview format is a lossy, heavily compressed format for
storing a large number of maps into a single archive. MicroMAP Preview
files only store the minimal necessary information to render a 3D
preview of each map.

- Design goal: store every community SRB2kart map ever made including
  textures into a single 10MB archive that can be loaded into a 3D
  preview on a website, such as the SRB2 message board mod page.

- Non-goals: editibility: conversion to MicroMAP is a one-way trip!

Design considerations
---------------------
- Maps stored in WAD files have unnecessary data used to speed up Doom
  engine rendering such as the BSP, enemy line-of-sight information,
  etc. We don’t need this if we’re going to throw everything into a
  single OpenGL draw call!

- Existing WAD formats do not place similar structure close together
  in the file, which hurts compression.

- Existing WAD formats allow for redundancy: most map tools make a
  distinction between flats and textures, requiring identical images
  to be stored twice. Several maps make use of identical community
  texture packs, which can be deduplicated to save space further.

Alternatives considered
-----------------------

$ cat maps.kart textures.kart | lzma -9 -v > /dev/null
  100 %        37.5 MiB / 229.1 MiB = 0.164   1.6 MiB/s       2:22

Throwing all SEGS, NODES, REJECT, BLOCKMAP lumps away and nonessential
texture elements and we have:

$ cat ~/srb2kart/minified\ maps.kart ~/srb2kart/textures.wad | lzma -9 -v > /dev/null
  100 %        19.0 MiB / 173.4 MiB = 0.110   1.3 MiB/s       2:12

We can do better.


Overall structure
-----------------

The key idea is that MicroMAP stores all similar information
consecutively in a file: every texture name from every map, followed
by every 2D point, followed by every flag, and so on.

A MicroMAP Preview file is stored as the following structure:

  LZMACompress(
    Msgpack({
        maps: [{name: string, num_sectors: int, num_linedefs: int}, ...]
        sectors: sector data,
        linedefs: linedef data,
        textures: all texture data,
        things: all thing data,
      })
  )

Wherever possible, references are removed and the relevant information
is de-normalized into the parent structure (for instance, VERTEX
coordinates and SIDEDEF information is redundantly stored inside the
referencing LINEDEF). This introduces redundancy, but works better
with LZMA.

Preliminary results
-------------------
Uncompressed, maps.kart is 88MB and textures.kart is 142MB.

Without any texture downsampling, we can get down to about 12.9MB. This
is completely lossless.

By downsampling textures to 2x2, we can get all map data and textures
to around 5.1MB.

The total accounting of the space usage is:

 Byte counts:          12919k
   sectors               212k
     floorHeight           48k
     ceilingHeight         28k
     floorFlat             52k
     ceilingFlat           28k
     brightness            12k
     special               15k
     tag                   29k
   linedefs              2557k
     x1                    408k
     x2                    415k
     y1                    408k
     y2                    416k
     action                34k
     front                 573k
       tx                    97k
       ty                    13k
       tupper                30k
       tlower                102k
       tmiddle               65k
       sector                265k
     back                  533k
       tx                    84k
       ty                    11k
       tupper                44k
       tlower                109k
       tmiddle               41k
       sector                250k
   textures              10149k
     height                1k
     width                 1k
     leftOffset            0k
     topOffset             0k
     data                  10145k

'''

require! 'fs'
msgpack = require 'msgpack'
lzma = require 'lzma-native'
progress = require 'progress'
{wad-parse, picture-parse, wad-list-maps, wad-read-map, wad-list-gfx} = require './wad-parser.ls'
{MapModel} = require './map-model.ls'

err, map-wad-buf <- fs.read-file '/Users/kimmy/srb2kart/maps.kart'
err, tex-wad-buf <- fs.read-file '/Users/kimmy/srb2kart/textures.kart'

wad <- wad-parse map-wad-buf .then
maps = do ->>
  console.log "Loading maps..."
  maps = wad-list-maps wad
  bar = new progress 'Map :name :current/:total, :percent, eta :eta s', total: maps.length
  for mapname in maps
    bar.tick name: mapname
    new MapModel await wad-read-map wad, mapname
maps <- maps.then

console.log "Loading textures..."
tex-wad <- wad-parse tex-wad-buf .then
{all-gfx} = wad-list-gfx tex-wad

downsample-tex = (t, xscale=1, yscale=1)->
  {height, width, data} = t
  buf = new Uint8Array(Math.floor(height/xscale) * Math.floor(width/yscale))
  for row from 1 til height
    for col from 1 til width
      if row % yscale == 0 and col % xscale == 0
        buf[col/yscale + row/xscale*width] = t.data[col + row*width]
  t.data = buf
  t

bar = new progress 'Patch :name :current/:total, :percent, eta :eta s', total: Object.keys(all-gfx).length
all-loaded-textures = for tex of all-gfx
  bar.tick name: tex
  t = all-gfx[tex]! # Single {height, width, data: Buffer}
  if t.length # This is a FLAT, represented only as a square Buffer or Uint8Array
    t = height: Math.sqrt(t.length), width: Math.sqrt(t.length), data: t
  downsample-tex t

# Actually encode the data

all-sectors = [.. for maps for ..sectors]
all-linedefs = [.. for maps for ..linedefs]
all-vertexes = [.. for maps for ..vertexes]

u16 = (arr) -> new Uint16Array(arr)
i16 = (arr) -> new Int16Array(arr)
residu = (buf) ->
  for i from 1 til buf.length
    buf[i] = buf[i] - buf[i-1]
tex-ref = (id) -> id # TODO

# the key innovation is storing all related data together: all vertex coordinates,
# all

data = do
  #maps: TODO. store name, icon, # of linedefs, # of sectors, etc.
  sectors:
    floor-height:   u16 [..floor-height         for all-sectors]
    ceiling-height: u16 [..ceiling-height       for all-sectors]
    floor-flat:         [tex-ref ..floor-flat   for all-sectors]
    ceiling-flat:       [tex-ref ..ceiling-flat for all-sectors]
    brightness:     u16 [..brightness           for all-sectors]
    special:        u16 [..special              for all-sectors]
    tag:            u16 [..tag                  for all-sectors]
  linedefs:
    # just store both vertexes inline; redundant but LZMA likes it
    x1:             i16 [..v-begin.x       for all-linedefs]
    x2:             i16 [..v-end.x         for all-linedefs]
    y1:             i16 [..v-begin.y       for all-linedefs]
    y2:             i16 [..v-end.y         for all-linedefs]
    # residual encoding does not seem to help
#   x1:    residual i16 [..v-begin.x       for all-linedefs]
#   x2:    residual i16 [..v-end.x         for all-linedefs]
#   y1:    residual i16 [..v-begin.y       for all-linedefs]
#   y2:    residual i16 [..v-end.y         for all-linedefs]
    # storing vertexes separately and keeping pointers does not help
#   v1:             u16 [..v-begin.id      for all-linedefs]
#   v2:             u16 [..v-end.id        for all-linedefs]
# vertexes:
#   x:              u16 [..x               for all-vertexes]
#   y:              u16 [..y               for all-vertexes]
    # TODO
#   flags:              [..flags           for all-linedefs]
    action:         u16 [..action          for all-linedefs]
    front:
      tx:           u16 [..front-sidedef?.tex-x-offset       for all-linedefs]
      ty:           u16 [..front-sidedef?.tex-y-offset       for all-linedefs]
      tupper:           [tex-ref ..front-sidedef?.upper-tex  for all-linedefs]
      tlower:           [tex-ref ..front-sidedef?.lower-tex  for all-linedefs]
      tmiddle:          [tex-ref ..front-sidedef?.middle-tex for all-linedefs]
      sector:       u16 [..front-sidedef?.sector.id          for all-linedefs]
    back:
      tx:           u16 [..back-sidedef?.tex-x-offset        for all-linedefs]
      ty:           u16 [..back-sidedef?.tex-y-offset        for all-linedefs]
      tupper:           [tex-ref ..back-sidedef?.upper-tex   for all-linedefs]
      tlower:           [tex-ref ..back-sidedef?.lower-tex   for all-linedefs]
      tmiddle:          [tex-ref ..back-sidedef?.middle-tex  for all-linedefs]
      sector:       u16 [..back-sidedef?.sector.id           for all-linedefs]
  textures:
    height:             [..height           for all-loaded-textures]
    width:              [..width            for all-loaded-textures]
    left-offset:        [..left-offset or 0 for all-loaded-textures]
    top-offset:         [..top-offset or 0  for all-loaded-textures]
    data:               [..data             for all-loaded-textures]

do ->>
  # Serializing
  console.log "Writing /tmp/maps.msgpack..."
  fs.write-file-sync "/tmp/maps.msgpack", msgpack.pack data
  console.log "Complete."
  serialize-length = (obj) ->>
    kb = Math.floor((await lzma.compress msgpack.pack obj).length / 1024)
    "\x1b[1;32m#{kb}\x1b[0;32mk\x1b[0m"
  do show-byte-count = (obj=data, name='Byte counts:', depth=0) ->>
    console.log("  " * depth, name, " "*(20-name.length),await serialize-length obj)
    if obj.length is undefined
      for k,v of obj
        await show-byte-count v, k, depth+1
