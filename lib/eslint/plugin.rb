require 'mkmf'
require 'json'

module Danger
  # Lint javascript files using [eslint](http://eslint.org/).
  # Results are send as inline commen.
  #
  # @example Run eslint with changed files only
  #
  #          eslint.filtering = true
  #          eslint.lint
  #
  # @see  leonhartX/danger-eslint
  # @tags lint, javaxctipt
  class DangerEslint < Plugin
    DEFAULT_BIN_PATH = './node_modules/.bin/eslint'

    # An path to eslint's config file
    # @return [String]
    attr_accessor :config_file

    # An path to eslint's ignore file
    # @return [String]
    attr_accessor :ignore_file

    # Specify result linting file and skip lint.
    # @return [String]
    attr_accessor :result_file

    # A path of eslint's bin
    attr_writer :bin_path
    def bin_path
      @bin_path ||= DEFAULT_BIN_PATH
    end

    # Specified extentions of target file
    # Default is [".js"]
    # @return [Array]
    attr_writer :target_extensions
    def target_extensions
      @target_extensions ||= %W(.js)
    end

    # Lints javascript files.
    # Generates `errors` and `warnings` due to eslint's config.
    # Will try to send inline comment if supported(Github)
    # @param  [Boolean] filtering - If true, only lint the files that git has changed
    # @return  [void]
    #
    def lint(filtering: false)
      changed_files = ((git.modified_files - git.deleted_files - git.renamed_files.map { |r| r[:before] }) + git.added_files + git.renamed_files.map { |r| r[:after] }) if filtering
      get_json_result
        .select { |r| if filtering then changed_files.include? r['filePath'].gsub("#{Dir.pwd}/", '') else true end }
        .reject { |r| r.nil? || r['messages'].length.zero? }
        .reject { |r| r['messages'].first['message'].include? 'matching ignore pattern' }
        .map { |r| send_comment r }
    end

    private

    # Get eslint' bin path
    #
    # return [String]
    def eslint_path
      File.exist?(bin_path) ? bin_path : find_executable('eslint')
    end


    # Get eslint's result as json
    # If result_file is given, read the file.
    # Otherwise, run eslint against the target files.
    # @param  [String] result_file
    # @return [Hash]
    private
    def get_json_result
      if result_file
        JSON.parse(File.read(result_file))
      else
        bin = eslint_path
        raise 'eslint is not installed' unless bin
        run_lint(bin, '.')
          .select { |r| target_extensions.include?(File.extname(r['filePath'])) }
      end
    end

    # Run eslint aginst a single file.
    #
    # @param   [String] bin
    #          The binary path of eslint
    #
    # @param   [String] file
    #          File to be linted
    #
    # return [Hash]
    private
    def run_lint(bin, file)
      command = "#{bin} -f json"
      command << " -c #{config_file}" if config_file
      command << " --ignore-path #{ignore_file}" if ignore_file
      result = `#{command} #{file}`
      JSON.parse(result)
    end

    # Send comment with danger's warn or fail method.
    #
    # @return [void]
    private
    def send_comment(results)
      dir = "#{Dir.pwd}/"
      results['messages'].each do |r|
        filename = results['filePath'].gsub(dir, '')
        if r['severity'] > 1
          fail(r['message'], file: filename, line: r['line'])
        else
          warn(r['message'], file: filename, line: r['line'])
        end
      end
    end
  end
end
