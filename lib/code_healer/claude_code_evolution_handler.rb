require 'timeout'
require 'open3'

module CodeHealer
  class ClaudeCodeEvolutionHandler
    class << self
      def handle_error_with_claude_code(error, class_name, method_name, file_path)
        puts "🤖 Claude Code Terminal Evolution Triggered!"
        puts "Error: #{error.class} - #{error.message}"
        puts "Class: #{class_name}, Method: #{method_name}"
        puts "File: #{file_path}"
        
        begin
          # Build comprehensive prompt
          prompt = BusinessContextManager.build_claude_code_prompt(
            error, class_name, method_name, file_path
          )
          
          # Execute Claude Code command
          success = execute_claude_code_fix(prompt, class_name, method_name)
          
          if success
            puts "✅ Claude Code evolution completed successfully!"
            # Reload modified files
            reload_modified_files
            
            # 🚀 Trigger Git operations (commit, push, PR creation)
            puts "🔄 Starting Git operations..."
            trigger_git_operations(error, class_name, method_name, file_path)
            
            return true
          else
            puts "❌ Claude Code evolution failed"
            return false
          end
          
        rescue => e
          puts "❌ Claude Code evolution error: #{e.message}"
          puts e.backtrace.first(5)
          return false
        end
      end
      
      private
      
      def execute_claude_code_fix(prompt, class_name, method_name)
        config = ConfigManager.claude_code_settings
        
        # Build command
        command = build_claude_command(prompt, config)
        
        puts "🚀 Executing Claude Code fix..."
        puts "Command: #{command}"
        puts "Timeout: #{config['timeout']} seconds"
        
        begin
          # Execute with timeout
          Timeout.timeout(config['timeout']) do
            stdout, stderr, status = Open3.capture3(command)
            
            puts "📤 Claude Code Output:"
            if stdout && !stdout.empty?
              puts "✅ Response received:"
              puts stdout

              # Check if Claude Code is asking for permission
              if stdout.include?("permission") || stdout.include?("grant") || stdout.include?("edit")
                puts "🔐 Claude Code needs permission to edit files"
                puts "💡 Make sure to grant Edit permissions when prompted"
              end
              
              # Check if fix was applied
              if stdout.include?("fix") && (stdout.include?("applied") || stdout.include?("ready"))
                puts "🎯 Fix appears to be ready - checking if files were modified..."
              end
            else
              puts "⚠️  No output received from Claude Code"
            end

            if stderr && !stderr.empty?
              puts "⚠️  Claude Code Warnings/Errors:"
              puts stderr
            end
            
            if status.success?
              puts "✅ Claude Code execution completed successfully"
              return true
            else
              puts "❌ Claude Code execution failed with status: #{status.exitstatus}"
              return false
            end
          end
          
        rescue Timeout::Error
          puts "⏰ Claude Code execution timed out after #{config['timeout']} seconds"
          return false
        rescue => e
          puts "❌ Claude Code execution error: #{e.message}"
          return false
        end
      end
      
      def build_claude_command(prompt, config)
        # Escape prompt for shell
        escaped_prompt = prompt.gsub("'", "'\"'\"'")
        
        # Build command template
        command_template = config['command_template'] || "claude --code '{prompt}'"
        
        # Replace placeholder
        command = command_template.gsub('{prompt}', escaped_prompt)
        
        # Add additional options if configured
        if config['include_tests']
          command += " --append-system-prompt 'Include tests when fixing the code'"
        end
        
        if config['max_file_changes']
          command += " --append-system-prompt 'Limit changes to #{config['max_file_changes']} files maximum'"
        end
        
        # Add file editing permissions
        command += " --permission-mode acceptEdits --allowedTools Edit"
        
        # Add current directory access
        command += " --add-dir ."
        
        command
      end
      
      def reload_modified_files
        puts "🔄 Reloading modified files..."
        
        # Get list of recently modified files (last 5 minutes)
        recent_files = get_recently_modified_files
        
        recent_files.each do |file_path|
          if file_path.include?('/app/')
            begin
              load file_path
              puts "✅ Reloaded: #{file_path}"
            rescue => e
              puts "⚠️  Failed to reload #{file_path}: #{e.message}"
            end
          end
        end
        
        puts "🔄 File reloading completed"
      end
      
      def get_recently_modified_files
        # Get files modified in the last 5 minutes
        cutoff_time = Time.now - 300 # 5 minutes ago
        
        files = []
        Dir.glob('**/*.rb').each do |file|
          if File.mtime(file) > cutoff_time
            files << file
          end
        end
        
        files.sort_by { |f| File.mtime(f) }.reverse
      end
      
      def log_evolution_attempt(error, class_name, method_name, success)
        log_entry = {
          timestamp: Time.now.iso8601,
          method: 'claude_code_terminal',
          error_type: error.class.name,
          error_message: error.message,
          class_name: class_name,
          method_name: method_name,
          success: success,
          execution_time: Time.now
        }
        
        # Log to file
        log_file = 'log/claude_code_evolution.log'
        FileUtils.mkdir_p(File.dirname(log_file))
        
        File.open(log_file, 'a') do |f|
          f.puts(log_entry.to_json)
        end
        
        puts "📝 Evolution attempt logged to #{log_file}"
      end
      
      def trigger_git_operations(error, class_name, method_name, file_path)
        puts "🚀 Triggering Git operations for Claude Code evolution..."
        
        begin
          # Use the existing SimpleEvolution Git operations
          require_relative 'simple_evolution'
          
          # Create a mock business context for Git operations
          business_context = {
            error_type: error.class.name,
            error_message: error.message,
            class_name: class_name,
            method_name: method_name
          }
          
          # Trigger the Git operations through SimpleEvolution
          git_success = CodeHealer::SimpleEvolution.handle_git_operations_for_claude(
            error, class_name, method_name, file_path
          )
          
          if git_success
            puts "✅ Git operations completed successfully!"
            puts "   - Branch created and committed"
            puts "   - Changes pushed to remote"
            puts "   - Pull request created"
          else
            puts "❌ Git operations failed"
          end
          
        rescue => e
          puts "❌ Error during Git operations: #{e.message}"
          puts "💡 You may need to manually commit and create PR"
        end
      end
    end
  end
end
