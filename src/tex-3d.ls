window.THREE = require 'three'

require! './wad-parser.ls'
atlas-manager = require 'three-sprite-texture-atlas-manager'

export class TextureManager
  ->
    @atlas = new atlas-manager 1024
    @tex-buffers = {}
    @tex-to-index = {}
    @uvs = []
    @palette = null

  ingest-wad: (wad)->
    for lump in wad.lumps
      if lump.name == 'PLAYPAL'
        @palette = lump.data
    if not @palette
      throw new Error "can't load textures - no PLAYPAL palette"
    within-tx-start = null
    for lump in wad.lumps
      if lump.name == 'TX_END'
        within-tx-start = false
      if within-tx-start
        @tex-buffers[lump.name] = lump.data
      if lump.name == 'TX_START'
        within-tx-start = true

  get: (name)->
    if name not of @tex-buffers
      return 0

    if name of @tex-to-index
      return @tex-to-index[name]

    console.log name

    image-data = wad-parser.lump-to-image-data @tex-buffers[name], @palette
    node = @atlas.allocate image-data.width, image-data.height
    node.clip-context!.put-image-data image-data, 0, 0
    @uvs.push ...node.uv-coordinates!
    node.restore-context!
    @tex-to-index[name] = @tex-to-index.length
    return @tex-to-index[name]

  get-shader-material: ->
    console.log @atlas
    vertex-shader = """
        attribute float texIndex;
        varying float vTexIndex;
        varying vec2 vUv;
void main () {
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  vUv = uv;
}

    """
    fragment-shader = """
        varying vec2 vUv;
        varying float texIndex;
        uniform sampler2D atlas;
        uniform float texuv[4];
        void main() {
            int(texuv[int(texIndex)]);
            gl_FragColor = texture2D(atlas, vUv);
            //vec4(1.0,1.0,1.0,1.0);
        }
    """
    return new THREE.ShaderMaterial do
      uniforms:
        atlas:
          type: 't'
          value: @atlas.knapsacks[0].root-texture
        texuv:
          type: 'v'
          value: [0,1,2,3,4]
      vertex-shader: vertex-shader
      fragment-shader: fragment-shader
