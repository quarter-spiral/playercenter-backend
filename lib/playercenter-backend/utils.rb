module Playercenter::Backend
  class Utils
    def self.camelize_string(str)
      str.gsub('-', '_').sub(/^[a-z\d]*/) { $&.capitalize }.gsub(/(?:_|(\/))([a-z\d]*)/i) {$2.capitalize}
    end

    def self.uncamelize_string(str)
      str.sub(/^./) {|e| e.downcase}.gsub(/[A-Z]/) {|e| "_#{e.downcase}"}
    end
  end
end