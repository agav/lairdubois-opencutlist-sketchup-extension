module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class SurfaceComponent

    include HashableHelper

    attr_accessor :name, :x, :y

    def initialize(name, side, x, y)
      @name = name
      @side = side
      @x = x
      @y = y
    end

  end
end