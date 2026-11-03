# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require "webkit_web_process_extension/version"

describe WebkitWebProcessExtension do
  it "has a version" do
    expect(WebkitWebProcessExtension::VERSION).to be =~ /\A\d+\.\d+\.\d+\z/
  end
end
