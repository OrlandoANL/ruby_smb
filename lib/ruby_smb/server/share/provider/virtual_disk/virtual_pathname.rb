module RubySMB
  class Server
    module Share
      module Provider
        class VirtualDisk < Disk
          class VirtualPathname
            SEPARATOR = /[\/\\]/
            # see: https://ruby-doc.org/stdlib-2.6.3/libdoc/pathname/rdoc/Pathname.html#class-Pathname-label-File+status+predicate+methods
            STAT_METHODS = %i[
              blockdev?
              chardev?
              directory?
              executable?
              exist?
              file?
              grpowned?
              owned?
              pipe?
              readable?
              world_readable?
              setgid?
              setuid?
              size
              socket?
              sticky?
              symlink?
              writable?
              world_writable?
              zero?

              atime
              birthtime
              ctime
              mtime
              ftype
            ]

            def initialize(disk, path, stat: nil)
              @virtual_disk = disk
              @path = path
              @stat = stat || VirtualStat.new
            end

            def ==(other)
              other.is_a?(self.class) && other.to_s == to_s
            end

            def join(other)
              sep = to_s[SEPARATOR] || File::SEPARATOR
              lookup_or_create(to_s + sep + other.to_s)
            end

            alias :+ :join
            alias :/ :join

            def to_s
              @path
            end

            def absolute?
              to_s.start_with?(SEPARATOR)
            end

            def relative?
              !absolute?
            end

            def basename
              lookup_or_create(to_s.rpartition(SEPARATOR).last, stat: @stat)
            end

            def dirname
              name = to_s.rpartition(SEPARATOR).first
              lookup_or_create(name.empty? ? '.' : '')
            end

            def extname
              File.extname(to_s)
            end

            def split
              [dirname, basename]
            end

            def entries
              raise Errno::ENOTDIR.new("Not a directory @ dir_initialize - #{to_s}") unless directory?

              @virtual_disk.each_value.select { |dirent| dirent.dirname == self }
            end

            def cleanpath(consider_symlink=false)
              lookup_or_create(self.class.cleanpath(to_s), stat: @stat)
            end

            attr_reader :stat

            def self.cleanpath(path_string, sep: nil)
              sep = sep || path_string[SEPARATOR] || File::SEPARATOR

              cleaned = []
              path_string.split(SEPARATOR).each do |part|
                next if ['', '.'].include?(part)

                if part == '..'
                  cleaned.pop
                  next
                end

                cleaned << part
              end

              (path_string.start_with?(sep) ? sep : '') + cleaned.join(sep)
            end

            private

            def lookup_or_create(path, **kwargs)
              @virtual_disk[self.class.cleanpath(path)] || VirtualPathname.new(@virtual_disk, path, **kwargs)
            end

            def method_missing(symbol, *args)
              if STAT_METHODS.include?(symbol)
                return @stat.send(symbol, *args)
              end

              raise NoMethodError, "undefined method `#{symbol}' for #{self.class}"
            end
          end
        end
      end
    end
  end
end
