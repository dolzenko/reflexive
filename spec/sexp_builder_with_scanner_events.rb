require File.expand_path("../ripper_events_recorder", __FILE__)

# reports scanner events as hashes
class SexpBuilderWithScannerEvents < RipperEventsRecorder
  SCANNER_EVENTS.each do |event|
    module_eval(<<-End, __FILE__, __LINE__ + 1)
      def on_#{event}(tok)
        super
        { :#{ event } => tok }
      end
    End
  end

  PARSER_EVENT_TABLE.each do |event, arity|
    if /_new\z/ =~ event.to_s and arity == 0
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def on_#{event}
          super
          []
        end
      End
    elsif /_add\z/ =~ event.to_s
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def on_#{event}(list, item)
          super
          list.push item
          list
        end
      End
    else
      module_eval(<<-End, __FILE__, __LINE__ + 1)
        def on_#{event}(*args)
          super
          [:#{event}, *args]
        end
      End
    end
  end
end