# This example is adapted from https://threejs.org/examples/#webgl_loader_gltf
require 'js_wrap/three'
require 'js_wrap/three/controls/OrbitControls'
require 'js_wrap/three/loaders/GLTFLoader'
require 'js_wrap/three/loaders/RGBELoader'
require 'js_wrap/three/utils/RoughnessMipmapper'

renderer, scene, camera = nil

PATH = "https://raw.githubusercontent.com/mrdoob/three.js/master/examples/"

render = proc do
  renderer.render(scene, camera)
end

init = proc do
  camera = Three::PerspectiveCamera.new(45, JSGlobal.inner_width / JSGlobal.inner_height, 0.25, 20)
  camera.position.set(-1.8, 0.6, 2.7)

  scene = Three::Scene.new

  Three::RGBELoader.new.set_path(PATH + 'textures/equirectangular/')
                       .load('royal_esplanade_1k.hdr') do |texture|
    texture.mapping = Three::EquirectangularReflectionMapping

    scene.background = texture
    scene.environment = texture

    render.call

    roughness_mipmapper = Three::RoughnessMipmapper.new(renderer)

    Three::GLTFLoader.new.set_path(PATH + 'models/gltf/DamagedHelmet/glTF/')
                         .load('DamagedHelmet.gltf') do |gltf|
      gltf.scene.traverse do |child|
        if child[:is_mesh]
          roughness_mipmapper.generate_mipmaps(child.material)
        end
      end

      scene << gltf.scene

      roughness_mipmapper.dispose

      render.call
    end
  end

  renderer = Three::WebGLRenderer.new(antialias: true)
  renderer.set_pixel_ratio(JSGlobal.device_pixel_ratio)
  renderer.set_size(JSGlobal.inner_width, JSGlobal.inner_height)
  renderer.tone_mapping = Three::ACESFilmicToneMapping
  renderer.tone_mapping_exposure = 1
  renderer.outputEncoding = Three.sRGBEncoding
  
  JSGlobal.document.body.append_child(renderer.dom_element)

  controls = Three::OrbitControls.new(camera, renderer.dom_element)
  controls.add_event_listener('change', &render)
  controls.min_distance = 2
  controls.max_distance = 10
  controls.target.set(0, 0, 0.2)
  controls.update

  JSGlobal.add_event_listener('resize') do
    camera.aspect = JSGlobal.inner_width / JSGlobal.inner_height
    camera.update_projection_matrix

    renderer.set_size(JSGlobal.inner_width, JSGlobal.inner_height)

    render.call
  end
end

JSGlobal.add_event_listener("DOMContentLoaded") do
  init.call
  render.call
end
