require! 'jParser'
require! 'jszip'
require! 'path'

export WAD-SPEC = (data) ->
  # fixed-length 8 byte string padded with \x00, which we discard ;)
  string8: -> @parse ['string', 8] .replace /\0+$/g, ''

  # an entire WAD file. a short header, followed by a
  # bunch of lumps.
  file:
     sig: ['string', 4]
     num-lumps: 'uint32'
     directory-offset: 'uint32'
     lumps: ->
         <- @seek @current.directory-offset
         for til @current.num-lumps
           @parse 'lump'

  # an entry in a WAD file. lumps are untyped, but
  # we can sometimes infer based on the lump name.
  # note that lumps may not necessarily appear contiguously
  # in the file!
  # Also very important: lump names are not unique! don't cast this
  # to a dictionary or anything!
  lump:
     offset: 'uint32'
     size: 'uint32'
     name: 'string8'
     data: ->
       c = @current
       # data is a buffer
       if c.name in ['THINGS', 'LINEDEFS', 'VERTEXES', 'SECTORS', 'SIDEDEFS', 'PLAYPAL']
         @seek c.offset, -> @parse [c.name, c.size]
       else
         data.slice c.offset, c.offset+c.size

  # special-purpose lump specifications

  # each thing in a level
  THINGrecord:
    x: 'int16'
    y: 'int16'
    angle: 'uint16'
    type: 'uint16'
    spawnFlags: 'uint16'
  THINGS: (length) ->
    @parse ['array', 'THINGrecord', length/2/5]

  # 'vertexes' is a raw buffer of x,y locations.
  VERTEXrecord:
    x: 'int16'
    y: 'int16'
  VERTEXES: (length) -> @parse ['array', 'VERTEXrecord', length/2/2]

  # each linedef indexes into the above 'vertexes' array.
  # you have to inspect the sidedefs to understand
  # which sectors this linedef is attached to
  LINEDEFrecord:
    v-begin: 'int16'
    v-end: 'int16'
    flags: 'uint16'
    # impassible: 1
    # block-monsters: 1
    # two-sided: 1
    # upper-unpegged: 1
    # lower-unpegged: 1
    # secret: 1
    # block-sound: 1
    # not-on-map: 1
    # already-on-map: 1
    # unused: 7
    action: 'int16'
    tag: 'int16'
    front-sidedef: 'int16' # aka "right" sidedef
    back-sidedef: 'int16'  # aka "left" sidedef, or Null
    #                   back
    #    v-begin  o---------------o    v-end
    #                  front

  LINEDEFS: (length) ->
    @parse ['array', 'LINEDEFrecord', length/2/7]

  # each linedef has a front and back sidedef, plus
  # texture info, etc
  SIDEDEFrecord:
    tex-x-offset: 'int16'
    tex-y-offset: 'int16'
    upper-tex: 'string8'
    lower-tex: 'string8'
    middle-tex: 'string8'
    sector: 'int16'
  SIDEDEFS: (length) -> @parse ['array', 'SIDEDEFrecord', length/30]

  # a contiguous bit of level geometry.
  # we assume that sectors are 'well-formed'; that each
  # sector is closed by linedefs
  SECTORrecord:
    floor-height: 'int16'
    ceiling-height: 'int16'
    floor-flat: 'string8'
    ceiling-flat: 'string8'
    brightness: 'int16'
    special: 'int16'
    tag: 'int16'
  SECTORS: (length) -> @parse ['array', 'SECTORrecord', length/26]


  # Graphics formats
  PLAYPAL:
    data: ['array' 'uint8' 256*3*14]
  # PICTURE is used for sprites and textures.
  PICTURE:
    width: 'uint16'
    height: 'uint16'
    left-offset: 'int16'
    top-offset: 'int16'
    data: ->
      # from the unofficial DOOM specification 1.666
      offset = @tell! - 8
      data = new Uint8Array(@current.width * @current.height)
      data.fill 255
      for ptr, col in @parse ['array', 'uint32', @current.width]
        @seek ptr - offset, ->
          while (row = @parse 'uint8') != 0xff
            n-pixels = @parse 'uint8'
            pixdata = @parse ['array', 'uint8', n-pixels + 2]
            pixdata = pixdata[1 til -1] # slice off the top
            for x,i in pixdata
              data[(row + i)*@current.width  + col] = x
      return data

# wad-parse :: Buffer -> Promise of JSON array
export wad-parse = (data) ->
  new Promise (resolve, reject) ->
    return resolve(new jParser(data, WAD-SPEC(data)).parse 'file')

