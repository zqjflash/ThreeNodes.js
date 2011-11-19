define [
  'jQuery',
  'Underscore', 
  'Backbone',
  "text!templates/node.tmpl.html",
  "order!libs/jquery.tmpl.min",
  "order!libs/jquery.contextMenu",
  "order!libs/jquery-ui/js/jquery-ui-1.8.16.custom.min",
  'order!threenodes/core/NodeFieldRack',
  'order!threenodes/utils/Utils',
], ($, _, Backbone, _view_node_template) ->
  class ThreeNodes.nodes.types.Three.Object3D extends ThreeNodes.NodeBase
    set_fields: =>
      super
      @auto_evaluate = true
      @ob = new THREE.Object3D()
      @rack.addFields
        inputs:
          "children": {type: "Array", val: []}
          "position": {type: "Vector3", val: new THREE.Vector3()}
          "rotation": {type: "Vector3", val: new THREE.Vector3()}
          "scale": {type: "Vector3", val: new THREE.Vector3(1, 1, 1)}
          "doubleSided": false
          "visible": true
          "castShadow": false
          "receiveShadow": false
        outputs:
          "out": {type: "Any", val: @ob}
      @vars_shadow_options = ["castShadow", "receiveShadow"]
      @shadow_cache = @create_cache_object(@vars_shadow_options)
  
    compute: =>
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['children'])
      childs_in = @rack.get("children").get()
      
      # no connections mean no children
      if @rack.get("children").connections.length == 0 && @ob.children.length != 0
        @ob.remove(@ob.children[0]) while @ob.children.length > 0
      
      # remove old childs
      for child in @ob.children
        ind = childs_in.indexOf(child)
        if child && ind == -1 && child
          #console.log "object remove child"
          #console.log @ob
          @ob.removeChild(child)
      
      #add new childs
      for child in childs_in
        ind = @ob.children.indexOf(child)
        if ind == -1
          #console.log "object add child"
          #console.log @ob
          @ob.addChild(child)
      
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.Scene extends ThreeNodes.nodes.types.Three.Object3D
    set_fields: =>
      super
      @ob = new THREE.Scene()
      current_scene = @ob
  
    apply_children: =>
      # no connections means no children
      if @rack.get("children").connections.length == 0 && @ob.children.length != 0
        @ob.remove(@ob.children[0]) while @ob.children.length > 0
        return true
      
      childs_in = @rack.get("children").get()
      # remove old childs
      for child in @ob.children
        ind = childs_in.indexOf(child)
        if child && ind == -1 && child instanceof THREE.Light == false
          #console.log "scene remove child"
          #console.log @ob
          @ob.remove(child)
          
      for child in @ob.children
        ind = childs_in.indexOf(child)
        if child && ind == -1 && child instanceof THREE.Light == true
          @ob.remove(child)
          
      #add new childs
      for child in childs_in
        if child instanceof THREE.Light == true
          ind = @ob.children.indexOf(child)
          if ind == -1
            @ob.add(child)
            ThreeNodes.rebuild_all_shaders()
        else
          ind = @ob.children.indexOf(child)
          if ind == -1
            #console.log "scene add child"
            #console.log @ob
            @ob.add(child)
  
    compute: =>
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['children', 'lights'])
      @apply_children()
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.Mesh extends ThreeNodes.nodes.types.Three.Object3D
    set_fields: =>
      super
      @rack.addFields
        inputs:
          "geometry": {type: "Any", val: new THREE.CubeGeometry( 200, 200, 200 )}
          "material": {type: "Any", val: new THREE.MeshLambertMaterial( { color: 0xff0000, wireframe: false })}
          "overdraw": false
      @ob = false
      @geometry_cache = false
      @material_cache = false
      @compute()
  
    compute: =>
      needs_rebuild = false
      
      if @input_value_has_changed(@vars_shadow_options, @shadow_cache)
        needs_rebuild = true
      
      if @geometry_cache != @rack.get('geometry').get().id || @material_cache != @rack.get('material').get().id || needs_rebuild
        @ob = new THREE.Mesh(@rack.get('geometry').get(), @rack.get('material').get())
        @geometry_cache = @rack.get('geometry').get().id
        @material_cache = @rack.get('material').get().id
      
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['children', 'geometry'])
      @shadow_cache = @create_cache_object(@vars_shadow_options)
      
      if needs_rebuild == true
        ThreeNodes.rebuild_all_shaders()
      
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.Camera extends ThreeNodes.NodeBase
    set_fields: =>
      super
      @ob = new THREE.PerspectiveCamera(75, 800 / 600, 1, 10000)
      @rack.addFields
        inputs:
          "fov": 50
          "aspect": 1
          "near": 0.1
          "far": 2000
          "position": {type: "Vector3", val: new THREE.Vector3()}
          "target": {type: "Vector3", val: new THREE.Vector3()}
          "useTarget": false
        outputs:
          "out": {type: "Any", val: @ob}
  
    compute: =>
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['target'])
      @ob.lookAt(@rack.get("target").get())
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.Texture extends ThreeNodes.NodeBase
    set_fields: =>
      super
      @ob = false
      @cached = false
      @rack.addFields
        inputs:
          "image": {type: "String", val: false}
        outputs:
          "out": {type: "Any", val: @ob}
  
    compute: =>
      current = @rack.get("image").get()
      if current && current != ""
        if @cached == false || ($.type(@cached) == "object" && @cached.constructor == THREE.Texture && @cached.image.attributes[0].nodeValue != current)
          #@ob = new THREE.Texture(current)
          @ob = new THREE.ImageUtils.loadTexture(current)
          console.log "new texture"
          console.log @ob
          @cached = @ob
          
      @rack.set("out", @ob)
      
  class ThreeNodes.nodes.types.Three.WebGLRenderer extends ThreeNodes.NodeBase
    set_fields: =>
      super
      @auto_evaluate = true
      @ob = ThreeNodes.Webgl.current_renderer
      @width = 0
      @height = 0
      @rack.addFields
        inputs:
          "width": 800
          "height": 600
          "scene": {type: "Scene", val: new THREE.Scene()}
          "camera": {type: "Camera", val: new THREE.PerspectiveCamera(75, 800 / 600, 1, 10000)}
          "bg_color": {type: "Color", val: new THREE.Color(0, 0, 0)}
          "postfx": {type: "Array", val: []}
          "shadowCameraNear": 3
          "shadowCameraFar": 3000
          "shadowMapWidth": 512
          "shadowMapHeight": 512
          "shadowMapEnabled": false
          "shadowMapSoft": true
        outputs:
          "out": {type: "Any", val: @ob}
      @apply_size()
      @rack.get("camera").val.position.z = 1000
      @win = false
      if @context.testing_mode == false
        @win = window.open('', 'win' + @nid, "width=800,height=600,scrollbars=false,location=false,status=false,menubar=false")
        @win.document.body.appendChild( @ob.domElement );
        $("*", @win.document).css
          padding: 0
          margin: 0
      @old_bg = false
      @apply_bg_color()
    
    apply_bg_color: ->
      new_val = @rack.get('bg_color').get().getContextStyle()
      if @win && @old_bg != new_val
        $(@win.document.body).css
          background: new_val
        @ob.setClearColor( @rack.get('bg_color').get(), 1 )
        @old_bg = new_val
    
    apply_size: =>
      if !@win
        return false
      w = @rack.get('width').get()
      h = @rack.get('height').get()
      if w != @width || h != @height
        @ob.setSize(w, h)
      @width = w
      @height = h
    
    apply_post_fx: =>
      # work on a copy of the incoming array
      fxs = @rack.get("postfx").get().slice(0)
      # 1st pass = rendermodel, last pass = screen
      fxs.unshift ThreeNodes.Webgl.renderModel
      fxs.push ThreeNodes.Webgl.effectScreen
      ThreeNodes.Webgl.composer.passes = fxs
      
    compute: =>
      @apply_size()
      @apply_bg_color()
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['width', 'height', 'scene', 'camera', 'bg_color', 'postfx'])
      ThreeNodes.Webgl.current_camera = @rack.get("camera").get()
      ThreeNodes.Webgl.current_scene = @rack.get("scene").get()
      
      @apply_post_fx()
      @ob.clear()
      ThreeNodes.Webgl.renderModel.scene = ThreeNodes.Webgl.current_scene
      ThreeNodes.Webgl.renderModel.camera = ThreeNodes.Webgl.current_camera
      ThreeNodes.Webgl.composer.render(0.05)