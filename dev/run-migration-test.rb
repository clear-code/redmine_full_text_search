#!/usr/bin/env ruby

$VERBOSE = true

require "test-unit"

test_dir = File.expand_path(File.join(__dir__, "..", "test", "migration"))

exit(Test::Unit::AutoRunner.run(true, test_dir))
