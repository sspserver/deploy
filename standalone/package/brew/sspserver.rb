class Sspserver < Formula
  desc "SSP Server - Supply-Side Platform Server for programmatic advertising"
  homepage "https://sspserver.org"
  url "https://github.com/sspserver/deploy/archive/refs/heads/main.tar.gz"
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000" # TODO: Update with actual SHA256
  license "MIT"

  depends_on "curl"
  depends_on "unzip" 
  depends_on "jq"
  depends_on "git"
  depends_on "docker" => :recommended

  def install
    # Create installation directories
    (var/"log/sspserver").mkpath
    (etc/"sspserver").mkpath
    
    # Install scripts and configuration files
    bin.install "standalone/install.sh" => "sspserver-install"
    bin.install "standalone/systems/darwin.sh" => "sspserver-darwin"
    
    # Install configuration templates
    (etc/"sspserver").install Dir["standalone/config/*"] if Dir.exist?("standalone/config")
    
    # Create wrapper script
    (bin/"sspserver").write <<~EOS
      #!/bin/bash
      set -e
      
      # SSP Server Homebrew wrapper script
      SSPSERVER_BREW_PREFIX="#{prefix}"
      SSPSERVER_LOG_DIR="#{var}/log/sspserver"
      SSPSERVER_CONFIG_DIR="#{etc}/sspserver"
      
      export SSPSERVER_BREW_PREFIX SSPSERVER_LOG_DIR SSPSERVER_CONFIG_DIR
      
      case "$1" in
        install)
          echo "Installing SSP Server..."
          exec "#{bin}/sspserver-install" "${@:2}"
          ;;
        status)
          echo "Checking SSP Server status..."
          if launchctl list | grep -q "org.sspserver.sspserver"; then
            echo "SSP Server is running"
            launchctl list | grep "org.sspserver.sspserver"
          else
            echo "SSP Server is not running"
          fi
          ;;
        start)
          echo "Starting SSP Server..."
          sudo launchctl load /Library/LaunchDaemons/org.sspserver.sspserver.plist
          ;;
        stop)
          echo "Stopping SSP Server..."
          sudo launchctl unload /Library/LaunchDaemons/org.sspserver.sspserver.plist
          ;;
        restart)
          echo "Restarting SSP Server..."
          sudo launchctl unload /Library/LaunchDaemons/org.sspserver.sspserver.plist 2>/dev/null || true
          sudo launchctl load /Library/LaunchDaemons/org.sspserver.sspserver.plist
          ;;
        logs)
          echo "Showing SSP Server logs..."
          if [ -f "#{var}/log/sspserver/sspserver_1click_standalone.log" ]; then
            tail -f "#{var}/log/sspserver/sspserver_1click_standalone.log"
          else
            echo "Log file not found"
          fi
          ;;
        uninstall)
          echo "Uninstalling SSP Server..."
          echo "This will remove:"
          echo "  - SSP Server services"
          echo "  - Docker containers and images"
          echo "  - Installation directory (/opt/sspserver)"
          echo "  - Configuration files (/etc/sspserver)"
          echo "  - Service files (/Library/LaunchDaemons/org.sspserver.sspserver.plist)"
          echo ""
          
          # Check if running in force mode (from Homebrew uninstall)
          if [[ "\${SSPSERVER_UNINSTALL_FORCE}" == "1" ]]; then
            echo "Running in automated mode (Homebrew uninstall)..."
            CONFIRMED=true
          else
            read -p "Are you sure you want to continue? (y/N): " -n 1 -r
            echo
            if [[ \$REPLY =~ ^[Yy]\$ ]]; then
              CONFIRMED=true
            else
              CONFIRMED=false
            fi
          fi
          
          if [[ "\$CONFIRMED" == "true" ]]; then
            # Stop services
            echo "Stopping SSP Server services..."
            sudo launchctl unload /Library/LaunchDaemons/org.sspserver.sspserver.plist 2>/dev/null || true
            
            # Remove service files
            sudo rm -f /Library/LaunchDaemons/org.sspserver.sspserver.plist
            
            # Stop and remove Docker containers
            if command -v docker >/dev/null 2>&1; then
              echo "Stopping SSP Server containers..."
              docker ps -a --filter "name=sspserver" --format "{{.Names}}" | while read container; do
                [ -n "\$container" ] && docker stop "\$container" 2>/dev/null || true
                [ -n "\$container" ] && docker rm "\$container" 2>/dev/null || true
              done
              
              echo "Removing SSP Server images..."
              docker images --filter "reference=sspserver*" --format "{{.Repository}}:{{.Tag}}" | while read image; do
                [ -n "\$image" ] && docker rmi "\$image" 2>/dev/null || true
              done
            fi
            
            # Remove installation directory
            sudo rm -rf /opt/sspserver
            
            # Remove configuration files
            sudo rm -rf /etc/sspserver
            
            echo "SSP Server has been completely uninstalled."
            echo ""
            echo "Note: Logs are preserved in #{var}/log/sspserver"
            echo "To remove logs: rm -rf #{var}/log/sspserver"
            
            # Only show Homebrew uninstall message if not running from Homebrew
            if [[ "\${SSPSERVER_UNINSTALL_FORCE}" != "1" ]]; then
              echo ""
              echo "To uninstall this Homebrew package:"
              echo "  brew uninstall sspserver"
            fi
          else
            echo "Uninstallation cancelled."
          fi
          ;;
        *)
          echo "Usage: sspserver {install|status|start|stop|restart|logs|uninstall}"
          echo ""
          echo "Commands:"
          echo "  install     Install SSP Server"
          echo "  status      Show service status"
          echo "  start       Start SSP Server service"
          echo "  stop        Stop SSP Server service"
          echo "  restart     Restart SSP Server service"
          echo "  logs        Show logs (tail -f)"
          echo "  uninstall   Remove SSP Server completely"
          echo ""
          echo "Examples:"
          echo "  sspserver install           # Interactive installation"
          echo "  sspserver install -y        # Automatic installation"
          echo "  sspserver status            # Check if running"
          echo "  sspserver restart           # Restart service"
          exit 1
          ;;
      esac
    EOS
  end

  def post_install
    # Ensure log directory exists and has proper permissions
    (var/"log/sspserver").chmod 0755
    
    ohai "SSP Server has been installed!"
    ohai ""
    ohai "To install and start SSP Server:"
    ohai "  sspserver install"
    ohai ""
    ohai "To install automatically (no prompts):"
    ohai "  sspserver install -y"
    ohai ""
    ohai "Other commands:"
    ohai "  sspserver status     # Check service status"
    ohai "  sspserver start      # Start service"
    ohai "  sspserver stop       # Stop service"
    ohai "  sspserver restart    # Restart service"
    ohai "  sspserver logs       # View logs"
    ohai "  sspserver uninstall  # Remove completely"
    ohai ""
    ohai "Note: SSP Server requires Docker. Install with:"
    ohai "  brew install --cask docker"
  end

  def uninstall_preflight
    # Use the wrapper script's uninstall command for consistency
    ohai "Running SSP Server cleanup before Homebrew uninstall..."
    
    # Check if sspserver command exists and run uninstall with --force flag
    if File.exist?("#{bin}/sspserver")
      # Set environment variable to skip confirmation in automated mode
      ENV['SSPSERVER_UNINSTALL_FORCE'] = '1'
      system "#{bin}/sspserver", "uninstall"
      ENV.delete('SSPSERVER_UNINSTALL_FORCE')
    else
      # Fallback: manual cleanup if wrapper script is not available
      ohai "Wrapper script not found, performing manual cleanup..."
      
      # Stop launchd services
      system "sudo", "launchctl", "unload", "/Library/LaunchDaemons/org.sspserver.sspserver.plist" if File.exist?("/Library/LaunchDaemons/org.sspserver.sspserver.plist")
      
      # Remove service files
      system "sudo", "rm", "-f", "/Library/LaunchDaemons/org.sspserver.sspserver.plist"
      
      # Remove installation directory
      system "sudo", "rm", "-rf", "/opt/sspserver" if Dir.exist?("/opt/sspserver")
      
      # Remove configuration files
      system "sudo", "rm", "-rf", "/etc/sspserver" if Dir.exist?("/etc/sspserver")
    end
    
    ohai "SSP Server cleanup completed."
  end

  test do
    # Test that the wrapper script exists and is executable
    assert_predicate bin/"sspserver", :exist?
    assert_predicate bin/"sspserver", :executable?
    
    # Test that install script exists
    assert_predicate bin/"sspserver-install", :exist?
    assert_predicate bin/"sspserver-install", :executable?
    
    # Test basic command help
    output = shell_output("#{bin}/sspserver 2>&1", 1)
    assert_match "Usage: sspserver", output
  end
end
