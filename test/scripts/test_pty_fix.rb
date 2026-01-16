#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to validate PTY output parsing fix
# Run with: bundle exec ruby test/scripts/test_pty_fix.rb

require 'bundler/setup'
require 'train-k8s-container'

POD = ENV['TEST_POD'] || 'test-ubuntu'
CONTAINER = ENV['TEST_CONTAINER'] || 'test-ubuntu'
NAMESPACE = ENV['TEST_NAMESPACE'] || 'default'

puts '=== Testing PTY Output Parsing Fix ==='
puts "Target: #{NAMESPACE}/#{POD}/#{CONTAINER}"
puts

# Create connection to test pod
conn = TrainPlugins::K8sContainer::Connection.new(
  pod: POD,
  container_name: CONTAINER,
  namespace: NAMESPACE
)

puts "Platform detected: #{conn.platform.name}"
puts

results = []

# Test 1: Simple command
puts '--- Test 1: Simple command (whoami) ---'
result = conn.run_command('whoami')
puts "stdout: #{result.stdout.inspect}"
puts "exit_status: #{result.exit_status}"
pass = result.stdout.strip == 'root'
puts pass ? '✅ PASS' : '❌ FAIL'
results << pass
puts

# Test 2: Directory existence (the bug scenario)
puts '--- Test 2: Directory /var/log exists? ---'
file = conn.file('/var/log')
puts "exists?: #{file.exist?}"
# First verify ground truth
ground_truth = conn.run_command('test -d /var/log && echo YES || echo NO').stdout.strip == 'YES'
puts "ground truth (via command): #{ground_truth}"
pass = file.exist? == ground_truth
puts pass ? '✅ PASS (matches ground truth)' : '❌ FAIL (mismatch with ground truth)'
results << pass
puts

# Test 3: Multi-line command (the PTY parsing bug)
puts '--- Test 3: Multi-line command output ---'
result = conn.run_command('for f in /etc/*.conf; do echo "Found: $f"; done | head -3')
puts "stdout: #{result.stdout.inspect}"
puts "exit_status: #{result.exit_status}"
# Check output does not contain command echo-back
pass = !result.stdout.include?('for f in')
puts pass ? '✅ PASS - no command echo-back in output' : '❌ FAIL - output contains command echo-back (BUG!)'
results << pass
puts

# Test 4: Verify no internal markers in output
puts '--- Test 4: No internal markers in output ---'
result = conn.run_command('echo test')
# Check for any EXIT_CODE marker pattern (includes UUID-based markers like __EXIT_CODE_deadbeef__)
has_markers = result.stdout.match?(/__EXIT_CODE_[0-9a-f]+__/) || result.stdout.include?('2>&1')
puts "stdout: #{result.stdout.inspect}"
pass = !has_markers
puts pass ? '✅ PASS - clean output' : '❌ FAIL - internal markers leaked'
results << pass
puts

# Test 5: File that does not exist
puts '--- Test 5: Non-existent file detection ---'
file = conn.file('/this/does/not/exist')
puts "exists?: #{file.exist?}"
pass = file.exist? == false
puts pass ? '✅ PASS (correctly detects missing file)' : '❌ FAIL'
results << pass
puts

# Test 6: Stat command output (used by InSpec directory resource)
puts '--- Test 6: Stat command parsing ---'
result = conn.run_command('stat -c "%U %G %a" /etc')
puts "stdout: #{result.stdout.inspect}"
puts "exit_status: #{result.exit_status}"
# Should be something like "root root 755"
pass = result.exit_status.zero? && result.stdout.include?('root')
puts pass ? '✅ PASS' : '❌ FAIL'
results << pass
puts

# Summary
puts '=== Summary ==='
passed = results.count(true)
failed = results.count(false)
puts "Passed: #{passed}/#{results.length}"
puts "Failed: #{failed}/#{results.length}"
puts

# Clean up PTY sessions
TrainPlugins::K8sContainer::SessionManager.instance.cleanup_all
puts 'Cleaned up PTY sessions'

exit(failed.zero? ? 0 : 1)
