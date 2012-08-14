require "compile_version.rb"

module App
  extend self

  include CompileVersion
  VERSION = "1.2_50BELOW"
  OS = org.jruby.platform.Platform::OS
  OS_VERSION = java.lang.System.getProperty("os.version")

  def version
    VERSION
  end

  def compile_version
    "#{OS}.#{OS_VERSION}.#{org.jruby.platform.Platform::ARCH}.ruby-#{::Object::VERSION}.#{COMPILE_TIME}.#{REVISION}"
  end


  CONFIG_DIR = File.join( java.lang.System.getProperty("user.home") , '.fire-app' )
  AUTOCOMPLTETE_CACHE_DIR = File.join( java.lang.System.getProperty("user.home") , '.fire-app', 'autocomplete_cache' )

  Dir.mkdir( CONFIG_DIR ) unless File.exists?( CONFIG_DIR )
  Dir.mkdir( AUTOCOMPLTETE_CACHE_DIR ) unless File.exists?( AUTOCOMPLTETE_CACHE_DIR )

  HISTORY_FILE =  File.join( CONFIG_DIR, 'history')
  CONFIG_FILE  =  File.join( CONFIG_DIR, 'config')
  @notifications = []
  def notifications
    @notifications
  end

  def notifications=(x)
    @notifications=x
  end

  def show_and_clean_notifications
    if !App.notifications.empty?
      App.notifications.each do |x|
        App.notify(x)
      end
      App.notifications = []
    end
  end

  def get_system_default_gem_path
    begin
      %x{gem env gempath}.strip.split(/:/).first
    rescue => e
      nil
    end
  end

  def get_config
    begin
      x = YAML.load_file( CONFIG_FILE )
    rescue => e
      x = {}
    end

    x.delete("services_http_port") unless x["services_http_port"].to_i > 0
    x.delete("services_livereload_port") unless x["services_livereload_port"].to_i > 0

    config={
      "show_welcome" => false,
      "use_version" => 0.11,
      "use_specify_gem_path" => false,
      "notifications" => [ :error, :warning ],
      "save_notification_to_file" => true,
      "services" => [ :http, :livereload],
      "services_http_port" => 24681,
      "services_livereload_port" => 35729,
      "services_livereload_extensions" => "aspx,ascx,css,png,jpg,gif,html,erb,haml,coffee,markdown,mkd,md",
      "preferred_syntax" => "scss"
    }

    config.merge!(x)
    unless config["gem_path"]
      config["gem_path"] = App.get_system_default_gem_path
    end

    return config
  end

  CONFIG = get_config
  def require_compass

    begin
      if CONFIG["use_specify_gem_path"]
        ENV["GEM_HOME"] = CONFIG["gem_path"]
        ENV["GEM_PATH"] = CONFIG["gem_path"]
        require "rubygems"
      end

      # make sure use java version library, ex json-java, eventmachine-java
      jruby_gems_path = File.join(LIB_PATH, "ruby", "jruby" )
      scan_library( jruby_gems_path )
      require "fssm" if (OS == 'darwin' && OS_VERSION.to_f >= 10.6 ) || OS == 'linux' || OS == 'windows'

      require "compass"
      require "compass/exec"

    rescue LoadError => e
      if CONFIG["use_specify_gem_path"]
        alert("Load custom Compass fail, use default Compass v0.12 library, please check the Gem Path")
      end


      common_lib_path = File.join(LIB_PATH, "ruby", "common" )
      scan_library( common_lib_path )

      # if App::CONFIG['use_version']
      #   alert("Hey there 50 Belower! \n\nFire.app is using Compass #{VERSION}! by default.")
      #   App::CONFIG['use_version']=0.12
      # end

      if App::CONFIG['use_version'] == 0.12
        compass_gems_path = File.join(LIB_PATH, "ruby", "compass_0.12")
      else
        compass_gems_path = File.join(LIB_PATH, "ruby", "compass_0.11")
      end

      scan_library(compass_gems_path)

      extensions_gems_path = File.join(LIB_PATH, "ruby", "compass_extensions" )

      scan_library( extensions_gems_path )

      require "compass"
      require "compass/exec"
    end

    $LOAD_PATH.unshift('.')
    require "fsevent_patch" if OS == 'darwin'
    require "coffee_compiler.rb"
    require "compass_patch.rb"
    require "sass_patch.rb"
  end

  def save_config
    open(CONFIG_FILE,'w') do |f|
      f.write YAML.dump(CONFIG)
    end

  end

  def clear_histoy
    set_histoy([])
  end

  def set_histoy(dirs)
    File.open(HISTORY_FILE, 'w') do |out|
      YAML.dump(dirs, out)
    end
  end

  def get_history
    dirs = YAML.load_file( HISTORY_FILE ) if File.exists?(HISTORY_FILE)
    return dirs if dirs
    return []
  end

  def display
    Swt::Widgets::Display.get_current
  end

  def create_shell(style = nil)
    style ||= Swt::SWT::NO_FOCUS | Swt::SWT::NO_TRIM
    Swt::Widgets::Shell.new( Swt::Widgets::Display.get_current, style)
  end

  def create_image(path)
    Swt::Graphics::Image.new( Swt::Widgets::Display.get_current, java.io.FileInputStream.new( File.join(LIB_PATH, 'images', path)))
  end

  def get_stdout
    begin
      sio = StringIO.new
      old_stdout, $stdout = $stdout, sio
      #  Invoke method to test that writes to stdout
      yield
      output = sio.string.gsub(/\e\[\d+m/,'')
    rescue Exception => e
      output = e.message
    end
    $stdout = old_stdout # restore stdout
    return output
  end

  def notify(msg, target_display = nil )
    if org.jruby.platform.Platform::IS_MAC
      system('/usr/bin/osascript', "#{LIB_PATH}/applescript/growl.scpt", msg )
    else
      Notification.new(msg, target_display)
    end
  end

  def report(msg, target_display = nil, options={}, &block)
    Report.new(msg, target_display, options, &block)
  end

  def alert(msg, target_display = nil, &block)
    Alert.new(msg, target_display, &block)
  end

  def try
    begin
      yield
    rescue Exception => e
      report("#{e.message}\n#{e.backtrace.join("\n")}")
    end
  end

  def scan_library( dir )
    Dir.new( dir ).entries.reject{|e| e =~ /^\./}.each do | subfolder|
      lib_path = File.expand_path( File.join(dir, subfolder,'lib') )
      $LOAD_PATH.unshift( lib_path ) if File.exists?(lib_path)
    end

  end

  def clear_autocomplete_cache
    history_dirs=App.get_history
      Dir.glob(File.join(App::AUTOCOMPLTETE_CACHE_DIR, '*project')).each do |f|
        need_delete=true
        f_project = IO.read(f)
        history_dirs.each do |history_string|
          if f_project == history_string
            need_delete = false
            break
          end
        end
        if need_delete
          [f, f.gsub(/project$/, 'mixin'), f.gsub(/project$/, 'variable')].each do |fn|
            File.delete(fn)  if File.exists?(fn)
          end
        end
      end
  end
end

