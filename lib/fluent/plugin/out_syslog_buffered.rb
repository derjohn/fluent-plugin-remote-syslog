require 'fluent/mixin/config_placeholders'
require 'fluent/mixin/rewrite_tag_name'

module Fluent
  class SyslogBufferedOutput < Fluent::BufferedOutput
    # First, register the plugin. NAME is the name of this plugin
    # and identifies the plugin in the configuration file.
    # This method is called before starting.

    Fluent::Plugin.register_output('syslog_buffered', self)

    include Fluent::Mixin::ConfigPlaceholders
    include Fluent::HandleTagNameMixin
    include Fluent::Mixin::RewriteTagName

    config_param :remote_syslog, :string, :default => ""
    config_param :port, :integer, default: 25
    config_param :hostname, :string, :default => ""
    config_param :remove_tag_prefix, :string, :default => nil
    config_param :tag_key, :string, :default => nil
    config_param :tag_max_size, :integer, default: 32
    config_param :facility, :string, :default => 'user'
    config_param :severity, :string, :default => 'debug'
    config_param :use_record, :string, :default => nil
    config_param :payload_key, :string, :default => 'message'
    config_param :payload_full, :bool, :default => false
    config_param :msg_max_size, :integer, default: 1024

    def initialize
      super
      require 'socket'
      require 'syslog_protocol'
      require 'timeout'
    end

    def configure(conf)
      super
      if not conf['remote_syslog']
        raise Fluent::ConfigError.new("remote syslog required")
      end
      @socket = create_tcp_socket(conf['remote_syslog'], conf['port'])
      @packet = SyslogProtocol::Packet.new
      if remove_tag_prefix = conf['remove_tag_prefix']
        @remove_tag_prefix = Regexp.new('^' + Regexp.escape(remove_tag_prefix))
      end
      @facilty = conf['facility']
      @severity = conf['severity']
      @use_record = conf['use_record']
      @payload_key = conf['payload_key']
      @payload_full = conf['payload_full']
      @tag_max_size = conf['tag_max_size'].to_i
      # Configure the packet
      @packet.max_msg_size = conf['msg_max_size'].to_i
      @packet.max_tag_size = @tag_max_size
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def create_tcp_socket(host, port)
      begin
        Timeout.timeout(10) do
          begin
            socket = TCPSocket.new(host, port)
          rescue Errno::ENETUNREACH
            retry
          end
        end
        socket = TCPSocket.new(host, port)
        secs = Integer(1)
        usecs = Integer((1 - secs) * 1_000_000)
        optval = [secs, usecs].pack("l_2")
        socket.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
      rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPIPE, Timeout::Error, OpenSSL::SSL::SSLError, Timeout::Error => e
        log.warn "out:syslog: failed to open tcp socket  #{@remote_syslog}:#{@port} :#{e}"
        socket = nil
      end
      socket
    end

    # This method is called when starting.
    def start
      super
    end

    # This method is called when shutting down.
    def shutdown
      super
    end


    def write(chunk)
      chunk.msgpack_each {|(tag,time,record)|
            send_to_syslog(tag, time, record)
          }
    end

    def send_to_syslog(tag, time, record)
      tag = tag.sub(@remove_tag_prefix, '') if @remove_tag_prefix
      @packet.hostname = hostname
      if @use_record
        @packet.facility = record['facility'] || @facilty
        @packet.severity = record['severity'] || @severity
      else
        @packet.facility = @facilty
        @packet.severity = @severity
      end
      if record['time']
        time = Time.parse(record['time'])
      else
        time = Time.now
      end
      @packet.time = time
      @packet.tag      = if tag_key
                           record[tag_key][0..(@tag_max_size-1)].gsub(/[\[\]]/,'') # tag is trimmed. Default is 32 chars.
                         else
                           tag[0..(@tag_max_size-1)] # tag is trimmed. Default is 32 chars.
                         end
      packet = @packet.dup
      if @payload_full
        packet.content = record.to_json.to_s
      else
        packet.content = record[@payload_key]
      end
      begin
        if not @socket
          @socket = create_tcp_socket(@remote_syslog, @port)
        end
        if @socket
          begin
            @socket.write packet.assemble + "\n"
            @socket.flush
          rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPIPE, Timeout::Error, OpenSSL::SSL::SSLError => e
            log.warn "out:syslog: connection error by #{@remote_syslog}:#{@port} :#{e}"
            @socket = nil
            raise #{e}
          end
        else
          log.warn "out:syslog: Socket connection couldn't be reestablished"
          raise #{e}
        end
      end
    end


  end

  class Time < Time
    def timezone(timezone = 'UTC')
      old = ENV['TZ']
      utc = self.dup.utc
      ENV['TZ'] = timezone
      output = utc.localtime
      ENV['TZ'] = old
      output
    end
  end
end

