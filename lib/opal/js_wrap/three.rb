# frozen_string_literal: true

require_relative "three/version"

module Opal
  module JSWrap
    module Three
    end
  end
end

require "opal"

Opal.append_path File.expand_path('../../../../lib-opal', __FILE__).untaint