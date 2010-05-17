require "ripper"

class RipperEventsRecorder < Ripper
  attr_accessor :parser_events, :scanner_events, :all_events

  def self.parser_events(src)
    new(src).tap { |p| p.parse }.parser_events
  end

  def self.scanner_events(src)
    new(src).tap { |p| p.parse }.scanner_events
  end

  def self.all_events(src)
    new(src).tap { |p| p.parse }.all_events
  end

  def initialize(*args)
    super
    self.parser_events = []
    self.scanner_events = []
    self.all_events = []
  end

  Ripper::SCANNER_EVENTS.each do |meth|
    define_method("on_#{ meth }") do |*args|
      result = super(*args)
      scanner_events << [ meth, (args.size == 1 ? args[0] : args) ]
      all_events << [ meth, (args.size == 1 ? args[0] : args) ]
      result
    end
  end

  Ripper::PARSER_EVENTS.each do |meth|
    define_method("on_#{ meth }") do |*args|
      result = super(*args)
      parser_events << [ meth, (args.size == 1 ? args[0] : args) ]
      all_events << [ meth, (args.size == 1 ? args[0] : args) ]
      result
    end
  end

  def scanner_event_index(scanner_event_object_id)
    scanner_events.index { |s_e| s_e.object_id == scanner_event_object_id }
  end

  def scanner_event(scanner_event_object_id)
    scanner_events.detect { |s_e| s_e.object_id == scanner_event_object_id }
  end
end