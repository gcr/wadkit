require! 'jParser'
#require! 'jszip'

WAD-SPEC = (data) ->
  string8: -> @parse ['string', 8] .replace /\0+$/g, ''
  file:
     sig: ['string', 4]
     num-lumps: 'uint32'
     directory-offset: 'uint32'
     lumps: ->
         <- @seek @current.directory-offset
         for til @current.num-lumps
           @parse 'lump'
  lump:
     offset: 'uint32'
     size: 'uint32'
     name: 'string8'
     data: ->
       c = @current
       # data is a buffer
       if c.name in ['THINGS', 'LINEDEFS', 'VERTEXES', 'SECTORS', 'SIDEDEFS']
         @seek c.offset, -> @parse [c.name, c.size]
       else
         data.slice c.offset, c.offset+c.size

  # special-purpose lumps:
  THINGrecord:
    x: 'int16'
    y: 'int16'
    angle: 'uint16'
    type: 'uint16'
    spawnFlags: 'uint16'
  THINGS: (length) ->
    @parse ['array', 'THINGrecord', length/2/5]

  LINEDEFrecord:
    v-begin: 'int16'
    v-end: 'int16'
    flags: 'int16'
    action: 'int16'
    tag: 'int16'
    front-sidedef: 'int16'
    back-sidedef: 'int16'
  LINEDEFS: (length) ->
    @parse ['array', 'LINEDEFrecord', length/2/7]
  VERTEXrecord:
    x: 'int16'
    y: 'int16'
  VERTEXES: (length) -> @parse ['array', 'VERTEXrecord', length/2/2]

  SECTORrecord:
    floor-height: 'int16'
    ceiling-height: 'int16'
    floor-flat: 'string8'
    ceiling-flat: 'string8'
    brightness: 'int16'
    special: 'int16'
    tag: 'int16'
  SECTORS: (length) -> @parse ['array', 'SECTORrecord', length/26]

  SIDEDEFrecord:
    tex-x-offset: 'int16'
    tex-y-offset: 'int16'
    upper-tex: 'string8'
    lower-tex: 'string8'
    middle-tex: 'string8'
    face-sector: 'int16'
  SIDEDEFS: (length) -> @parse ['array', 'SIDEDEFrecord', length/30]


export parse-wad = (data) ->
  ## a WAD file is a sequence of lumps.
  new Promise (resolve, reject) ->
    resolve(new jParser(data, WAD-SPEC(data)).parse 'file')

export read-map = (wad, name)-> new Promise (resolve, reject) ->
  if not name.starts-with "MAP"
    reject "Map name must begin with MAP: '#name'"
  for i til wad.lumps.length
    if wad.lumps[i].name == name
      required = ["SECTORS", "VERTEXES", "THINGS", "LINEDEFS", "SIDEDEFS"]
      map = {}
      for lump in wad.lumps.slice i+1, i+12
        if lump.name.starts-with "MAP"
          break # found another map
        if lump.name in required
          if lump.name.to-lower-case! of map
            return reject "Map has multiple lumps named '#{lump.name}'"
          map[lump.name.to-lower-case!] = lump.data
      # cool, double check everything
      for lumpname in required
        if lumpname.to-lower-case! not of map
          return reject "Map does not have required lump: '#lumpname'"

      return resolve map
  reject "Map #name does not exist"




require! 'fs'
#err, data <- fs.read-file '/Users/kimmy/srb2kart/DOWNLOAD/KL_InfiniteLaps-v1.wad'
#err, data <- fs.read-file '/Users/kimmy/srb2-mods/assets/srb2.srb'
err, data <- fs.read-file '/Users/kimmy/wadkit/Maps/MAPM8.wad'
if err
  console.log err
else
  wad <- parse-wad data .then
  map <- read-map wad, "MAPM8" .then
  console.log map
