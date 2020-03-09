window.THREE = require 'three'

require! 'path'

require! './wad-parser.ls'
require! './texture-parser.ls'
atlas-manager = require 'three-sprite-texture-atlas-manager'

export class TextureManager
  ->
    @atlas = new atlas-manager 4096
    # mapping from texture name to (-> ImageData)
    @tex-thunks = {}
    # texture name to UV index
    @tex-to-index = {}
    # index of [left,top,right,bottom]
    @rects = []
    # lookup table
    @palette = null
    @count = 0

  ingest-wad: (wad)->
    for lump in wad.lumps
      if lump.name == 'PLAYPAL'
        @palette = lump.data
    if not @palette
      throw new Error "can't load textures - no PLAYPAL palette"
    @within-tx-start = null
    for let lump in wad.lumps
      if lump.name == 'TEXTURES'
        str = new TextDecoder("utf-8").decode(lump.data)
        for k,texdata of texture-parser.TEXTURES str
          @tex-thunks[k] = ~> @composite-texture texdata, k
      if lump.name == 'TX_END'
        @within-tx-start = false
      if @within-tx-start
        @tex-thunks[lump.name] = ~>
          wad-parser.patch-to-image-data lump.data, @palette
      if lump.name == 'TX_START'
        @within-tx-start = true
    return Promise.resolve!

  ingest-pk3: (pk3)->
    promises = []
    for let name, fileobj of pk3
      if path.basename(name) == 'PLAYPAL'
        promises.push new Promise (resolve, reject)~>
          buf <~ fileobj.async 'nodebuffer' .then
          @palette = new jParser(buf, wad-parser.WAD-SPEC!).parse 'PLAYPAL'
          resolve!
    for let name, fileobj of pk3
      d = path.dirname(name)
      # parse all lumps as doom patches in "Textures/" folder
      if d.starts-with "Textures" or d.starts-with "Patches"
        lumpname = path.basename(name).split('.')[0]
        promises.push new Promise (resolve, reject)~>
            buf <~ fileobj.async 'nodebuffer' .then
            @tex-thunks[lumpname] = ~>
              wad-parser.patch-to-image-data buf, @palette
            resolve!
      # parse all flats as raw values
      if d.starts-with "Flats"
        lumpname = path.basename(name)
        promises.push new Promise (resolve, reject)~>
            buf <~ fileobj.async 'nodebuffer' .then
            @tex-thunks[lumpname] = ~>
              wad-parser.flat-to-image-data buf, @palette
            resolve!
      # Parse TEXTURES definitions
      if path.basename(name).starts-with "TEXTURES"
        promises.push new Promise (resolve, reject)~>
            buf <~ fileobj.async 'nodebuffer' .then
            str = new TextDecoder("utf-8").decode(buf)
            for let k,texdata of texture-parser.TEXTURES str
                @tex-thunks[k] = ~> @composite-texture texdata, k
            resolve!
    return Promise.all promises

  composite-texture: ({width, height, patches}, k)->
    console.log "Making", k
    canvas = document.create-element('canvas') <<< {width,height}
    ctx = canvas.get-context '2d'
    for {pname, x, y, flipX, flipY} in patches
      if pname of @tex-thunks
        # we may want to add patches, etc
        image-data = @tex-thunks[pname]!
        patch = document.create-element('canvas') <<< {image-data.width,image-data.height}
        pctx = patch.get-context '2d'
        pctx.put-image-data image-data,0,0
        ctx.save!
        ctx.translate x,y
        if flipX
          ctx.scale -1, 1
          ctx.translate -patch.width, 0
        if flipY
          ctx.scale 1, -1
          ctx.translate 0, -patch.height
        ctx.draw-image patch,0,0
        #ctx.put-image-data @tex-thunks[pname]!, x, y
        ctx.restore!
      else
        console.log "uh oh - cannot find patch", pname
    return ctx.get-image-data 0,0,width,height

  get: (name)->
    if name not of @tex-thunks
      console.log "Warning: Texture not found:", name
      return 0
    if name.starts-with 'SKY'
      console.log "Not getting sky"
      return 0

    if name of @tex-to-index
      return @tex-to-index[name]

    image-data = @tex-thunks[name]!
    node = @atlas.allocate image-data.width, image-data.height
    rect = node.rectangle
    node.clip-context!.put-image-data image-data, rect.left, rect.top
    @rects.push rect
    node.restore-context!
    @tex-to-index[name] = @count++
    return @tex-to-index[name]

  fix-tex-bounds: (geo)->
    index = geo.get-attribute 'texIndex'
    bounds = geo.get-attribute 'texBounds'
    for i in [0 til index.count]
        vTexIndex = index.array[i]
        r = @rects[vTexIndex]
        if vTexIndex == 13
            console.log r
        bounds.setXYZW i, r.left, r.top, r.width, r.height

  get-shader-material: ->
    console.log @
    #document.body.prepend @atlas.knapsacks[0]._canvas
    with @atlas.knapsacks[0].root-texture
      ..flipY = false
      ..mag-filter = THREE.NearestFilter
      ..min-filter = THREE.NearestFilter
      ..needs-update = true
    vertex-shader = """
        attribute float texIndex;
        attribute vec4 texBounds;
        varying vec2 vUv;
        varying vec4 vTexBounds;
void main () {
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  vUv = uv;
  vTexBounds = texBounds;
}

    """
    fragment-shader = """
    varying highp vec2 vUv;
    varying highp vec4 vTexBounds;
    uniform sampler2D atlas;
    void main() {
        vec2 texLT = vec2(vTexBounds[0], vTexBounds[1]);
        vec2 texSize = vec2(vTexBounds[2], vTexBounds[3]);
        float epsilon = 0.001;
        vec2 loc = texLT + (clamp(fract(vUv / texSize),
            0.001, 0.999) * texSize);
        gl_FragColor = texture2D(atlas, loc / 4096.);
        //gl_FragColor = vec4(loc[0], loc[1], 0.0, 1.0);
    }
    """
    return new THREE.ShaderMaterial do
      uniforms:
        atlas:
          type: 't'
          value: @atlas.knapsacks[0].root-texture
      vertex-shader: vertex-shader
      fragment-shader: fragment-shader
      polygon-offset: true
      polygon-offset-factor: 1.0
      polygon-offset-units: -4.0
