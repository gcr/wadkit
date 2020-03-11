
# See P_AddFakeFloorsByLine
FOF-TYPES = do
  100: # FOF (solid, opaque, shadows)
    {+draw-flats, +draw-lines, -translucent, +shadows}
  101: # FOF (solid, opaque, no shadows)
    {+draw-flats, +draw-lines, -translucent, -shadows}
  102: # TL block: FOF (solid, translucent)
    {+draw-flats, +draw-lines, +translucent, -shadows} # TODO: NOCLIMB ...
  103: # Solid FOF with no floor/ceiling (quite possibly useless)
    {-draw-flats, +draw-lines, -translucent, -shadows}
  104: # 3D Floor type that doesn't draw sides
    {+draw-flats, +draw-lines, -translucent, -shadows} # TODO: NOCLIMB...
  105: # FOF (solid, invisible)
    {-draw-flats, -draw-lines, -translucent, -shadows}
  120: # Opaque water
    {+draw-flats, +draw-lines, -translucent, +shadows} # TODO: flags
  121: # TL water
    {+draw-flats, +draw-lines, +translucent, +shadows} # TODO: flags
  122: # Opaque water, no sides
    {+draw-flats, -draw-lines, -translucent, +shadows} # TODO: flags
  123: # TL water, no sides
    {+draw-flats, -draw-lines, +translucent, +shadows} # TODO: flags
  124: # goo water
    {+draw-flats, +draw-lines, +translucent, +shadows} # TODO: flags
  125: # goo water, no sides
    {+draw-flats, -draw-lines, +translucent, +shadows} # TODO: flags
  140: # 'Platform' - You can jump up through it
    {+draw-flats, +draw-lines, -translucent, +shadows} # TODO: NOCLIMB
  141: # Translucent "platform"
    {+draw-flats, +draw-lines, +translucent, +shadows} # TODO: NOCLIMB
  142: # Translucent "platform" with no sides
    {+draw-flats, -draw-lines, +translucent, +shadows} # TODO: NOCLIMB
  143: # 'Reverse platform' - You fall through it
    {+draw-flats, +draw-lines, -translucent, +shadows} # TODO: flags
  144: # Translucent "reverse platform"
    {+draw-flats, +draw-lines, +translucent, +shadows} # TODO: flags
  145: # Translucent "reverse platform" with no sides
    {+draw-flats, -draw-lines, +translucent, +shadows} # TODO: flags
  146: # Intangible floor/ceiling with solid sides (fences/hoops maybe?)
    {-draw-flats, +draw-lines, -translucent, -shadows}
  150: # Air bobbing platform
    {-draw-flats, +draw-lines, -translucent, -shadows}
  151: # Adjustable air bobbing platform
    {-draw-flats, +draw-lines, -translucent, -shadows}
  152: # Adjustable air bobbing platform in reverse
    {-draw-flats, +draw-lines, -translucent, -shadows}
  160: # Float/bob platform
    {-draw-flats, +draw-lines, -translucent, -shadows}
  170: # Crumbling platform
    {-draw-flats, +draw-lines, -translucent, -shadows}
  171: # Crumbling platform that will not return
    {-draw-flats, +draw-lines, -translucent, -shadows}
  172: # "Platform" that crumbles and returns
    {+draw-flats, +draw-lines, -translucent, -shadows}
  173: # "Platform" that crumbles and doesn't return
    {+draw-flats, +draw-lines, -translucent, -shadows}
  174: # Translucent "platform" that crumbles and returns
    {+draw-flats, +draw-lines, +translucent, -shadows} # TODO: all lines
  175: # Translucent "platform" that crumbles and doesn't return
    {+draw-flats, +draw-lines, +translucent, -shadows} # TODO: all lines
  176: # Air bobbing platform that will crumble and bob on the water when it falls and hits
    {+draw-flats, +draw-lines, -translucent, -shadows}
  177: # Air bobbing platform that will crumble and bob on the water when it falls and hits, then never return
    {+draw-flats, +draw-lines, -translucent, -shadows}
  178: # Crumbling platform that will float when it hits water
    {+draw-flats, +draw-lines, -translucent, -shadows}
  179: # Crumbling platform that will float when it hits water, but not return
    {+draw-flats, +draw-lines, -translucent, -shadows}
  180: # Air bobbing platform that will crumble
    {+draw-flats, +draw-lines, -translucent, -shadows}
  190: # Rising Platform FOF (solid, opaque, shadows)
    {+draw-flats, +draw-lines, -translucent, +shadows}
  191: # Rising Platform FOF (solid, opaque, no shadows)
    {+draw-flats, +draw-lines, -translucent, -shadows}
  192: # Rising Platform TL block: FOF (solid, translucent)
    {+draw-flats, +draw-lines, +translucent, -shadows}
  193: # Rising Platform FOF (solid, invisible)
    {-draw-flats, -draw-lines, -translucent, -shadows}
  194: # Rising Platform 'Platform' - You can jump up through it
    {+draw-flats, +draw-lines, +translucent, -shadows} # TODO: all sides
  195: # Rising Platform Translucent "platform"
    {+draw-flats, +draw-lines, +translucent, -shadows} # TODO: all sides
  200: # Double light effect
    null#{+draw-flats, +draw-lines, +translucent, +shadows} # TODO: light
  201: # Light effect
    null #TODO
  202: # Fog
    null #TODO
  220: # Like opaque water, but not swimmable. (Good for snow effect on FOFs)
    {+draw-flats, +draw-lines, -translucent, +shadows}
  221: # FOF (intangible, translucent)
    {+draw-flats, +draw-lines, +translucent, +shadows} # TODO: NOCLMB
  222: # FOF with no floor/ceiling (good for GFZGRASS effect on FOFs)
    {-draw-flats, +draw-lines, +translucent, +shadows} # TODO: NOCLMB
  223: # FOF (intangible, invisible) - for combining specials in a sector
    null
  250: # Mario Block
    {+draw-flats, +draw-lines, -translucent, +shadows}
  251: # A THWOMP!
    {+draw-flats, +draw-lines, -translucent, +shadows}
  252: # Shatter block (breaks when touched)
    {+draw-flats, +draw-lines, -translucent, +shadows}
  253: # Translucent shatter block (see 76)
    {+draw-flats, +draw-lines, +translucent, +shadows}
  254: # Bustable block
    {+draw-flats, +draw-lines, -translucent, +shadows}
  255: # Spin bust block (breaks when jumped or spun downwards onto)
    {+draw-flats, +draw-lines, -translucent, +shadows}
  256: # Translucent spin bust block (see 78)
    {+draw-flats, +draw-lines, +translucent, +shadows}
  257: # Quicksand
    {+draw-flats, +draw-lines, -translucent, +shadows}
  258: # Laser block
    {+draw-flats, +draw-lines, -translucent, +shadows} # TODO
  259: # Make-Your-Own FOF!
    {+draw-flats, +draw-lines, -translucent, +shadows} # TODO

export fof-linedef-type: (linedef)->
  if linedef.action of FOF-TYPES
    return FOF-TYPES[linedef.action]
