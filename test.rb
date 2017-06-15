#!/usr/bin/env ruby
require_relative 'kubinator'
require 'minitest/autorun'

class TestKubinator < Minitest::Test
  def setup
    @kubinator = Kubinator.new
  end

  def test_kubinator
    FileUtils.stub(:touch, 'foo'){|x|
      File.stub(:exist?, false, 'foo'){|x|
        FileUtils.touch('foo') if not File.exist?('foo')
      }
    }
  end
end

# vim: ft=ruby:ts=2:sw=2:sts=2
