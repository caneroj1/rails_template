system "clear"
puts "Customizing #{@app_name}."
commands_for_after_bundle = []
model_name = ""
using_haml = false

if yes?("Would you like to use Twitter Bootstrap?")
  gem 'bootstrap-sass', '~> 3.2.0'
  inject_into_file 'app/assets/stylesheets/application.css', after: "*/\n" do
    <<-INSERT
@import "bootstrap-sprockets";
@import "bootstrap";
    INSERT
  end

  run "mv app/assets/stylesheets/application.css app/assets/stylesheets/application.css.scss"

  inject_into_file 'app/assets/javascripts/application.js', after: "//= require jquery_ujs\n" do
    <<-INSERT
//= require bootstrap-sprockets
    INSERT
  end
else
  puts "Skipping Bootstrap..."
end

if yes?("Would you like to use Haml?")
  gem 'haml-rails'
  using_haml = true
else
  puts "Skipping Haml..."
end

if yes?("Would you like to use Devise?")
  gem 'devise'
  commands_for_after_bundle << lambda { generate "devise:install" }
  model_name = ask("What would you like the user model to be called? Default is 'user'. Hit enter to skip.")
  model_name = "user" if model_name.blank?
  commands_for_after_bundle << lambda { generate "devise", model_name }

  if yes?("Would you like to use Devise views?")
    commands_for_after_bundle << lambda { generate "devise:views" }
    if using_haml && yes?("Would you like Devise views to be in Haml?")
      gem "html2haml"
      commands_for_after_bundle << lambda { run "find . -name \*.erb -print | sed 'p;s/.erb$/.haml/' | xargs -n2 html2haml;" }
      commands_for_after_bundle << lambda { run "find . -name \*.html.erb -delete" }
    end
  end

  puts "Adding Devise alerts and notices in application.html.erb."
  inject_into_file 'app/views/layouts/application.html.erb', after: "<body>\n" do
    <<-INJECT
<p class="notice"><%= notice %></p>
<p class="alert"><%= alert %></p>
    INJECT
  end

  puts "Making root to welcome#index."
  gsub_file 'config/routes.rb', "# root 'welcome#index'", "root 'welcome#index'"

  if yes?("Would you like to add code to ensure you can use 'current_#{model_name}'?")
    inject_into_file 'app/controllers/application_controller.rb', after: "protect_from_forgery with: :exception\n" do
      <<-INJECT

  def resource_name
    :#{model_name}
  end

  def resource
    @resource ||= #{model_name.capitalize}.new
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:#{model_name}]
  end

  def enable_devise
    @resource_name = resource_name
    resource
    devise_mapping
  end

  def after_sign_in_path_for(resource)
    #{model_name}_path(resource.id)
  end
      INJECT
    end
  end
else
  puts "Skipping Devise..."
end

if yes?("Would you like to use RSpec for testing?")
  gem_group :development, :test do
    gem 'rspec-rails'
    gem 'factory_girl_rails'
    gem 'better_errors'
    gem 'binding_of_caller'
  end

  gem_group :test do
    gem 'faker'
    gem 'capybara'
    gem 'guard-rspec'
    gem 'launchy'
  end

  commands_for_after_bundle << lambda { generate "rspec:install" }
else
  puts "Skipping RSpec..."
end

if yes?("Would you like to use Protected Attributes? Allows use of 'attr_accessible' in models.")
  gem 'protected_attributes'
else
  puts "Skipping Protected Attributed..."
end

if yes?("Would you like to use PostgreSQL as your database?")
  gem 'pg'
  gsub_file 'config/database.yml', 'adapter: sqlite3', 'adapter: postgresql'
  run "createdb #{@app_name}_development"
  run "createdb #{@app_name}_test"
  run "createdb #{@app_name}_production"
  gsub_file 'config/database.yml', 'database: db/development.sqlite3', "database: #{@app_name}_development"
  gsub_file 'config/database.yml', 'database: db/test.sqlite3', "database: #{@app_name}_test"
  gsub_file 'config/database.yml', 'database: db/production.sqlite3', "database: #{@app_name}_production"
else
  puts "Skipping Postgresql..."
end

if yes?("Would you like to run db:migrate after the installation to create your #{model_name.capitalize} table?")
  commands_for_after_bundle << lambda { rake "db:migrate" }
end

after_bundle do
  commands_for_after_bundle.each { |comm| comm.call }
  initialize_git_repo if yes?("Initialize a git repo for this project?")
end

def initalize_git_repo
  run "cd #{@app_name}"
  run "git init"
  puts "What is the url of the remote repo? "
  url = gets.chomp
  run "git remote add origin #{url}"
  run "git remote -v"
end
