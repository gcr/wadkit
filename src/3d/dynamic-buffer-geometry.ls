THREE = require 'three'

export class BufferGeoAggregate extends THREE.BufferGeometry

  # You apparently can't resize attributes.
  # So, allocate a Metric Fuckton of these attributes.

  (initial_alloc_mb, attributes)->
    super!
    all_attr_size = 0
    for k,size of attributes then all_attr_size += size

    @_allocated-n-elements = Math.ceil initial_alloc_mb*1024*1024/4/all_attr_size
    console.log {@_allocated-n-elements}

    for attr_name, size of attributes
      arr = new Float32Array(size * @_allocated-n-elements)
      @set-attribute attr_name, new THREE.Float32BufferAttribute arr, size

    @_index-offset = 0
    @_attr-offset = 0
    @_metadata = new WeakMap!
    @index = new THREE.Uint32BufferAttribute(new Uint32Array(@_allocated-n-elements * 3), 1)

  set: (key, geometries)->
    if @_metadata.has key
      m = @_metadata.get key
      n-vertices = n-index = 0
      for geometries then n-vertices += ..attributes.position.count
      for geometries then n-index += ..index.count
      if m.attr-used == n-vertices and m.index-used == n-index
        @_update key, geometries
      else
        throw Error "Resizing this geometry is not supported...."
        debugger
    else
      @_create key, geometries

  _update: (key, geometries)->
    {attr-offset, index-offset} = @_metadata.get key
    for geo in geometries
      for name,attr of @attributes
        other-attr = geo.get-attribute name
        attr.set other-attr.array, attr-offset * attr.item-size
        attr.needs-update = true
      for i in [0 til geo.index.count]
        @index.setX index-offset + i, geo.index.getX(i)+attr-offset
      @index.needs-update = true
      index-offset += geo.index.count
      attr-offset += geo.attributes.position.count

  _create: (key, geometries)->
    # Number of used vertices
    attr-offset = @_attr-offset
    # Number of used indices that represent vertices.
    # Typically grows much faster than attr-offset.
    index-offset = @_index-offset

    for geo in geometries
      for name,attr of @attributes
        other-attr = geo.get-attribute name
        attr.set other-attr.array, attr-offset * attr.item-size
      for i in [0 til geo.index.count]
        @index.setX index-offset + i, geo.index.getX(i)+attr-offset
      index-offset += geo.index.count
      attr-offset += geo.attributes.position.count


    m = {
      attr-offset: @_attr-offset, index-offset: @_index-offset,
      attr-used: attr-offset - @_attr-offset, index-used: index-offset - @_index-offset
    }
    @_attr-offset = attr-offset
    @_index-offset = index-offset

    @_metadata.set key, m
    @set-draw-range 0, @_index-offset