# pk3-parse :: Buffer -> Promise of {filename: buffer}
# A pk3 file is a renamed zip file, so we use jszip
# to load it.
#
# To load nested WAD files, call wad-parse on the contents
# of the zip file.
export pk3-parse = (data) -> new Promise (resolve, reject)->
  ## Returns a mapping from entries of the pk3 to node buffer objects.
  zip <- jszip.load-async data, checkCRC32: false .then
  zip-entries = {}
  zip.for-each (path, file)->
    zip-entries[path] = file
  resolve zip-entries

# wad-read-map :: WAD JSON, string -> Promise(map JSON)
export wad-read-map = (wad, mapname)-> new Promise (resolve, reject) ->
  if not mapname.starts-with "MAP"
    reject "Map name must begin with MAP: '#name'"
  for i til wad.lumps.length
    # WAD maps have a MAP?? lump, followed by
    # a few other lumps with specific names.
    # We're essentially doing some pattern matching on
    # the names of the lumps that follow.

    # They are:
    # THINGS, LINEDEFS, SIDEDEFS, VERTEXES, SEGS, SSECTORS,
    # NODES, SECTORS, REJECT, BLOCKMAP
    if wad.lumps[i].name == mapname
      mapcrap = ['THINGS', 'LINEDEFS', 'SIDEDEFS', 'VERTEXES', 'SEGS',
                 'SECTORS', 'NODES', 'SSECTORS', 'REJECT']
      # these are the only ones we care about ;)
      required = ["SECTORS", "VERTEXES", "THINGS", "LINEDEFS", "SIDEDEFS"]
      map = {}
      i += 1
      while i < wad.lumps.length and wad.lumps[i].name in mapcrap
        if wad.lumps[i].name in required
          if wad.lumps[i].name.to-lower-case! of map
            return reject "Map #mapname has multiple lumps named '#{wad.lumps[i].name}'"
          map[wad.lumps[i].name.to-lower-case!] = wad.lumps[i].data
        i++
      # cool, double check everything
      for lumpname in required
        if lumpname.to-lower-case! not of map
          return reject "Map does not have required lump: '#lumpname'"

      return resolve map
  return reject "Map #mapname does not exist"

export pk3-read-map = (zip, mapname)-> new Promise (resolve, reject)->
  for pathname, file of zip
    if path.parse(pathname).name == mapname
      buf <- file.async 'nodebuffer' .then
      return wad-parse buf .then (wad)->
        return resolve wad-read-map wad, mapname
  reject "Map #mapname not found"

export patch-to-image-data = (data, palette) ->
    lump = new jParser(data, WAD-SPEC(data)).parse 'PICTURE'
    image-data = new ImageData lump.width, lump.height
    for x,i in lump.data
      if x != 255
        image-data.data[4*i + 0] = palette.data[3*x + 0]
        image-data.data[4*i + 1] = palette.data[3*x + 1]
        image-data.data[4*i + 2] = palette.data[3*x + 2]
        image-data.data[4*i + 3] = 255
    return image-data
export flat-to-image-data = (data, palette) ->
    sz = Math.sqrt(data.length)
    image-data = new ImageData sz,sz
    for x,i in data
      if x != 255
        image-data.data[4*i + 0] = palette.data[3*x + 0]
        image-data.data[4*i + 1] = palette.data[3*x + 1]
        image-data.data[4*i + 2] = palette.data[3*x + 2]
        image-data.data[4*i + 3] = 255
    return image-data

#require! 'fs'
#err, data <- fs.read-file '/Users/kimmy/srb2kart/DOWNLOAD/KL_InfiniteLaps-v1.wad'
#err, data <- fs.read-file '/Users/kimmy/srb2-mods/assets/srb2.srb'

## WAD test
#require! 'fs'
#err, data <- fs.read-file '/Users/kimmy/wadkit/Maps/MAPM8.wad'
#if err
#  console.log err
#else
#  wad <- wad-parse data .then
#  for l in wad.lumps
#    console.log l.name, l.size
#  map <- wad-read-map wad, "MAPM8" .then
#
### PK3 test
#require! 'fs'
#err, data <- fs.read-file '/Users/kimmy/srb2-mods/assets/srb2.srb'
#wad <- wad-parse data .then
#for lump in wad.lumps
#    if lump.name == "STLIVEX"
#      console.log(new jParser(lump.data, WAD-SPEC!).parse 'PICTURE')

#map <- pk3-read-map zip, "MAP04" .then
#console.log map
#console.log do
#  n-vertexes: map.vertexes.length
#  n-linedefs: map.linedefs.length
#  n-sectors: map.sectors.length
