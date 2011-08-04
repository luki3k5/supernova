require "will_paginate"

class Supernova::Collection < WillPaginate::Collection
  attr_accessor :original_response, :facets
end