module VagrantBindfs
  # A Vagrant middleware which use bindfs to relocate directories inside a VM
  # and change their owner, group and permission.
  class Middleware
    
    # Options
    @@options = {
      :owner                => 'vagrant',
      :group                => 'vagrant',
      :perms                => 'u=rwX:g=rD:o=rD',
      :mirror               => nil,
      :'mirror-only'        => nil,
      :'create-for-user'    => nil,
      :'create-for-group'   => nil,
      :'create-with-perms'  => nil,
    }
      
    # Flags
    @@flags = {
      :'no-allow-other'     => false,
      :'create-as-user'     => false,
      :'create-as-mounter'  => false,
      :'chown-normal'       => false,
      :'chown-ignore'       => false,
      :'chown-deny'         => false,
      :'chgrp-normal'       => false,
      :'chgrp-ignore'       => false,
      :'chgrp-deny'         => false,
      :'chmod-normal'       => false,
      :'chmod-ignore'       => false,
      :'chmod-deny'         => false,
      :'chmod-allow-x'      => false,
      :'xattr-none'         => false,
      :'xattr-ro'           => false,
      :'xattr-rw'           => false,
      :'ctime-from-mtime'   => false,
    }
    
    def initialize(app, env)
      @app = app
      @env = env
    end

    def call(env)
      @env = env
      @app.call(env)
      bind_folders unless binded_folders.empty?
    end

    def binded_folders
      @env.env.config.bindfs.binded_folders
    end

    def default_options
      @@options.merge(@@flags).merge(@env.env.config.bindfs.default_options || {})
    end

    def bind_folders
      @env["vm"].ssh.execute do |ssh|
        
        # Check if bindfs is installed on VM
        begin
          ssh.exec!("sudo bindfs --help")
        rescue Vagrant::Errors::VagrantError => e
          @env.ui.error e
          @env.ui.error I18n.t("vagrant.actions.vm.bind_folders.bindfs_not_installed")
          return
        end
        
        @env.ui.info I18n.t("vagrant.actions.vm.bind_folders.binding")
        binded_folders.each do |opts|

          path     = opts.delete(:path)
          bindpath = opts.delete(:bindpath)
          opts     = default_options.merge(opts)

          args = []
          opts.each do |key, value|
            if @@flags.key?(key)
              args << "--#{key.to_s}" if !!value 
            else
              args << "--#{key.to_s}=#{value}" if !value.nil?
            end
          end
          args = " #{args.join(" ")}"
          
          begin
            ssh.exec!("sudo mkdir -p #{bindpath}")
            ssh.exec!("sudo bindfs#{args} #{path} #{bindpath}")
            @env.ui.info I18n.t("vagrant.actions.vm.bind_folders.binding_entry",
              :path     => path,
              :bindpath => bindpath
              )
            @env.ui.info "sudo bindfs#{args} #{path} #{bindpath}"
          rescue Vagrant::Errors::VagrantError => e
            @env.ui.error e
            @env.ui.error I18n.t("vagrant.actions.vm.bind_folders.bindfs_command_fail")
          end
          
        end
      end
    end
  end
end