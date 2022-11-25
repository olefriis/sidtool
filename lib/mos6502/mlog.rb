class MLog
  def initialize(base, &write)
    @_val  = base
    @write = write
  end

  def write(obj)
    @_val.nil? ? self : self.class.new(@write.call(@_val, obj), &@write)
  end

  def to_s
    @_val.nil? ? 'Nothing' : "<MLog: #{@_val.inspect}>"
  end
  alias_method :inspect, :to_s
end
