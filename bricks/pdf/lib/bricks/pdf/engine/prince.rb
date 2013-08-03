module Bricks
  module Pdf
    module Engine
      module Prince
        CMD = Bricks::CONFIG['pdf']['cmd'] || 'prince'
        def command(opts)
          cmd = [CMD]
          {
            :http_user     => '--http-user=',
            :http_password => '--http-password=',
            :baseurl       => '--baseurl='
          }.each do |key, cmd_key|
            cmd << "#{cmd_key}#{opts[key]}"
          end

          # FIXME: find a way to redirect errors on screen instead of main log.
          cmd << "--log=#{Zena.log_path}"

          if file = opts[:input]
            cmd << file
          else
            cmd << "-"
          end

          if file = opts[:output]
            cmd << "-o #{file}"
          else
            cmd << "-o -"
          end

          cmd.join(' ')
        end
      end # Prince
    end # Engine
  end # Pdf
end # Bricks



