# frozen_string_literal: true

# Rakefile

task default: :test

desc 'Run all tests'
task(:test) do
  Dir['./spec/**/*_spec.rb'].each { |f| load f }
end
