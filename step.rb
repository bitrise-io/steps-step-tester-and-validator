#

require 'pathname'

options = {
	step_repo: ENV['STEP_TESTER_STEP_REPO'],
	step_version: ENV['STEP_TESTER_STEP_VERSION_TAG'],
    step_test_branch: ENV['STEP_TESTER_STEP_TEST_BRANCH'],
	step_args_file: ENV['__INPUT_FILE__']
}

git_checkout_option = '', # will be either the Tag (if specified) or the test-branch
step_args_content = ''

$summary_info = {
	is_clone_ok: false,
	is_step_sh_file_found: false,
	is_step_yml_file_found: false,
	is_readme_file_found: false,
	is_license_file_found: false
}

$formatted_output_file_path = ENV['BITRISE_STEP_FORMATTED_OUTPUT_FILE_PATH']
system("rm #{$formatted_output_file_path}")

def puts_string_to_formatted_output(text, is_log_print=false)
	open($formatted_output_file_path, 'a') { |f|
		f.puts(text)
	}
	if is_log_print
		puts text
	end
end

def puts_section_to_formatted_output(section_text, is_log_print=false)
	open($formatted_output_file_path, 'a') { |f|
		f.puts
		f.puts(section_text)
		f.puts
	}
	if is_log_print
		puts
		puts section_text
		puts
	end
end

def print_formatted_summary
	is_required_missing = false
	is_recommended_missing = false

	puts_section_to_formatted_output("# Repository Check", true)

	if $summary_info[:is_clone_ok]
		puts_string_to_formatted_output("* Step Repository Clone [ok]", true)
	else
		puts_string_to_formatted_output("* **Step Repository Clone [FAILED]**", true)
		is_required_missing = true
	end
	if $summary_info[:is_step_sh_file_found]
		puts_string_to_formatted_output("* step.sh [found]", true)
	else
		puts_string_to_formatted_output("* **step.sh [NOT FOUND] (Required!)**", true)
		is_required_missing = true
	end
	if $summary_info[:is_step_yml_file_found]
		puts_string_to_formatted_output("* step.yml [found]", true)
	else
		puts_string_to_formatted_output("* **step.yml [not found] (recommended)**", true)
		is_recommended_missing = true
	end
	if $summary_info[:is_readme_file_found]
		puts_string_to_formatted_output("* README.md [found]", true)
	else
		puts_string_to_formatted_output("* **README.md [not found] (recommended)**", true)
		is_recommended_missing = true
	end
	if $summary_info[:is_license_file_found]
		puts_string_to_formatted_output("* LICENSE [found]", true)
	else
		puts_string_to_formatted_output("* **LICENSE [not found] (recommended)**", true)
		is_recommended_missing = true
	end

	puts_section_to_formatted_output("## Summary")
	if is_required_missing
		puts_string_to_formatted_output("* **Required Step file(s) missing [FAILED]**", true)
	else
		puts_string_to_formatted_output("* Every required Step file found [ok]", true)
	end

	if is_recommended_missing
		puts_string_to_formatted_output("* **Recommended Step file(s) missing**", true)
	else
		puts_string_to_formatted_output("* Every recommended Step file found [awesome]", true)
	end

	puts_section_to_formatted_output("---------------------------------------", true)

	return !is_required_missing
end

def print_error(err_msg)
	puts " [!] Failed: #{err_msg}"
	puts_section_to_formatted_output "# Failed"
	puts_section_to_formatted_output err_msg
	exit 1
end

def print_warning(warning_msg)
	puts " (!) #{warning_msg}"
	puts_section_to_formatted_output "# Warning"
	puts_section_to_formatted_output warning_msg
end

unless options[:step_repo]
	print_error "Step Repository URL not defined"
	exit 1
end
if options[:step_version]
	git_checkout_option = options[:step_version]
else
	print_warning "Step Version (Tag) not defined"
	if options[:step_test_branch]
      print_warning "Will use the provided Test-Branch instead - this is only recommended for testing, for production you should always use Version Tags instead of branch!"
      git_checkout_option = options[:step_test_branch]
    else
      print_error "Neither a Version Tag nor a Test-Branch defined!"
      exit 1
    end
end

if options[:step_args_file]
	step_args_content = File.read(options[:step_args_file])
end
unless step_args_content
	print_warning "Step Args not defined - no Input will be passed to the Step"
end


# -----------------------
# --- MAIN

def collect_step_input_envs_from_string(str)
	step_envs = []

	str.each_line {|line|
		splits = line.split("=")
		env_key = splits.shift.strip # first item is the key
		env_value = splits.join("=") # rest is the value
		if env_key and env_value
			step_envs << {
				key: env_key,
				value: env_value.chomp
			}
		else
			print_warning("Possibly invalid input (will be skipped), key or value missing: #{line}")
		end
	}

	return step_envs
end

is_failed = false
begin
	unless system(%Q{git clone -b "#{git_checkout_option}" "#{options[:step_repo]}" ./stepdir})
		raise "Failed to clone the Step Repository"
	end
	step_base_dir = Pathname.new('./stepdir').realpath.to_s
	puts " (debug) step_base_dir: #{step_base_dir}"
	$summary_info[:is_clone_ok] = true

	$summary_info[:is_step_sh_file_found] = true if File.file?(File.join(step_base_dir, "step.sh"))
	$summary_info[:is_step_yml_file_found] = true if File.file?(File.join(step_base_dir, "step.yml"))
	$summary_info[:is_license_file_found] = true if File.file?(File.join(step_base_dir, "LICENSE"))
	$summary_info[:is_readme_file_found] = true if File.file?(File.join(step_base_dir, "README.md"))
	unless print_formatted_summary()
		raise "A required Step file is missing!"
	end

	puts_section_to_formatted_output("# Running the Step", true)
	step_envs = collect_step_input_envs_from_string(step_args_content)
	puts " (debug) step_envs: #{step_envs}"

	# clean up own ENV
	ENV.delete('STEP_TESTER_STEP_REPO')
	ENV.delete('STEP_TESTER_STEP_VERSION_TAG')
	ENV.delete('STEP_TESTER_STEP_TEST_BRANCH')
	ENV.delete('__INPUT_FILE__')
	# set Step's ENV
	if step_envs.length > 0
		puts_section_to_formatted_output("## Envs:", true)
		step_envs.each {|an_env|
			ENV[an_env[:key]] = an_env[:value]
			puts_string_to_formatted_output("* `#{an_env[:key]}` : `#{ENV[an_env[:key]]}`", true)
		}
	end
	puts_section_to_formatted_output("---------------------------------------", true)
	
	unless system(%Q{cd stepdir && bash step.sh})
		raise "Step Failed"
	end
rescue => ex
	print_error("#{ex}")
	is_failed = true
ensure
	system(%Q{rm -rf "#{step_base_dir}"})
end

exit (is_failed ? 1 : 0)