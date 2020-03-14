moo = require 'moo'

# format the TEXTURES lump, which
# describes multipatch wall textures.
# see https://wiki.srb2.org/wiki/Texture
#
# example:
#
#   walltexture TEXTNAME, width, height {
#   	patch P1NAME, x1, y1
#   	patch P2NAME, x2, y2
#   	...
#   }

export TEXTURES = (str)->
  lexer = moo.compile do
    walltexture: ['WallTexture', 'WALLTEXTURE', 'walltexture', 'Texture', 'TEXTURE', 'texture']
    patch: ['patch', 'Patch', 'PATCH']
    flipy: ['flipy', 'FlipY']
    flipx: ['flipx', 'FlipX']
    style: ['style', 'Style']
    alpha: ['alpha', 'Alpha']
    subtract: ['subtract', 'Subtract']
    translucent: ['translucent', 'Translucent']
    number: [
      {match: /[0-9]+\.[0-9]*/ value: parseFloat}
      {match: /0|-?[1-9][0-9]*/ value: parseInt}
    ]

    id: /[A-Z]?[-_~A-Z0-9]+/
    ignore: [
        /\"/ # xwe likes to add this.
        /\/\/.*?$/
        {match: /\/\*[\s\S]*\*\//, lineBreaks: true}
        {match: /[ \r\n\t]+/, lineBreaks: true}
    ]
    lbrace: '{'
    rbrace: '}'
    comma: ','
    #lineBreaks: /(?:(?:[ \n\t]+))/

  lexer.reset str

  next = ->
    while (token = lexer.next!)?.type == 'ignore'
      true
    return token

  expect = (type, token=next!)->
    if token
        if token.type != type
          throw new Error lexer.formatError token, "expected #type"
        token

  textures = {}
  while expect "walltexture"
    texname = expect "id"
    expect "comma"
    width = expect "number" .value
    expect "comma"
    height = expect "number" .value
    expect "lbrace"
    patches = []
    while (token = next!)?.type != 'rbrace'
      if token.type == 'patch'
        expect "patch", token
        pname = expect "id" .value
        expect "comma"
        x = expect "number" .value
        expect "comma"
        y = expect "number" .value
        patches.push {pname, x, y}
      else
        expect "lbrace", token
        while (token = next!)?.type != 'rbrace'
          if token.type == 'flipy'
            patches[*-1].flipY = true
          if token.type == 'flipx'
            patches[*-1].flipX = true
    textures[texname] = {width, height, patches}
  return textures
